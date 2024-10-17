import 'package:flutter/foundation.dart';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/common/async_value.dart';
import 'package:zeniq_swap_frontend/common/logger.dart';
import 'package:zeniq_swap_frontend/providers/add_liquidity_provider.dart';
import 'package:zeniq_swap_frontend/providers/balance_provider.dart';
import 'package:zeniq_swap_frontend/providers/models/pair_info.dart';
import 'package:zeniq_swap_frontend/providers/pool_provider.dart';
import 'package:zeniq_swap_frontend/providers/price_provider.dart';
import 'package:zeniq_swap_frontend/providers/swap_provider.dart';

class CreateInfo {
  final ERC20Entity token0;
  final ERC20Entity token1;

  final Amount amount0;
  final Amount amount1;
  final Amount amount0Min;
  final Amount amount1Min;
  final BigInt deadline;
  final String address;
  final double poolShare;
  final bool token0NeedsApproval;
  final bool token1NeedsApproval;

  double get ratio0 => amount0.value / amount1.value;
  double get ratio1 => amount1.value / amount0.value;

  CreateInfo._({
    required this.token0,
    required this.token1,
    required this.amount0,
    required this.amount1,
    required this.amount0Min,
    required this.amount1Min,
    required this.deadline,
    required this.poolShare,
    required this.address,
    required this.token0NeedsApproval,
    required this.token1NeedsApproval,
  });

  factory CreateInfo.create({
    required ERC20Entity token0,
    required ERC20Entity token1,
    required Amount amount0,
    required Amount amount1,
    required double slippage,
    required String address,
    required bool token0NeedsApproval,
    required bool token1NeedsApproval,
  }) {
    final deadline = BigInt.from(
      DateTime.now().add(Duration(minutes: 1)).millisecondsSinceEpoch ~/ 1000,
    );

    const poolShare = 100.0;

    final slippageMultiplier = 1 - slippage;

    final amount0Min = Amount(
      value: amount0.value.multiply(slippageMultiplier),
      decimals: amount0.decimals,
    );

    final amount1Min = Amount(
      value: amount1.value.multiply(slippageMultiplier),
      decimals: amount1.decimals,
    );

    return CreateInfo._(
      token0: token0,
      token1: token1,
      amount0: amount0,
      amount1: amount1,
      amount0Min: amount0Min,
      amount1Min: amount1Min,
      deadline: deadline,
      poolShare: poolShare,
      address: address,
      token0NeedsApproval: token0NeedsApproval,
      token1NeedsApproval: token1NeedsApproval,
    );
  }

  Future<RawEVMTransactionType0> createAddLiquidityTransaction() {
    return zeniqSwapRouter
        .addLiquidityTx(
          tokenA: token0.contractAddress,
          tokenB: token1.contractAddress,
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

  Future<PairInfoEntity?> findPairInfo() {
    return zfactory
        .getPair(tokenA: token0.contractAddress, tokenB: token1.contractAddress)
        .then((address) => UniswapV2Pair(contractAddress: address, rpc: rpc))
        .then(
          (pair) => PairInfoEntity.fromPair(
            pair,
            type: PairType.v2,
            address: address,
          ),
        );
  }

  @override
  String toString() {
    return "Provided ${amount0.displayDouble.toStringAsFixed(2)} ${token0.symbol} and ${amount1.displayDouble.toStringAsFixed(2)} ${token1.symbol}";
  }
}

final minZeniqForPoolCreation = Amount.convert(
  value: kDebugMode ? 1 : 5000,
  decimals: 18,
);

class CreatePairProvider {
  final PoolProvider poolProvider;
  final PriceProvider priceProvider;

  final ERC20Entity token0;
  final ERC20Entity token1;

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

  final ValueNotifier<CreateInfo?> createInfoNotifier = ValueNotifier(null);

  final ValueNotifier<AddLiquidityState> createState =
      ValueNotifier(AddLiquidityState.none);

  LastTokenChanged? lastTokenChanged;

  bool recalculateInputs = true;

  double get slippage => slippageNotifier.value;

  final bool needToBroadcast;

  final Future<String> Function(String tx) signer;

  CreatePairProvider({
    required this.priceProvider,
    required this.poolProvider,
    required this.token0,
    required this.token1,
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

    token0AmountNotifier..addListener(checkDepositInfo);
    token1AmountNotifier..addListener(checkDepositInfo);
  }

  bool checkToken0Balance() {
    final balance = token0BalanceNotifier.value.valueOrNull;
    if (balance == null) return false;
    final amount = token0AmountNotifier.value;
    if (amount == null) return false;

    if (amount < minZeniqForPoolCreation) {
      token0ErrorNotifier.value =
          "Minimum 5000 ZENIQ required to create a pool";
      return false;
    } else if (balance < amount) {
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

    createState.value = switch ((this.address, createState.value)) {
      (null, _) => AddLiquidityState.preview,
      (_, AddLiquidityState.preview) => AddLiquidityState.none,
      _ => createState.value,
    };

    final address = this.address ?? arbitrumTestWallet;

    final token0BalanceValid = checkToken0Balance();
    final token1BalanceValid = checkToken1Balance();

    if (token0BalanceValid == false || token1BalanceValid == false) {
      createState.value = AddLiquidityState.none;
      return;
    }

    final amount0 = token0AmountNotifier.value;
    final amount1 = token1AmountNotifier.value;

    if (amount0 == null ||
        amount0.value == BigInt.zero ||
        amount1 == null ||
        amount1.value == BigInt.zero) {
      createState.value = AddLiquidityState.none;
      return;
    }

    final (token0HasApproval, token1HasApproval) = await checkTokenApprovals(
      amount0,
      amount1,
      address,
    );

    createInfoNotifier.value = CreateInfo.create(
      token0: token0,
      token1: token1,
      amount0: amount0,
      amount1: amount1,
      slippage: slippage,
      address: address,
      token0NeedsApproval: !token0HasApproval,
      token1NeedsApproval: !token1HasApproval,
    );

    Logger.log("token0HasApproval: $token0HasApproval");
    Logger.log("token1HasApproval: $token1HasApproval");

    if (token0HasApproval == false || token1HasApproval == false) {
      createState.value = AddLiquidityState.needTokenApproval;
      return;
    }

    createState.value = AddLiquidityState.ready;
  }

  Future<bool> approveToken(CreateInfo info, ERC20Entity token) async {
    try {
      final unsignedTX = await token.erc20Contract.approveTx(
        sender: info.address,
        spender: zeniqSwapRouter.contractAddress,
        value: BigInt.tryParse(
          "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
        )!,
      ) as RawEVMTransactionType0;

      createState.value = AddLiquidityState.waitingForUserApproval;

      final String hash;
      if (needToBroadcast) {
        final signedTX = await signer(
          unsignedTX.serializedUnsigned(rpc.type.chainId).toHex,
        );

        createState.value = AddLiquidityState.approvingToken;

        hash = await rpc.sendRawTransaction(
          signedTX.startsWith("0x") ? signedTX : "0x$signedTX",
        );
      } else {
        createState.value = AddLiquidityState.approvingToken;
        hash = await signer(
          unsignedTX.serializedUnsigned(rpc.type.chainId).toHex,
        );
      }

      final successfull = await rpc.waitForTxConfirmation(hash);

      return successfull;
    } catch (e) {
      createState.value = AddLiquidityState.tokenApprovalError;
      recalculateInputs = true;
      checkDepositInfo();
      rethrow;
    }
  }

  Future<String> deposit() async {
    assert(
      createState.value == AddLiquidityState.ready ||
          createState.value == AddLiquidityState.needTokenApproval,
    );

    final depositInfo = createInfoNotifier.value;

    assert(depositInfo != null);

    if (createState.value == AddLiquidityState.needTokenApproval) {
      try {
        final token0NeedsApproval = depositInfo!.token0NeedsApproval;
        final token1NeedsApproval = depositInfo.token1NeedsApproval;

        if (token0NeedsApproval) {
          await approveToken(depositInfo, token0);
        }

        if (token1NeedsApproval) {
          await approveToken(depositInfo, token1);
        }

        createState.value = AddLiquidityState.ready;
      } catch (e) {
        createState.value = AddLiquidityState.tokenApprovalError;
        recalculateInputs = true;
        checkDepositInfo();
        rethrow;
      }
    }

    try {
      final unsignedRawTx = await depositInfo!.createAddLiquidityTransaction();
      createState.value = AddLiquidityState.waitingForUserApproval;
      final String hash;
      if (needToBroadcast) {
        final signedTX = await signer(
          unsignedRawTx.serializedUnsigned(rpc.type.chainId).toHex,
        );

        createState.value = AddLiquidityState.broadcasting;

        hash = await rpc.sendRawTransaction(
          signedTX.startsWith("0x") ? signedTX : "0x$signedTX",
        );
      } else {
        hash = await signer(
          unsignedRawTx.serializedUnsigned(rpc.type.chainId).toHex,
        );
      }

      createState.value = AddLiquidityState.confirming;

      final successfull = await rpc.waitForTxConfirmation(hash);

      final pair = await depositInfo.findPairInfo();
      if (pair != null) {
        poolProvider.addPair(pair);
        priceProvider.addToken(pair);
      }

      createState.value =
          successfull ? AddLiquidityState.deposited : AddLiquidityState.error;

      // Cleanup
      token0InputNotifier.value = '';
      token1InputNotifier.value = '';
      recalculateInputs = true;
      return hash;
    } catch (e) {
      createState.value = AddLiquidityState.error;
      recalculateInputs = true;
      checkDepositInfo();
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
      ..removeListener(checkDepositInfo)
      ..dispose();
    token1AmountNotifier
      ..removeListener(checkDepositInfo)
      ..dispose();
    createState.dispose();
  }
}

extension on ERC20Entity {
  ERC20Contract get erc20Contract => ERC20Contract(
        contractAddress: contractAddress,
        rpc: rpc,
      );

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
