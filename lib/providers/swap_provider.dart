// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:walletkit_dart/walletkit_dart.dart';

final rpc = EvmRpcInterface(ZeniqSmartNetwork);
final zeniqSwapRouter = UniswapV2Router(
  rpc: rpc,
  contractAddress: "0x7963c1bd24E4511A0b14bf148F93e2556AFe3C27",
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
  Error,
}

enum LastAmountChanged {
  From,
  To,
}

sealed class SwapInfo {
  final double slippage;
  final double priceImpact;
  final double fee;
  final TokenEntity fromToken;
  final TokenEntity toToken;
  final bool needsApproval;
  final List<String> path;

  const SwapInfo({
    required this.slippage,
    required this.priceImpact,
    required this.fee,
    required this.fromToken,
    required this.toToken,
    required this.needsApproval,
    required this.path,
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
    required super.fee,
    required super.priceImpact,
    required super.slippage,
    required super.fromToken,
    required super.toToken,
    required super.needsApproval,
    required super.path,
  });

  @override
  String toString() {
    return "FromSwapInfo: From ${fromAmount.displayValue} ${fromToken.symbol} to ${amountOut.displayValue} ${toToken.symbol} with min ${amountOutMin.displayValue} ${toToken.symbol}";
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
    required super.fee,
    required super.priceImpact,
    required super.slippage,
    required super.fromToken,
    required super.toToken,
    required super.needsApproval,
    required super.path,
  });

  @override
  String toString() {
    return "ToSwapInfo: From ${amountIn.displayValue} ${fromToken.symbol} to ${toAmount.displayValue} ${toToken.symbol} with max ${amountInMax.displayValue} ${fromToken.symbol}";
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

    Timer.periodic(_refreshInterval, (_) {
      checkSwapInfo();
    });
  }

  SwapType? swapType;
  bool shouldRecalculateSwapType = true;
  LastAmountChanged? lastAmountChanged;

  final ValueNotifier<SwapState> swapState = ValueNotifier(SwapState.None);
  final ValueNotifier<SwapInfo?> swapInfo = ValueNotifier(null);

  // Rethink this since its only used for tests
  Completer<SwapInfo>? swapInfoCompleter;

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
        return;
      }
    }

    if (lastAmountChanged == LastAmountChanged.To) {
      if (toAmount.value?.value == BigInt.zero) {
        fromAmountString.value = '';
        swapState.value = SwapState.None;
        return;
      }
    }

    // if (switch ((fromAmount.value, toAmount.value)) {
    //   (Amount a, _) => a.value == BigInt.zero,
    //   (_, Amount a) => a.value == BigInt.zero,
    //   _ => true,
    // }) {
    //   toAmountString.value = '';
    //   fromAmountString.value = '';
    //   swapState.value = SwapState.None;

    //   return;
    // }

    calculateSwapInfo();
  }

  void calculateSwapInfo() async {
    swapInfoCompleter = Completer();

    swapInfo.value = await switch (swapType!) {
      SwapType.ExactZeniqForToken => fromSwapInfo(
          path: [wrappedZeniqSmart, toToken.value as EthBasedTokenEntity],
          own: ownAddress,
          fromAmount: fromAmount.value!,
        ),
      SwapType.ExactTokenForZeniq => fromSwapInfo(
          path: [fromToken.value as EthBasedTokenEntity, wrappedZeniqSmart],
          own: ownAddress,
          fromAmount: fromAmount.value!,
        ),
      SwapType.ExactTokenForToken => fromSwapInfo(
          path: [
            fromToken.value as EthBasedTokenEntity,
            wrappedZeniqSmart,
            toToken.value as EthBasedTokenEntity
          ],
          own: ownAddress,
          fromAmount: fromAmount.value!,
        ),
      SwapType.ZeniqForExactToken => toSwapInfo(
          path: [wrappedZeniqSmart, toToken.value as EthBasedTokenEntity],
          toAmount: toAmount.value!,
          own: ownAddress,
        ),
      SwapType.TokenForExactZeniq => toSwapInfo(
          path: [fromToken.value as EthBasedTokenEntity, wrappedZeniqSmart],
          toAmount: toAmount.value!,
          own: ownAddress,
        ),
      SwapType.TokenForExactToken => toSwapInfo(
          path: [
            fromToken.value as EthBasedTokenEntity,
            wrappedZeniqSmart,
            toToken.value as EthBasedTokenEntity
          ],
          toAmount: toAmount.value!,
          own: ownAddress,
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

    swapInfoCompleter!.complete(swapInfo.value);
  }

  Future<String> swap() async {
    if (swapState.value == SwapState.NeedsTokenApproval ||
        swapState.value == SwapState.TokenApprovalError) {
      final erc20 = ERC20Contract(
        rpc: rpc,
        contractAddress: swapInfo.value!.fromToken.asEthBased!.contractAddress,
      );

      final tx = await erc20.approveTx(
        sender: ownAddress,
        spender: zeniqSwapRouter.contractAddress,
        value: switch (swapInfo.value!) {
          FromSwapInfo info => info.fromAmount.value,
          ToSwapInfo info => info.amountInMax.value,
        },
      );

      swapState.value = SwapState.WaitingForUserApproval;

      final signed = await signer(tx.serializedTransactionHex);

      swapState.value = SwapState.ApprovingToken;

      final hash = await rpc.client.sendRawTransaction(signed);

      final successfull = await rpc.waitForTxConfirmation(hash);

      swapState.value =
          successfull ? SwapState.ReadyForSwap : SwapState.TokenApprovalError;
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
    };

    swapState.value = SwapState.WaitingForUserApproval;

    try {
      final signedTX = await signer(unsignedTX.serializedTransactionHex);

      swapState.value = SwapState.Broadcasting;

      final hash = await rpc.client.sendRawTransaction(
        signedTX.startsWith("0x") ? signedTX : "0x$signedTX",
      );

      swapState.value = SwapState.Confirming;

      final successfull = await rpc.waitForTxConfirmation(hash);

      swapState.value = successfull ? SwapState.Swapped : SwapState.Error;

      // Cleanup
      fromAmountString.value = '';
      toAmountString.value = '';

      return hash;
    } catch (e) {
      swapState.value = SwapState.Error;

      rethrow;
    }
  }
}

Future<FromSwapInfo> fromSwapInfo({
  required List<EthBasedTokenEntity> path,
  required Amount fromAmount,
  required String own,
}) async {
  final contractPath = path.map((e) => e.contractAddress).toList();

  final outputs = await zeniqSwapRouter.getAmountsOut(
    amountIn: fromAmount.value,
    path: contractPath,
  );

  final outputValue = outputs.last;
  final minOutputValue = (outputValue * 995.toBigInt) ~/ 1000.toBigInt;

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

  return FromSwapInfo(
    fromAmount: fromAmount,
    amountOutMin: Amount(value: minOutputValue, decimals: path.last.decimals),
    amountOut: Amount(value: outputValue, decimals: path.last.decimals),
    fee: 0,
    priceImpact: 0,
    slippage: 0.5,
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
}) async {
  final contractPath = path.map((e) => e.contractAddress).toList();

  final inputs = await zeniqSwapRouter.getAmountsIn(
    amountOut: toAmount.value,
    path: contractPath,
  );

  final inputValue = inputs.first;
  final maxInputValue = (inputValue * 1005.toBigInt) ~/ 1000.toBigInt;

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

  return ToSwapInfo(
    amountInMax: Amount(value: maxInputValue, decimals: path.first.decimals),
    amountIn: Amount(value: inputValue, decimals: path.first.decimals),
    toAmount: toAmount,
    fee: 0,
    priceImpact: 0,
    slippage: 0.5,
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
