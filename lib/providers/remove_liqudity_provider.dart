import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nomo_ui_kit/components/buttons/primary/nomo_primary_button.dart';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/common/logger.dart';
import 'package:zeniq_swap_frontend/providers/models/pair_info.dart';
import 'package:zeniq_swap_frontend/providers/pool_provider.dart';
import 'package:zeniq_swap_frontend/providers/swap_provider.dart';

final zeniqSwapRouter = UniswapV2Router(
  rpc: rpc,
  contractAddress: "0xEBb0C81b3450520f54282A9ca9996A1960Be7c7A",
);
final zeniqSwapRouterOld = UniswapV2Router(
  rpc: rpc,
  contractAddress: "0x7963c1bd24E4511A0b14bf148F93e2556AFe3C27",
);

enum LastTokenChanged {
  poolToken,
  token0,
  token1,
}

enum RemoveLiqudityState {
  none,
  error,
  needTokenApproval,
  approvingToken,
  waitingForUserApproval,
  tokenApprovalError,

  ready,
  broadcasting,
  confirming,
  removed,
  preview;

  String get buttonText => switch (this) {
        RemoveLiqudityState.approvingToken => "Approving Token",
        RemoveLiqudityState.needTokenApproval => "Approve",
        RemoveLiqudityState.waitingForUserApproval => "Approving",
        RemoveLiqudityState.broadcasting => "Removing",
        RemoveLiqudityState.confirming => "Confirming",
        _ => "Remove",
      };

  bool get buttonEnabled => switch (this) {
        RemoveLiqudityState.approvingToken => false,
        RemoveLiqudityState.broadcasting => false,
        RemoveLiqudityState.confirming => false,
        RemoveLiqudityState.waitingForUserApproval => false,
        RemoveLiqudityState.removed => false,
        _ => true,
      };

  ActionType get buttonType => switch (this) {
        RemoveLiqudityState.needTokenApproval => ActionType.def,
        RemoveLiqudityState.broadcasting => ActionType.loading,
        RemoveLiqudityState.confirming => ActionType.loading,
        RemoveLiqudityState.approvingToken => ActionType.loading,
        RemoveLiqudityState.ready => ActionType.def,
        RemoveLiqudityState.waitingForUserApproval => ActionType.loading,
        _ => ActionType.nonInteractive,
      };

  bool get inputsEnabled => switch (this) {
        RemoveLiqudityState.broadcasting => false,
        RemoveLiqudityState.confirming => false,
        RemoveLiqudityState.waitingForUserApproval => false,
        RemoveLiqudityState.removed => false,
        RemoveLiqudityState.approvingToken => false,
        _ => true,
      };
}

class WithdrawInfo {
  final PairInfoEntity pairInfo;
  final Amount poolTokenAmount;
  final Amount amount0Received;
  final Amount amount1Received;
  final Amount amount0MinReceived;
  final Amount amount1MinReceived;
  final BigInt deadline;
  final String address;
  final double poolShareDifference;

  WithdrawInfo._({
    required this.pairInfo,
    required this.amount0Received,
    required this.amount1Received,
    required this.amount0MinReceived,
    required this.amount1MinReceived,
    required this.deadline,
    required this.poolShareDifference,
    required this.address,
    required this.poolTokenAmount,
  });

  Amount get minTokenAmount {
    return pairInfo.token0IsZeniq ? amount1MinReceived : amount0MinReceived;
  }

  Amount get minZeniqAmount {
    return pairInfo.token0IsZeniq ? amount0MinReceived : amount1MinReceived;
  }

  factory WithdrawInfo.create({
    required PairInfoEntity pairInfo,
    required Amount poolTokenAmount,
    required Amount amount0Received,
    required Amount amount1Received,
    required double slippage,
    required String address,
  }) {
    final deadline = BigInt.from(
      DateTime.now().add(Duration(minutes: 1)).millisecondsSinceEpoch ~/ 1000,
    );

    final poolShare =
        pairInfo.calculatePoolShare(amount0Received, amount1Received);

    final slippageMultiplier = 1 - slippage;

    final amount0MinReceived = Amount(
      value: amount0Received.value.multiply(slippageMultiplier),
      decimals: amount0Received.decimals,
    );

    final amount1MinReceived = Amount(
      value: amount1Received.value.multiply(slippageMultiplier),
      decimals: amount1Received.decimals,
    );

    return WithdrawInfo._(
      pairInfo: pairInfo,
      deadline: deadline,
      poolShareDifference: poolShare,
      address: address,
      poolTokenAmount: poolTokenAmount,
      amount0Received: amount0Received,
      amount1Received: amount1Received,
      amount0MinReceived: amount0MinReceived,
      amount1MinReceived: amount1MinReceived,
    );
  }

  Future<RawEVMTransactionType0> createRemoveLiquidityTransaction(
      UniswapV2Router router) {
    if (router.contractAddress == zeniqSwapRouterOld.contractAddress) {
      return router
          .removeLiquidityETHTx(
            token: pairInfo.token.contractAddress,
            liquidity: poolTokenAmount.value,
            amountTokenMin: minTokenAmount.value,
            amountETHMin: minZeniqAmount.value,
            deadline: deadline,
            to: address,
            sender: address,
          )
          .then((value) => value as RawEVMTransactionType0);
    }

    return router
        .removeLiquidityTx(
          tokenA: pairInfo.token0.contractAddress,
          tokenB: pairInfo.token1.contractAddress,
          liquidity: poolTokenAmount.value,
          amountAMin: amount0MinReceived.value,
          amountBMin: amount1MinReceived.value,
          deadline: deadline,
          to: address,
          sender: address,
        )
        .then((value) => value as RawEVMTransactionType0);
  }

  @override
  String toString() {
    return "Removed ${amount0Received.displayDouble.toStringAsFixed(2)} ${pairInfo.token0.symbol} and ${amount1Received.displayDouble.toStringAsFixed(2)} ${pairInfo.token1.symbol}";
  }
}

const refreshIntervall = Duration(seconds: 30);

class RemoveLiqudityProvider {
  final PoolProvider poolProvider;

  final ValueNotifier<OwnedPairInfo> pairInfoNotifier;

  OwnedPairInfo get pairInfo => pairInfoNotifier.value;

  ERC20Entity get token0 => pairInfo.token0;
  ERC20Entity get token1 => pairInfo.token1;

  final ValueNotifier<String?> addressNotifier;
  String? get address => addressNotifier.value;

  final ValueNotifier<double> slippageNotifier;

  late final ValueNotifier<String> poolTokenInputNotifier = ValueNotifier("")
    ..addListener(poolTokenStringChanged);
  late final ValueNotifier<String> token0InputNotifier = ValueNotifier("")
    ..addListener(token0StringChanged);

  late final ValueNotifier<String> token1InputNotifier = ValueNotifier("")
    ..addListener(token1StringChanged);

  late final ValueNotifier<Amount?> poolTokenAmountNotifier =
      ValueNotifier(null)
        ..addListener(updateOtherAmounts)
        ..addListener(checkRemoveInfo);
  late final ValueNotifier<Amount?> token0AmountNotifier = ValueNotifier(null)
    ..addListener(updateOtherAmounts)
    ..addListener(checkRemoveInfo);
  late final ValueNotifier<Amount?> token1AmountNotifier = ValueNotifier(null)
    ..addListener(updateOtherAmounts)
    ..addListener(checkRemoveInfo);

  late final ValueNotifier<String?> inputErrorNotifer = ValueNotifier(null);

  final ValueNotifier<WithdrawInfo?> removeInfoNotifier = ValueNotifier(null);

  late final removeState = ValueNotifier(RemoveLiqudityState.none)
    ..addListener(removeStateChanged);

  UniswapV2Router get router => switch (pairInfo.type) {
        PairType.legacy => zeniqSwapRouterOld,
        PairType.v2 => zeniqSwapRouter,
      };

  LastTokenChanged? lastAmountChanged;

  bool recalculate = true;

  double get slippage => slippageNotifier.value;

  final bool needToBroadcast;

  bool get balanceError => inputErrorNotifer.value != null;

  final Future<String> Function(String tx) signer;

  late final Timer refreshTimer;

  bool disposed = false;

  RemoveLiqudityProvider({
    required OwnedPairInfo pairInfo,
    required this.poolProvider,
    required this.addressNotifier,
    required this.slippageNotifier,
    required this.needToBroadcast,
    required this.signer,
  }) : pairInfoNotifier = ValueNotifier(pairInfo) {
    refresh();
    refreshTimer = Timer.periodic(refreshIntervall, (_) {
      refresh();
    });
  }

  void removeStateChanged() {
    final newState = removeState.value;

    if (newState == RemoveLiqudityState.removed) {
      refresh();
      return;
    }
  }

  void refresh() async {
    final updatedPairInfo = await pairInfo.update(address);
    pairInfoNotifier.value = updatedPairInfo;
    poolProvider.updatePair(pairInfo.pair.contractAddress, updatedPairInfo);
  }

  void checkRemoveInfo() async {
    if (recalculate == false) return;

    removeState.value = switch ((this.address, removeState.value)) {
      (null, _) => RemoveLiqudityState.preview,
      (_, RemoveLiqudityState.preview) => RemoveLiqudityState.none,
      _ => removeState.value,
    };

    if (balanceError) {
      removeState.value = RemoveLiqudityState.none;
      return;
    }

    final poolTokenAmount = poolTokenAmountNotifier.value;
    final token0Amount = token0AmountNotifier.value;
    final token1Amount = token1AmountNotifier.value;

    if (poolTokenAmount == null ||
        poolTokenAmount.value == BigInt.zero ||
        token0Amount == null ||
        token0Amount.value == BigInt.zero ||
        token1Amount == null ||
        token1Amount.value == BigInt.zero) {
      removeState.value = RemoveLiqudityState.none;
      return;
    }

    final address = this.address ?? arbitrumTestWallet;

    removeInfoNotifier.value = WithdrawInfo.create(
      pairInfo: pairInfo,
      amount0Received: token0Amount,
      amount1Received: token1Amount,
      poolTokenAmount: poolTokenAmount,
      slippage: slippage,
      address: address,
    );

    final hasApproval = await checkTokenApproval(
      poolTokenAmount,
      address,
    );

    if (hasApproval == false) {
      removeState.value = RemoveLiqudityState.needTokenApproval;
      return;
    }

    removeState.value = RemoveLiqudityState.ready;
  }

  Future<String> remove() async {
    assert(removeState.value == RemoveLiqudityState.ready ||
        removeState.value == RemoveLiqudityState.needTokenApproval);

    final removeInfo = removeInfoNotifier.value;

    assert(removeInfo != null);

    if (removeState.value == RemoveLiqudityState.needTokenApproval ||
        removeState.value == RemoveLiqudityState.tokenApprovalError) {
      try {
        final unsignedTX = await pairInfo.erc20Contract.approveTx(
          sender: removeInfo!.address,
          spender: router.contractAddress,
          value: BigInt.tryParse(
            "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
          )!,
        ) as RawEVMTransactionType0;

        removeState.value = RemoveLiqudityState.waitingForUserApproval;

        final String hash;
        if (needToBroadcast) {
          final signedTX = await signer(
            unsignedTX.serializedUnsigned(rpc.type.chainId).toHex,
          );

          removeState.value = RemoveLiqudityState.approvingToken;

          hash = await rpc.sendRawTransaction(
            signedTX.startsWith("0x") ? signedTX : "0x$signedTX",
          );
        } else {
          removeState.value = RemoveLiqudityState.approvingToken;
          hash = await signer(
            unsignedTX.serializedUnsigned(rpc.type.chainId).toHex,
          );
        }

        final successfull = await rpc.waitForTxConfirmation(hash);

        removeState.value = successfull
            ? RemoveLiqudityState.ready
            : RemoveLiqudityState.tokenApprovalError;
      } catch (e) {
        removeState.value = RemoveLiqudityState.tokenApprovalError;
        recalculate = true;
        checkRemoveInfo();
        rethrow;
      }
    }

    try {
      final unsignedRawTx =
          await removeInfo!.createRemoveLiquidityTransaction(router);
      removeState.value = RemoveLiqudityState.waitingForUserApproval;
      final String hash;
      if (needToBroadcast) {
        final signedTX = await signer(
          unsignedRawTx.serializedUnsigned(rpc.type.chainId).toHex,
        );

        removeState.value = RemoveLiqudityState.broadcasting;

        hash = await rpc.sendRawTransaction(
          signedTX.startsWith("0x") ? signedTX : "0x$signedTX",
        );
      } else {
        hash = await signer(
          unsignedRawTx.serializedUnsigned(rpc.type.chainId).toHex,
        );
      }

      removeState.value = RemoveLiqudityState.confirming;

      final successfull = await rpc.waitForTxConfirmation(hash);

      if (disposed) return hash;

      removeState.value =
          successfull ? RemoveLiqudityState.removed : RemoveLiqudityState.error;

      // Cleanup
      token0InputNotifier.value = '';
      token1InputNotifier.value = '';
      recalculate = true;
      checkRemoveInfo();

      return hash;
    } catch (e) {
      if (disposed == false) {
        removeState.value = RemoveLiqudityState.error;
        recalculate = true;
        checkRemoveInfo();
      }
      rethrow;
    }
  }

  void setPoolTokenPercentage(double percentage) {
    final newAmount = pairInfo.pairTokenAmountAmount.displayDouble * percentage;

    poolTokenInputNotifier.value = newAmount.toString();
  }

  void token0StringChanged() {
    final value = token0InputNotifier.value;
    final bi = parseFromString(value, token0.decimals);

    final amount =
        bi != null ? Amount(value: bi, decimals: token0.decimals) : null;

    if (recalculate) lastAmountChanged = LastTokenChanged.token0;

    token0AmountNotifier.value = amount;
  }

  void token1StringChanged() {
    final value = token1InputNotifier.value;
    final bi = parseFromString(value, token1.decimals);

    final amount =
        bi != null ? Amount(value: bi, decimals: token1.decimals) : null;

    if (recalculate) lastAmountChanged = LastTokenChanged.token1;

    token1AmountNotifier.value = amount;
  }

  void poolTokenStringChanged() {
    final value = poolTokenInputNotifier.value;
    final bi = parseFromString(value, token0.decimals);

    final amount =
        bi != null ? Amount(value: bi, decimals: token0.decimals) : null;

    if (recalculate) lastAmountChanged = LastTokenChanged.poolToken;

    poolTokenAmountNotifier.value = amount;
  }

  void updateOtherAmounts() {
    if (recalculate == false) return;
    recalculate = false;
    if (lastAmountChanged == LastTokenChanged.poolToken) {
      final poolAmount = poolTokenAmountNotifier.value;
      if (poolAmount == null) return;

      final (amount0, amount1) =
          pairInfo.calculateTokeAmountsFromPoolAmount(poolAmount);

      token0AmountNotifier.value = amount0;
      token0InputNotifier.value = amount0.displayDouble.toString();
      token1AmountNotifier.value = amount1;
      token1InputNotifier.value = amount1.displayDouble.toString();
    } else if (lastAmountChanged == LastTokenChanged.token0) {
      final amount0 = token0AmountNotifier.value;
      if (amount0 == null) return;

      final amount1 = pairInfo.calculateAmount1FromAmount0(amount0);
      final poolAmount = pairInfo.calculatePoolTokenAmountFromAmount0(amount0);

      token1AmountNotifier.value = amount1;
      token1InputNotifier.value = amount1.displayDouble.toString();
      poolTokenAmountNotifier.value = poolAmount;
      poolTokenInputNotifier.value = poolAmount.displayDouble.toString();
    } else if (lastAmountChanged == LastTokenChanged.token1) {
      final amount1 = token1AmountNotifier.value;
      if (amount1 == null) return;

      final amount0 = pairInfo.calculateAmount0FromAmount1(amount1);
      final poolAmount = pairInfo.calculatePoolTokenAmountFromAmount1(amount1);

      token0AmountNotifier.value = amount0;
      token0InputNotifier.value = amount0.displayDouble.toString();
      poolTokenAmountNotifier.value = poolAmount;
      poolTokenInputNotifier.value = poolAmount.displayDouble.toString();
    }

    if (poolTokenAmountNotifier.value != null &&
        poolTokenAmountNotifier.value!.value >
            pairInfo.pairTokenAmountAmount.value) {
      inputErrorNotifer.value = "Insufficient Balance";
    } else {
      inputErrorNotifer.value = null;
    }

    recalculate = true;
  }

  void dispose() {
    refreshTimer.cancel();

    removeState
      ..removeListener(removeStateChanged)
      ..dispose();

    poolTokenInputNotifier
      ..removeListener(poolTokenStringChanged)
      ..dispose();
    token0InputNotifier
      ..removeListener(token0StringChanged)
      ..dispose();
    token1InputNotifier
      ..removeListener(token1StringChanged)
      ..dispose();

    disposed = true;
  }

  Future<bool> checkTokenApproval(
    Amount poolAmount,
    String address,
  ) async {
    try {
      final allowance = await pairInfo.erc20Contract.allowance(
        spender: router.contractAddress,
        owner: address,
      );
      return allowance >= poolAmount.value;
    } catch (e, s) {
      throw e;
    }
  }
}
