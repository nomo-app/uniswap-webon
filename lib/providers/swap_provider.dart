// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/common/extensions.dart';

const zeniqTokenWrapper = ERC20Entity(
  chainID: 383414847825,
  name: 'ZENIQ',
  symbol: 'ZENIQ Token',
  decimals: 18,
  contractAddress: "0x5b52bfB8062Ce664D74bbCd4Cd6DC7Df53Fd7233",
);
final rpc = EvmRpcInterface(
  type: ZeniqSmartNetwork,
  useQueuedManager: false,
  clients: [
    EvmRpcClient(zeniqSmartRPCEndpoint),
  ],
);
final zeniqSwapRouter = UniswapV2Router(
  rpc: rpc,
  contractAddress: "0xEBb0C81b3450520f54282A9ca9996A1960Be7c7A",
);
final zfactory = UniswapV2Factory(
  rpc: rpc,
  contractAddress: "0x40a4E23Cc9E57161699Fd37c0A4d8bca383325f3",
);
const _refreshInterval = Duration(seconds: 15);

enum SwapType {
  ExactTokenForToken,
  TokenForExactToken;

  bool get isFrom => switch (this) {
        SwapType.ExactTokenForToken => true,
        _ => false,
      };
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
  InsufficientLiquidity;

  bool get inputEnabled => switch (this) {
        SwapState.None ||
        SwapState.ReadyForSwap ||
        SwapState.Error ||
        SwapState.TokenApprovalError ||
        SwapState.NeedsTokenApproval ||
        SwapState.InsufficientLiquidity =>
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
  final CoinEntity fromToken;
  final CoinEntity toToken;
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

  Amount get fromAmount => switch (this) {
        FromSwapInfo info => info.fromAmount,
        ToSwapInfo info => info.amountIn,
      };

  Amount get toAmount => switch (this) {
        FromSwapInfo info => info.amountOut,
        ToSwapInfo info => info.toAmount,
      };
}

final class FromSwapInfo extends SwapInfo {
  final Amount amountOutMin;
  final Amount fromAmount;
  final Amount amountOut;

  double get rate {
    if (fromToken.decimals == toToken.decimals) {
      return amountOut.value / fromAmount.value;
    } else if (fromToken.decimals > toToken.decimals) {
      return amountOut.value /
          fromAmount.value /
          BigInt.from(10).pow(fromToken.decimals - toToken.decimals).toDouble();
    } else {
      return amountOut.value /
          fromAmount.value *
          BigInt.from(10).pow(toToken.decimals - fromToken.decimals).toDouble();
    }
  }

  String getPrice(bool inverse) {
    if (inverse) {
      return "${(1 / rate).toString().format(3)} ${fromToken.name} per ${toToken.name}";
    }
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
    if (fromToken.decimals == toToken.decimals) {
      return amountIn.value / toAmount.value;
    } else if (fromToken.decimals > toToken.decimals) {
      return amountIn.value /
          toAmount.value /
          BigInt.from(10).pow(fromToken.decimals - toToken.decimals).toDouble();
    } else {
      return amountIn.value /
          toAmount.value *
          BigInt.from(10).pow(toToken.decimals - fromToken.decimals).toDouble();
    }
  }

  String getPrice(bool inverse) {
    if (inverse) {
      return "${rate.toString().format(3)} ${fromToken.symbol} per ${toToken.symbol}";
    }
    return "${(1 / rate).toString().format(3)} ${toToken.symbol} per ${fromToken.symbol}";
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

  final ValueNotifier<ERC20Entity?> fromToken =
      ValueNotifier(zeniqTokenWrapper);
  final ValueNotifier<ERC20Entity?> toToken = ValueNotifier(null);
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

    final String oldValue;
    if (lastAmountChanged == LastAmountChanged.From) {
      oldValue = fromAmountString.value;

      fromAmountString.value = '';
    } else {
      oldValue = toAmountString.value;

      toAmountString.value = '';
    }

    swapInfo.value = null;

    shouldRecalculateSwapType = true;

    if (lastAmountChanged == LastAmountChanged.From) {
      toAmountString.value = oldValue;
    } else {
      fromAmountString.value = oldValue;
    }
  }

  void setFromToken(ERC20Entity token) {
    if (token == toToken.value) {
      toToken.value = fromToken.value;
    }
    fromToken.value = token;
  }

  void setToToken(ERC20Entity token) {
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
    swapType = switch (lastAmountChanged!) {
      LastAmountChanged.From => SwapType.ExactTokenForToken,
      LastAmountChanged.To => SwapType.TokenForExactToken,
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

    final fromToken = this.fromToken.value!;
    final toToken = this.toToken.value!;

    final containsZeniq =
        fromToken == zeniqTokenWrapper || toToken == zeniqTokenWrapper;

    final path = [
      fromToken,
      if (containsZeniq == false) zeniqTokenWrapper,
      toToken
    ];

    swapInfo.value = await switch (swapType!) {
      SwapType.ExactTokenForToken => fromSwapInfo(
          path: path,
          own: ownAddress,
          fromAmount: fromAmount.value!,
          slippage: slippage,
        ),
      SwapType.TokenForExactToken => toSwapInfo(
          path: path,
          toAmount: toAmount.value!,
          own: ownAddress,
          slippage: slippage,
        ),
    };

    swapState.value = swapInfo.value == null
        ? SwapState.InsufficientLiquidity
        : swapInfo.value!.needsApproval
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
      case null:
        if (swapType!.isFrom) {
          toAmountString.value = '';
        } else {
          fromAmountString.value = '';
        }
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
          value: BigInt.tryParse(
            "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
          )!,
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
      (SwapType.ExactTokenForToken, FromSwapInfo info) =>
        zeniqSwapRouter.swapExactTokenForTokensTx(
          amountIn: info.fromAmount.value,
          amountOutMin: info.amountOutMin.value,
          path: info.path,
          to: ownAddress,
          deadline: deadline.toBigInt,
          sender: ownAddress,
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

Future<FromSwapInfo?> fromSwapInfo({
  required List<ERC20Entity> path,
  required Amount fromAmount,
  required String own,
  required double slippage,
}) async {
  final contractPath = path.map((e) => e.contractAddress).toList();
  final List<BigInt> outputs;
  try {
    outputs = await zeniqSwapRouter.getAmountsOut(
      amountIn: fromAmount.value,
      path: contractPath,
    );
    if (outputs.last == BigInt.zero) return null;
  } catch (e) {
    return null;
  }

  final _s = 1000.toBigInt - Amount.convert(value: slippage, decimals: 1).value;

  final outputValue = outputs.last;

  final minOutputValue = (outputValue * _s) ~/ 1000.toBigInt;

  final bool needsApproval;

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

  final firstOutput = outputs.first;

  final feeValue = switch (outputs.length) {
    _ when firstOutput < 1000.toBigInt => 0.toBigInt, // No fee
    2 => firstOutput - ((firstOutput * 997.toBigInt) ~/ 1000.toBigInt),
    3 => firstOutput -
        ((firstOutput * 997.toBigInt * 997.toBigInt) ~/ 1000000.toBigInt),
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

Future<ToSwapInfo?> toSwapInfo({
  required List<ERC20Entity> path,
  required Amount toAmount,
  required String own,
  required double slippage,
}) async {
  final contractPath = path.map((e) => e.contractAddress).toList();

  final List<BigInt> inputs;

  try {
    inputs = await zeniqSwapRouter.getAmountsIn(
      amountOut: toAmount.value,
      path: contractPath,
    );
    if (inputs.first == BigInt.zero) return null;
  } catch (e) {
    return null;
  }

  final _s = 1000.toBigInt + Amount.convert(value: slippage, decimals: 1).value;

  final inputValue = inputs.first;
  final maxInputValue = (inputValue * _s) ~/ 1000.toBigInt;

  final bool needsApproval;

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

  final feeValue = switch (inputs.length) {
    _ when inputValue < 1000.toBigInt => 0.toBigInt, // No fee
    2 => inputValue - ((inputValue * 997.toBigInt) ~/ 1000.toBigInt),
    3 => inputValue -
        ((inputValue * 997.toBigInt * 997.toBigInt) ~/ 1000000.toBigInt),
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
  List<ERC20Entity> path,
  BigInt amountIn,
) async {
  final pairs = await Future.wait(
    [
      for (var i = 0; i < path.length - 1; i++)
        zfactory
            .getPair(
              tokenA: path[i].contractAddress,
              tokenB: path[i + 1].contractAddress,
            )
            .then(
              (value) => (
                UniswapV2Pair(
                  rpc: zfactory.rpc,
                  contractAddress: value,
                ),
                path[i],
                path[i + 1],
              ),
            ),
    ],
  );

  final pairInfos = await Future.wait([
    for (final pair in pairs)
      () async {
        final (_pair, path1, path2) = pair;

        final reserves = await _pair.getReserves();
        final token0Contract = await _pair.token0();
        final token1Contract = await _pair.token1();

        final token0 = path.singleWhere(
          (erc20) => erc20.lowerCaseAddress == token0Contract,
        );

        final token1 = path.singleWhere(
          (erc20) => erc20.lowerCaseAddress == token1Contract,
        );

        return ((token0, reserves.$1), (token1, reserves.$2), (path1, path2));
      }.call()
  ]);

  final quotedAmount = pairInfos.fold(
    amountIn,
    (amountIn, pairInfo) {
      final (token0Info, token1Info, path) = pairInfo;

      final token0Decimals = token0Info.$1.decimals;
      final token1Decimals = token1Info.$1.decimals;
      final decimalsFactor =
          BigInt.from(10).pow((token0Decimals - token1Decimals).abs());

      var price = token0Info.$1 == path.$1
          ? token1Info.$2 / token0Info.$2
          : token0Info.$2 / token1Info.$2;

      if (path.$1.decimals < path.$2.decimals) {
        amountIn = amountIn * decimalsFactor; // Correct for decimals
        price = price / decimalsFactor.toInt();
      } else {
        price = price * decimalsFactor.toInt();
      }

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
