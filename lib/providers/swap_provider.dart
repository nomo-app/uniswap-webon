// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/common/extensions.dart';

final rpc = EvmRpcInterface(
  type: ZeniqSmartNetwork,
  useQueuedManager: false,
  clients: [
    EvmRpcClient(zeniqSmartRPCEndpoint),
  ],
);
final zeniqSwapRouter = UniswapV2Router(
  rpc: rpc,
  contractAddress: "0x7963c1bd24E4511A0b14bf148F93e2556AFe3C27",
);
final factory = UniswapV2Factory(
  rpc: rpc,
  contractAddress: "0x7D0cbcE25EaaB8D5434a53fB3B42077034a9bB99",
);
const _refreshInterval = Duration(seconds: 15);

enum SwapType {
  ExactTokenForToken,
  ExactTokenForZeniq,
  ExactZeniqForToken,
  ZeniqForExactToken,
  TokenForExactZeniq,
  TokenForExactToken,
}

enum SwapState {
  None,
  NeedsTokenApproval,
  TokenApprovalError,
  ApprovingToken,
  ReadyForSwap,
  WaitingForUserApproval,
  Broadcasting,
  Confirming,
  Swapped,
  Error;

  bool get inputEnabled => switch (this) {
        SwapState.None ||
        SwapState.ReadyForSwap ||
        SwapState.Error ||
        SwapState.TokenApprovalError ||
        SwapState.NeedsTokenApproval =>
          true,
        _ => false,
      };
}

enum LastAmountChanged {
  From,
  To,
}

sealed class SwapInfo {
  final double slippage;
  final double priceImpact;
  final Amount fee;
  final TokenEntity fromToken;
  final TokenEntity toToken;
  final bool needsApproval;
  final List<String> path;

  const SwapInfo({
    required this.slippage,
    required this.priceImpact,
    required this.fromToken,
    required this.toToken,
    required this.needsApproval,
    required this.path,
    required this.fee,
  });
}

final class FromSwapInfo extends SwapInfo {
  final Amount amountOutMin;
  final Amount fromAmount;
  final Amount amountOut;

  double get rate {
    return amountOut.value / fromAmount.value;
  }

  String getPrice() {
    return "${rate.toString().format(3)} ${toToken.name} per ${fromToken.name}";
  }

  const FromSwapInfo({
    required this.amountOutMin,
    required this.fromAmount,
    required this.amountOut,
    required super.priceImpact,
    required super.slippage,
    required super.fromToken,
    required super.toToken,
    required super.needsApproval,
    required super.path,
    required super.fee,
  });

  @override
  String toString() {
    return "${fromAmount.displayDouble.toMaxPrecisionWithoutScientificNotation(3)} ${fromToken.symbol} -> ${amountOut.displayDouble.toMaxPrecisionWithoutScientificNotation(3)} ${toToken.symbol}";
  }
}

final class ToSwapInfo extends SwapInfo {
  final Amount toAmount;
  final Amount amountInMax;
  final Amount amountIn;

  double get rate {
    return toAmount.value / amountIn.value;
  }

  String getPrice() {
    return "${(1 / rate).toString().format(3)} ${fromToken.symbol} per ${toToken.symbol}";
  }

  const ToSwapInfo({
    required this.toAmount,
    required this.amountInMax,
    required this.amountIn,
    required super.priceImpact,
    required super.slippage,
    required super.fromToken,
    required super.toToken,
    required super.needsApproval,
    required super.path,
    required super.fee,
  });

  @override
  String toString() {
    return "${amountIn.displayDouble.toMaxPrecisionWithoutScientificNotation(3)} ${fromToken.symbol} -> ${toAmount.displayDouble.toMaxPrecisionWithoutScientificNotation(3)} ${toToken.symbol}";
  }
}

extension on String {
  String format(int places) {
    final parts = split('.');
    if (parts.length == 1) {
      return this;
    }
    final decimal = parts[1];
    if (decimal.length <= places) {
      return this;
    }
    return '${parts[0]}.${decimal.substring(0, places)}';
  }
}

BigInt? parseFromString(String value, int decimals) {
  final split = value.replaceAll(',', '.').split('.');

  if (split.length > 2) {
    return null;
  }

  final right = split.length == 2
      ? split[1].padRight(decimals, '0')
      : ''.padRight(decimals, '0');
  final left = split[0];

  return BigInt.tryParse('$left$right');
}

class SwapProvider {
  final String ownAddress;
  final Future<String> Function(String tx) signer;

  final ValueNotifier<TokenEntity?> fromToken = ValueNotifier(zeniqSmart);
  final ValueNotifier<TokenEntity?> toToken = ValueNotifier(null);
  final ValueNotifier<Amount?> fromAmount = ValueNotifier(null);
  final ValueNotifier<Amount?> toAmount = ValueNotifier(null);
  final ValueNotifier<String> fromAmountString = ValueNotifier('');
  final ValueNotifier<String> toAmountString = ValueNotifier('');

  SwapProvider(this.ownAddress, this.signer) {
    fromToken.addListener(() => checkSwapInfo());
    toToken.addListener(() => checkSwapInfo());
    fromAmount.addListener(() => checkSwapInfo());
    toAmount.addListener(() => checkSwapInfo());

    fromAmountString.addListener(fromAmountStringChanged);
    toAmountString.addListener(toAmountStringChanged);

    slippageString.addListener(slippageChanged);

    Timer.periodic(_refreshInterval, (_) {
      checkSwapInfo();
    });
  }

  SwapType? swapType;
  bool shouldRecalculateSwapType = true;
  LastAmountChanged? lastAmountChanged;

  final ValueNotifier<SwapState> swapState = ValueNotifier(SwapState.None);
  final ValueNotifier<SwapInfo?> swapInfo = ValueNotifier(null);

  // // Rethink this since its only used for tests
  // Completer<SwapInfo>? swapInfoCompleter;

  double slippage = 0.5;

  late final ValueNotifier<String> slippageString =
      ValueNotifier(slippage.toString());

  void slippageChanged() {
    final slippage_s = slippageString.value;

    final slippage_d = double.tryParse(slippage_s);

    if (slippage_d == null) return;

    slippage = slippage_d;

    checkSwapInfo(); // Recalculate the swap info
  }

  void fromAmountStringChanged() {
    final value = fromAmountString.value;
    final bi = parseFromString(value, fromToken.value?.decimals ?? 0);

    final amount = bi != null
        ? Amount(value: bi, decimals: fromToken.value?.decimals ?? 0)
        : null;

    setFromAmount(amount);
  }

  void toAmountStringChanged() {
    final value = toAmountString.value;
    final bi = parseFromString(value, toToken.value?.decimals ?? 0);

    final amount = bi != null
        ? Amount(value: bi, decimals: toToken.value?.decimals ?? 0)
        : null;

    setToAmount(amount);
  }

  void changePosition() {
    shouldRecalculateSwapType = false;

    final from = fromToken.value;
    final to = toToken.value;

    fromToken.value = to;
    toToken.value = from;

    shouldRecalculateSwapType = true;

    if (lastAmountChanged == LastAmountChanged.From) {
      toAmountString.value = fromAmountString.value;
    } else if (lastAmountChanged == LastAmountChanged.To) {
      fromAmountString.value = toAmountString.value;
    }
  }

  void setFromToken(TokenEntity token) {
    if (token == toToken.value) {
      toToken.value = fromToken.value;
    }
    fromToken.value = token;
  }

  void setToToken(TokenEntity token) {
    if (token == fromToken.value) {
      fromToken.value = toToken.value;
    }
    toToken.value = token;
  }

  void setFromAmount(Amount? amount) {
    if (shouldRecalculateSwapType) lastAmountChanged = LastAmountChanged.From;
    fromAmount.value = amount;
  }

  void setToAmount(Amount? amount) {
    if (shouldRecalculateSwapType) lastAmountChanged = LastAmountChanged.To;
    toAmount.value = amount;
  }

  /// Gets called whenever any of the swap info changes
  /// If all the necessary info is present, it calculates the swap info
  void checkSwapInfo() {
    if (fromToken.value == null ||
        toToken.value == null ||
        (fromAmount.value == null && toAmount.value == null)) {
      swapState.value = SwapState.None;
      return;
    }

    // Debounce the function
    if (shouldRecalculateSwapType == false) return;

    // Set the swap type
    swapType = switch ((fromToken.value, toToken.value, lastAmountChanged!)) {
      (zeniqSmart, _, LastAmountChanged.From) => SwapType.ExactZeniqForToken,
      (zeniqSmart, _, LastAmountChanged.To) => SwapType.ZeniqForExactToken,
      (_, zeniqSmart, LastAmountChanged.From) => SwapType.ExactTokenForZeniq,
      (_, zeniqSmart, LastAmountChanged.To) => SwapType.TokenForExactZeniq,
      (_, _, LastAmountChanged.From) => SwapType.ExactTokenForToken,
      (_, _, LastAmountChanged.To) => SwapType.TokenForExactToken,
    };

    if (lastAmountChanged == LastAmountChanged.From) {
      if (fromAmount.value?.value == BigInt.zero) {
        toAmountString.value = '';
        swapState.value = SwapState.None;
        swapInfo.value = null;
        return;
      }
    }

    if (lastAmountChanged == LastAmountChanged.To) {
      if (toAmount.value?.value == BigInt.zero) {
        fromAmountString.value = '';
        swapState.value = SwapState.None;
        swapInfo.value = null;
        return;
      }
    }

    calculateSwapInfo();
  }

  void calculateSwapInfo() async {
    // swapInfoCompleter = Completer();

    swapInfo.value = await switch (swapType!) {
      SwapType.ExactZeniqForToken => fromSwapInfo(
          path: [wrappedZeniqSmart, toToken.value as EthBasedTokenEntity],
          own: ownAddress,
          fromAmount: fromAmount.value!,
          slippage: slippage,
        ),
      SwapType.ExactTokenForZeniq => fromSwapInfo(
          path: [fromToken.value as EthBasedTokenEntity, wrappedZeniqSmart],
          own: ownAddress,
          fromAmount: fromAmount.value!,
          slippage: slippage,
        ),
      SwapType.ExactTokenForToken => fromSwapInfo(
          path: [
            fromToken.value as EthBasedTokenEntity,
            wrappedZeniqSmart,
            toToken.value as EthBasedTokenEntity,
          ],
          own: ownAddress,
          fromAmount: fromAmount.value!,
          slippage: slippage,
        ),
      SwapType.ZeniqForExactToken => toSwapInfo(
          path: [wrappedZeniqSmart, toToken.value as EthBasedTokenEntity],
          toAmount: toAmount.value!,
          own: ownAddress,
          slippage: slippage,
        ),
      SwapType.TokenForExactZeniq => toSwapInfo(
          path: [fromToken.value as EthBasedTokenEntity, wrappedZeniqSmart],
          toAmount: toAmount.value!,
          own: ownAddress,
          slippage: slippage,
        ),
      SwapType.TokenForExactToken => toSwapInfo(
          path: [
            fromToken.value as EthBasedTokenEntity,
            wrappedZeniqSmart,
            toToken.value as EthBasedTokenEntity
          ],
          toAmount: toAmount.value!,
          own: ownAddress,
          slippage: slippage,
        ),
    };

    swapState.value = swapInfo.value!.needsApproval
        ? SwapState.NeedsTokenApproval
        : SwapState.ReadyForSwap;

    shouldRecalculateSwapType = false;

    switch (swapInfo.value) {
      case FromSwapInfo swapInfo:
        toAmountString.value = swapInfo.amountOut.displayValue.format(5);
        break;
      case ToSwapInfo swapInfo:
        fromAmountString.value = swapInfo.amountIn.displayValue.format(5);
        break;
      default:
    }

    shouldRecalculateSwapType = true;

    // swapInfoCompleter!.complete(swapInfo.value);
  }

  Future<String> swap() async {
    shouldRecalculateSwapType = false;

    if (swapState.value == SwapState.NeedsTokenApproval ||
        swapState.value == SwapState.TokenApprovalError) {
      try {
        final erc20 = ERC20Contract(
          rpc: rpc,
          contractAddress:
              swapInfo.value!.fromToken.asEthBased!.contractAddress,
        );

        final tx = await erc20.approveTx(
          sender: ownAddress,
          spender: zeniqSwapRouter.contractAddress,
          value: switch (swapInfo.value!) {
            FromSwapInfo info => info.fromAmount.value,
            ToSwapInfo info => info.amountInMax.value,
          },
        ) as RawEVMTransactionType0;

        swapState.value = SwapState.WaitingForUserApproval;

        final signed = await signer(
          tx.serializedUnsigned(rpc.type.chainId).toHex,
        );

        swapState.value = SwapState.ApprovingToken;

        final hash = await rpc.sendRawTransaction(signed);

        final successfull = await rpc.waitForTxConfirmation(hash);

        swapState.value =
            successfull ? SwapState.ReadyForSwap : SwapState.TokenApprovalError;
      } catch (e) {
        swapState.value = SwapState.TokenApprovalError;
        shouldRecalculateSwapType = true;
        checkSwapInfo();
        rethrow;
      }
    }

    assert(
      swapState.value == SwapState.ReadyForSwap ||
          swapState.value == SwapState.Error,
      "Swap state is not ready for swap",
    );

    final deadline =
        DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch ~/
            1000;

    final unsignedTX = await switch ((swapType!, swapInfo.value!)) {
      (SwapType.ExactZeniqForToken, FromSwapInfo info) =>
        zeniqSwapRouter.swapExactEthForTokensTransaction(
          amountIn: info.fromAmount.value,
          amountOutMin: info.amountOutMin.value,
          path: info.path,
          to: ownAddress,
          deadline: deadline.toBigInt,
          sender: ownAddress,
        ),
      (SwapType.ExactTokenForZeniq, FromSwapInfo info) =>
        zeniqSwapRouter.swapExactTokensForEthTx(
          amountIn: info.fromAmount.value,
          amountOutMin: info.amountOutMin.value,
          path: info.path,
          to: ownAddress,
          deadline: deadline.toBigInt,
          sender: ownAddress,
        ),
      (SwapType.ExactTokenForToken, FromSwapInfo info) =>
        zeniqSwapRouter.swapExactTokenForTokensTx(
          amountIn: info.fromAmount.value,
          amountOutMin: info.amountOutMin.value,
          path: info.path,
          to: ownAddress,
          deadline: deadline.toBigInt,
          sender: ownAddress,
        ),
      (SwapType.ZeniqForExactToken, ToSwapInfo info) =>
        zeniqSwapRouter.swapEthForExactTokensTx(
          amountOut: info.toAmount.value,
          amountInMax: info.amountInMax.value,
          deadline: deadline.toBigInt,
          path: info.path,
          sender: ownAddress,
          to: ownAddress,
        ),
      (SwapType.TokenForExactZeniq, ToSwapInfo info) =>
        zeniqSwapRouter.swapTokenForExactEthTx(
          amountOut: info.toAmount.value,
          amountInMax: info.amountInMax.value,
          deadline: deadline.toBigInt,
          path: info.path,
          sender: ownAddress,
          to: ownAddress,
        ),
      (SwapType.TokenForExactToken, ToSwapInfo info) =>
        zeniqSwapRouter.swapTokenForExactTokensTx(
          amountOut: info.toAmount.value,
          amountInMax: info.amountInMax.value,
          deadline: deadline.toBigInt,
          path: info.path,
          sender: ownAddress,
          to: ownAddress,
        ),
      _ => throw Exception("Invalid swap type"), // This should never happen
    } as RawEVMTransactionType0;

    swapState.value = SwapState.WaitingForUserApproval;

    try {
      final signedTX = await signer(
        unsignedTX.serializedUnsigned(rpc.type.chainId).toHex,
      );

      swapState.value = SwapState.Broadcasting;

      final hash = await rpc.sendRawTransaction(
        signedTX.startsWith("0x") ? signedTX : "0x$signedTX",
      );

      swapState.value = SwapState.Confirming;

      final successfull = await rpc.waitForTxConfirmation(hash);

      swapState.value = successfull ? SwapState.Swapped : SwapState.Error;

      // Cleanup
      fromAmountString.value = '';
      toAmountString.value = '';
      shouldRecalculateSwapType = true;
      checkSwapInfo();

      return hash;
    } catch (e) {
      swapState.value = SwapState.Error;
      shouldRecalculateSwapType = true;
      checkSwapInfo();
      rethrow;
    }
  }
}

Future<FromSwapInfo> fromSwapInfo({
  required List<EthBasedTokenEntity> path,
  required Amount fromAmount,
  required String own,
  required double slippage,
}) async {
  final contractPath = path.map((e) => e.contractAddress).toList();

  final outputs = await zeniqSwapRouter.getAmountsOut(
    amountIn: fromAmount.value,
    path: contractPath,
  );

  final _s = 1000.toBigInt - Amount.convert(value: slippage, decimals: 1).value;

  final outputValue = outputs.last;

  final minOutputValue = (outputValue * _s) ~/ 1000.toBigInt;

  final bool needsApproval;

  /// Check if the token allowance is enough
  if (path.first != wrappedZeniqSmart) {
    /// Check if the token allowance is enough
    final tokenERC20 = ERC20Contract(
      rpc: rpc,
      contractAddress: path.first.contractAddress,
    );
    final allowance = await tokenERC20.allowance(
      owner: own,
      spender: zeniqSwapRouter.contractAddress,
    );
    needsApproval = allowance < fromAmount.value;
  } else {
    needsApproval = false;
  }

  final feeValue = switch (outputs.length) {
    2 => outputs.first - ((outputs.first * 997.toBigInt) ~/ 1000.toBigInt),
    3 => outputs.first -
        ((outputs.first * 997.toBigInt * 997.toBigInt) ~/ 1000000.toBigInt),
    _ => throw Exception("Invalid path length"),
  };

  final feeAmount = Amount(value: feeValue, decimals: fromAmount.decimals);

  final priceImpact = await calculatePriceImpact(path, fromAmount.value);

  return FromSwapInfo(
    fromAmount: fromAmount,
    amountOutMin: Amount(value: minOutputValue, decimals: path.last.decimals),
    amountOut: Amount(value: outputValue, decimals: path.last.decimals),
    fee: feeAmount,
    priceImpact: priceImpact,
    slippage: slippage,
    fromToken: path.first,
    toToken: path.last,
    needsApproval: needsApproval,
    path: contractPath,
  );
}

Future<ToSwapInfo> toSwapInfo({
  required List<EthBasedTokenEntity> path,
  required Amount toAmount,
  required String own,
  required double slippage,
}) async {
  final contractPath = path.map((e) => e.contractAddress).toList();

  final inputs = await zeniqSwapRouter.getAmountsIn(
    amountOut: toAmount.value,
    path: contractPath,
  );

  final _s = 1000.toBigInt + Amount.convert(value: slippage, decimals: 1).value;

  final inputValue = inputs.first;
  final maxInputValue = (inputValue * _s) ~/ 1000.toBigInt;

  final bool needsApproval;

  if (path.first != wrappedZeniqSmart) {
    /// Check if the token allowance is enough
    final tokenERC20 = ERC20Contract(
      rpc: rpc,
      contractAddress: path.first.contractAddress,
    );
    final allowance = await tokenERC20.allowance(
      owner: own,
      spender: zeniqSwapRouter.contractAddress,
    );
    needsApproval = allowance < maxInputValue;
  } else {
    needsApproval = false;
  }

  final feeValue = switch (inputs.length) {
    2 => inputs.first - ((inputs.first * 997.toBigInt) ~/ 1000.toBigInt),
    3 => inputs.first -
        ((inputs.first * 997.toBigInt * 997.toBigInt) ~/ 1000000.toBigInt),
    _ => throw Exception("Invalid path length"),
  };

  final feeAmount = Amount(value: feeValue, decimals: path.first.decimals);

  final priceImpact = await calculatePriceImpact(path, inputValue);

  return ToSwapInfo(
    amountInMax: Amount(value: maxInputValue, decimals: path.first.decimals),
    amountIn: Amount(value: inputValue, decimals: path.first.decimals),
    toAmount: toAmount,
    priceImpact: priceImpact,
    fee: feeAmount,
    slippage: slippage,
    fromToken: path.first,
    toToken: path.last,
    needsApproval: needsApproval,
    path: contractPath,
  );
}

class InheritedSwapProvider extends InheritedWidget {
  const InheritedSwapProvider({
    super.key,
    required this.swapProvider,
    required super.child,
  });

  final SwapProvider swapProvider;

  static SwapProvider of(BuildContext context) {
    final result =
        context.dependOnInheritedWidgetOfExactType<InheritedSwapProvider>();
    if (result == null) {
      throw Exception('InheritedSwapProvider not found in context');
    }
    return result.swapProvider;
  }

  @override
  bool updateShouldNotify(InheritedSwapProvider oldWidget) {
    return true;
  }
}

Future<double> calculatePriceImpact(
  List<EthBasedTokenEntity> path,
  BigInt amountIn,
) async {
  final pairs = await Future.wait(
    [
      for (var i = 0; i < path.length - 1; i++)
        factory
            .getPair(
              tokenA: path[i].contractAddress,
              tokenB: path[i + 1].contractAddress,
            )
            .then(
              (value) => (
                UniswapV2Pair(
                  rpc: factory.rpc,
                  contractAddress: value,
                ),
                path[i]
              ),
            ),
    ],
  );

  final pairInfos = await Future.wait([
    for (final pair in pairs)
      () async {
        final reserves = await pair.$1.getReserves();
        final token0 = await pair.$1.token0();

        return (reserves, token0, pair.$2);
      }.call()
  ]);

  final quotedAmount = pairInfos.fold(
    amountIn,
    (amountIn, pairInfo) {
      final reserves = pairInfo.$1;
      final token0 = pairInfo.$2;
      final tokenA = pairInfo.$3;

      final price = token0 == tokenA.contractAddress.toLowerCase()
          ? reserves.$2 / reserves.$1
          : reserves.$1 / reserves.$2;

      final amountOut = amountIn.multiply(0.997).multiply(price);
      return amountOut;
    },
  );

  final actualOutputAmount = await zeniqSwapRouter
      .getAmountsOut(
        amountIn: amountIn,
        path: path.map((e) => e.contractAddress).toList(),
      )
      .then((value) => value.last);

  final priceImpact = (quotedAmount - actualOutputAmount) / quotedAmount;

  return priceImpact * 100;
}
