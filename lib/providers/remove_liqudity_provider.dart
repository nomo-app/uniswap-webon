import 'package:flutter/foundation.dart';
import 'package:nomo_ui_kit/components/buttons/primary/nomo_primary_button.dart';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/common/async_value.dart';
import 'package:zeniq_swap_frontend/common/logger.dart';
import 'package:zeniq_swap_frontend/providers/balance_provider.dart';
import 'package:zeniq_swap_frontend/providers/models/pair_info.dart';
import 'package:zeniq_swap_frontend/providers/pool_provider.dart';
import 'package:zeniq_swap_frontend/providers/swap_provider.dart';

final zeniqSwapRouterOld = UniswapV2Router(
  rpc: rpc,
  contractAddress: "0x7963c1bd24E4511A0b14bf148F93e2556AFe3C2",
);

enum LastTokenChanged {
  token0,
  token1,
}

enum AddLiquidityState {
  none,
  error,
  needTokenApproval,
  waitingForUserApproval,
  tokenApprovalError,
  ready,
  broadcasting,
  confirming,
  deposited,
  preview;

  String get buttonText => switch (this) {
        AddLiquidityState.needTokenApproval => "Approve",
        AddLiquidityState.waitingForUserApproval => "Approving",
        AddLiquidityState.broadcasting => "Depositing",
        AddLiquidityState.confirming => "Confirming",
        _ => "Deposit",
      };

  bool get buttonEnabled => switch (this) {
        AddLiquidityState.broadcasting => false,
        AddLiquidityState.confirming => false,
        AddLiquidityState.waitingForUserApproval => false,
        AddLiquidityState.deposited => false,
        _ => true,
      };

  ActionType get buttonType => switch (this) {
        AddLiquidityState.needTokenApproval => ActionType.def,
        AddLiquidityState.broadcasting => ActionType.loading,
        AddLiquidityState.confirming => ActionType.loading,
        AddLiquidityState.ready => ActionType.def,
        AddLiquidityState.waitingForUserApproval => ActionType.loading,
        _ => ActionType.nonInteractive,
      };

  bool get inputsEnabled => switch (this) {
        AddLiquidityState.broadcasting => false,
        AddLiquidityState.confirming => false,
        AddLiquidityState.waitingForUserApproval => false,
        AddLiquidityState.deposited => false,
        _ => true,
      };
}

class DepositInfo {
  final PairInfoEntity pairInfo;
  final Amount amount0;
  final Amount amount1;
  final Amount amount0Min;
  final Amount amount1Min;
  final BigInt deadline;
  final String address;
  final double poolShare;

  DepositInfo._({
    required this.pairInfo,
    required this.amount0,
    required this.amount1,
    required this.amount0Min,
    required this.amount1Min,
    required this.deadline,
    required this.poolShare,
    required this.address,
  });

  factory DepositInfo.create({
    required PairInfoEntity pairInfo,
    required Amount amount0,
    required Amount amount1,
    required double slippage,
    required String address,
  }) {
    final deadline = BigInt.from(
      DateTime.now().add(Duration(minutes: 1)).millisecondsSinceEpoch ~/ 1000,
    );

    final poolShare = pairInfo.calculatePoolShare(amount0, amount1);

    final slippageMultiplier = 1 - slippage;

    final amount0Min = Amount(
      value: amount0.value.multiply(slippageMultiplier),
      decimals: amount0.decimals,
    );

    final amount1Min = Amount(
      value: amount1.value.multiply(slippageMultiplier),
      decimals: amount1.decimals,
    );

    return DepositInfo._(
      pairInfo: pairInfo,
      amount0: amount0,
      amount1: amount1,
      amount0Min: amount0Min,
      amount1Min: amount1Min,
      deadline: deadline,
      poolShare: poolShare,
      address: address,
    );
  }

  Future<RawEVMTransactionType0> createAddLiquidityTransaction() {
    return zeniqSwapRouter
        .addLiquidityTx(
          tokenA: pairInfo.token0.contractAddress,
          tokenB: pairInfo.token1.contractAddress,
          amountADesired: amount0.value,
          amountBDesired: amount1.value,
          amountAMin: amount0Min.value,
          amountBMin: amount1Min.value,
          deadline: deadline,
          to: address,
          sender: address,
        )
        .then((value) => value as RawEVMTransactionType0);
  }

  @override
  String toString() {
    return "Provided ${amount0.displayDouble.toStringAsFixed(2)} ${pairInfo.token0.symbol} and ${amount1.displayDouble.toStringAsFixed(2)} ${pairInfo.token1.symbol}";
  }
}

class AddLiquidityProvider {
  final PairInfoEntity pairInfo;

  ERC20Entity get token0 => pairInfo.token0;
  ERC20Entity get token1 => pairInfo.token1;

  final ValueNotifier<String?> addressNotifier;
  String? get address => addressNotifier.value;

  final ValueNotifier<double> slippageNotifier;

  final ValueNotifier<String> token0InputNotifier = ValueNotifier("");
  final ValueNotifier<String> token1InputNotifier = ValueNotifier("");

  final ValueNotifier<String?> token0ErrorNotifier = ValueNotifier(null);
  final ValueNotifier<String?> token1ErrorNotifier = ValueNotifier(null);

  final ValueNotifier<Amount?> token0AmountNotifier = ValueNotifier(null);
  final ValueNotifier<Amount?> token1AmountNotifier = ValueNotifier(null);

  late final ValueNotifier<AsyncValue<Amount>> token0BalanceNotifier;
  late final ValueNotifier<AsyncValue<Amount>> token1BalanceNotifier;

  final ValueNotifier<DepositInfo?> depositInfoNotifier = ValueNotifier(null);

  final ValueNotifier<AddLiquidityState> depositState =
      ValueNotifier(AddLiquidityState.none);

  LastTokenChanged? lastTokenChanged;

  bool recalculateInputs = true;

  double get slippage => slippageNotifier.value;

  final bool needToBroadcast;

  final Future<String> Function(String tx) signer;

  AddLiquidityProvider({
    required this.pairInfo,
    required BalanceProvider assetNotifier,
    required this.addressNotifier,
    required this.slippageNotifier,
    required this.needToBroadcast,
    required this.signer,
  }) {
    token0BalanceNotifier = assetNotifier.balanceNotifierForToken(token0)
      ..addListener(checkToken0Balance);
    token1BalanceNotifier = assetNotifier.balanceNotifierForToken(token1)
      ..addListener(checkToken1Balance);

    token0InputNotifier.addListener(token0InputChanged);

    token1InputNotifier.addListener(token1InputChanged);

    token0AmountNotifier
      ..addListener(calculateToken1)
      ..addListener(checkDepositInfo);
    token1AmountNotifier
      ..addListener(calculateToken0)
      ..addListener(checkDepositInfo);
  }

  bool checkToken0Balance() {
    final balance = token0BalanceNotifier.value.valueOrNull;
    if (balance == null) return false;
    final amount = token0AmountNotifier.value;
    if (amount == null) return false;

    if (balance < amount) {
      token0ErrorNotifier.value = "Insufficient balance";
      return false;
    } else {
      token0ErrorNotifier.value = null;
      return true;
    }
  }

  bool checkToken1Balance() {
    final balance = token1BalanceNotifier.value.valueOrNull;
    if (balance == null) return false;
    final amount = token1AmountNotifier.value;
    if (amount == null) return false;

    if (balance < amount) {
      token1ErrorNotifier.value = "Insufficient balance";
      return false;
    } else {
      token1ErrorNotifier.value = null;
      return true;
    }
  }

  void checkDepositInfo() async {
    if (recalculateInputs == false) return;

    depositState.value = switch ((this.address, depositState.value)) {
      (null, _) => AddLiquidityState.preview,
      (_, AddLiquidityState.preview) => AddLiquidityState.none,
      _ => depositState.value,
    };

    final address = this.address ?? arbitrumTestWallet;

    final token0BalanceValid = checkToken0Balance();
    final token1BalanceValid = checkToken1Balance();

    if (token0BalanceValid == false || token1BalanceValid == false) {
      depositState.value = AddLiquidityState.none;
      return;
    }

    final amount0 = token0AmountNotifier.value;
    final amount1 = token1AmountNotifier.value;

    if (amount0 == null ||
        amount0.value == BigInt.zero ||
        amount1 == null ||
        amount1.value == BigInt.zero) {
      depositState.value = AddLiquidityState.none;
      return;
    }

    depositInfoNotifier.value = DepositInfo.create(
      pairInfo: pairInfo,
      amount0: amount0,
      amount1: amount1,
      slippage: slippage,
      address: address,
    );

    final (token0HasApproval, token1HasApproval) = await checkTokenApprovals(
      amount0,
      amount1,
      address,
    );

    Logger.log("token0HasApproval: $token0HasApproval");
    Logger.log("token1HasApproval: $token1HasApproval");

    if (token0HasApproval == false || token1HasApproval == false) {
      depositState.value = AddLiquidityState.needTokenApproval;
      return;
    }

    depositState.value = AddLiquidityState.ready;
  }

  Future<String> deposit() async {
    assert(
      depositState.value == AddLiquidityState.ready ||
          depositState.value == AddLiquidityState.needTokenApproval,
    );

    final depositInfo = depositInfoNotifier.value;

    assert(depositInfo != null);

    if (depositState.value == AddLiquidityState.needTokenApproval) {
      Logger.log("Approving");
    }

    Logger.log("Depositing");

    try {
      final unsignedRawTx = await depositInfo!.createAddLiquidityTransaction();
      depositState.value = AddLiquidityState.waitingForUserApproval;
      final String hash;
      if (needToBroadcast) {
        final signedTX = await signer(
          unsignedRawTx.serializedUnsigned(rpc.type.chainId).toHex,
        );

        depositState.value = AddLiquidityState.broadcasting;

        hash = await rpc.sendRawTransaction(
          signedTX.startsWith("0x") ? signedTX : "0x$signedTX",
        );
      } else {
        hash = await signer(
          unsignedRawTx.serializedUnsigned(rpc.type.chainId).toHex,
        );
      }

      depositState.value = AddLiquidityState.confirming;

      final successfull = await rpc.waitForTxConfirmation(hash);

      depositState.value =
          successfull ? AddLiquidityState.deposited : AddLiquidityState.error;

      // Cleanup
      token0InputNotifier.value = '';
      token1InputNotifier.value = '';
      recalculateInputs = true;
      checkDepositInfo();

      return hash;
    } catch (e) {
      depositState.value = AddLiquidityState.error;
      recalculateInputs = true;
      rethrow;
    }
  }

  Future<(bool, bool)> checkTokenApprovals(
    Amount amount0,
    Amount amount1,
    String address,
  ) async {
    final results = await Future.wait([
      token0.isApproved(
        amount: amount0,
        spender: zeniqSwapRouter.contractAddress,
        owner: address,
      ),
      token1.isApproved(
        amount: amount1,
        spender: zeniqSwapRouter.contractAddress,
        owner: address,
      ),
    ]);

    return (results[0], results[1]);
  }

  void calculateToken0() {
    if (lastTokenChanged == LastTokenChanged.token0) {
      return;
    }
    final amount1 = token1AmountNotifier.value;
    if (amount1 == null) {
      return;
    }

    final amount0 = pairInfo.calculateAmount0FromAmount1(amount1);

    recalculateInputs = false;

    token0AmountNotifier.value = amount0;
    token0InputNotifier.value = amount0.displayDouble.toString();

    recalculateInputs = true;
  }

  void calculateToken1() {
    if (lastTokenChanged == LastTokenChanged.token1) {
      return;
    }
    final amount0 = token0AmountNotifier.value;
    if (amount0 == null) {
      return;
    }

    final amount1 = pairInfo.calculateAmount1FromAmount0(amount0);

    recalculateInputs = false;

    token1AmountNotifier.value = amount1;
    token1InputNotifier.value = amount1.displayDouble.toString();

    recalculateInputs = true;
  }

  void token0InputChanged() {
    final value = token0InputNotifier.value;
    final bi = parseFromString(value, token0.decimals);

    final amount =
        bi != null ? Amount(value: bi, decimals: token0.decimals) : null;

    if (recalculateInputs) lastTokenChanged = LastTokenChanged.token0;
    token0AmountNotifier.value = amount;
  }

  void token1InputChanged() {
    final value = token1InputNotifier.value;
    final bi = parseFromString(value, token1.decimals);

    final amount =
        bi != null ? Amount(value: bi, decimals: token1.decimals) : null;

    if (recalculateInputs) lastTokenChanged = LastTokenChanged.token1;
    token1AmountNotifier.value = amount;
  }

  void dispose() {
    token0BalanceNotifier.removeListener(checkToken0Balance);
    token1BalanceNotifier.removeListener(checkToken1Balance);

    token0InputNotifier
      ..removeListener(token0InputChanged)
      ..dispose();
    token1InputNotifier
      ..removeListener(token1InputChanged)
      ..dispose();
    token0AmountNotifier
      ..removeListener(calculateToken1)
      ..removeListener(checkDepositInfo)
      ..dispose();
    token1AmountNotifier
      ..removeListener(calculateToken0)
      ..removeListener(checkDepositInfo)
      ..dispose();
    depositState.dispose();
  }
}

extension on ERC20Entity {
  Future<bool> isApproved({
    required Amount amount,
    required String spender,
    required String owner,
  }) async {
    final contract = ERC20Contract(contractAddress: contractAddress, rpc: rpc);

    final allowance = await contract.allowance(
      owner: owner,
      spender: spender,
    );

    return allowance >= amount.value;
  }
}
