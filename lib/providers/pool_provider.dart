import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/common/async_value.dart';
import 'package:zeniq_swap_frontend/providers/swap_provider.dart';

final factoryNew = UniswapV2Factory(
  rpc: rpc,
  contractAddress: "0x40a4E23Cc9E57161699Fd37c0A4d8bca383325f3",
);

final factoryOld = UniswapV2Factory(
  rpc: rpc,
  contractAddress: "0x7D0cbcE25EaaB8D5434a53fB3B42077034a9bB99",
);

class PoolProvider {
  final ValueNotifier<AsyncValue<List<PairInfo>>> allPairsNotifier =
      ValueNotifier(AsyncValue.loading());

  final Map<String, ValueNotifier<AsyncValue<PairInfo>>> pairNotifiers = {};

  ValueNotifier<AsyncValue<PairInfo>> getPairNotifier(String address) {
    final notifier = pairNotifiers.putIfAbsent(
      address,
      () {
        return allPairsNotifier.value.when(
          loading: () => ValueNotifier(AsyncValue.loading()),
          error: (error) => ValueNotifier(AsyncValue.loading()),
          data: (allPairs) {
            final pair = allPairs.singleWhereOrNull(
              (pair) => pair.pair.contractAddress == address,
            );

            if (pair == null) {
              return ValueNotifier(AsyncValue.loading());
            }

            return ValueNotifier(AsyncValue.value(pair));
          },
        );
      },
    );

    return notifier;
  }

  PoolProvider() {
    fetchAll();
  }

  void fetchAll() async {
    try {
      final pairsNew = await fetchAllPairs(factoryNew, allowEntering: true);
      final pairsOld =
          <PairInfo>[]; //await fetchAllPairs(factoryOld, allowEntering: false);
      final pairs = [...pairsNew, ...pairsOld];
      pairs.sort((a, b) => a.zeniqAmount < b.zeniqAmount ? 1 : -1);
      allPairsNotifier.value = AsyncValue.value(pairs);
    } catch (e) {
      allPairsNotifier.value = AsyncValue.error(e);
    }
  }
}

Future<List<PairInfo>> fetchAllPairs(UniswapV2Factory factory,
    {required bool allowEntering}) async {
  final length = await factory.allPairsLength().then((value) => value.toInt());

  final pairs = await Future.wait([
    for (int i = 0; i < length; i++)
      factory
          .allPairs(i.toBigInt)
          .then(
            (contractAddress) => UniswapV2Pair(
              rpc: rpc,
              contractAddress: contractAddress,
            ),
          )
          .then(
            (pair) => PairInfo.fromPair(pair, allowEntering: allowEntering),
          )
  ]).then((pairsNullable) => pairsNullable.whereType<PairInfo>().toList());

  return pairs;
}

class PairInfo {
  final UniswapV2Pair pair;

  final ERC20Entity token0;
  final ERC20Entity token1;

  final BigInt reserve0;
  final BigInt reserve1;

  final bool allowEntering;

  int get decimalOffset0 => token1.decimals - token0.decimals;
  int get decimalOffset1 => token0.decimals - token1.decimals;

  BigInt get reserve0Adjusted => reserve0 * BigInt.from(10).pow(decimalOffset0);
  BigInt get reserve1Adjusted => reserve1 * BigInt.from(10).pow(decimalOffset1);

  double get ratio0 => reserve0Adjusted / reserve1Adjusted;
  double get ratio1 => reserve1Adjusted / reserve0Adjusted;

  double get zeniqRatio => switch (token0) {
        zeniqTokenWrapper => ratio0,
        _ => ratio1,
      };

  Amount get zeniqAmount => switch (token0) {
        zeniqTokenWrapper => amount0,
        _ => amount1,
      };

  Amount get tokenAmount => switch (token0) {
        zeniqTokenWrapper => amount1,
        _ => amount0,
      };

  Amount get amount0 => Amount(
        value: reserve0,
        decimals: token0.decimals,
      );

  Amount get amount1 => Amount(
        value: reserve1,
        decimals: token1.decimals,
      );

  Amount calculateAmount0FromAmount1(Amount amount1) {
    final amount1Adjusted = amount1.value * BigInt.from(10).pow(decimalOffset1);
    final amount0BI = amount1Adjusted.multiply(ratio0);
    return Amount(
      value: amount0BI,
      decimals: token0.decimals,
    );
  }

  Amount calculateAmount1FromAmount0(Amount amount0) {
    final amount0Adjusted = amount0.value * BigInt.from(10).pow(decimalOffset0);
    final amount1BI = amount0Adjusted.multiply(ratio1);
    return Amount(
      value: amount1BI,
      decimals: token1.decimals,
    );
  }

  double calculatePoolShare(Amount amount0, Amount amount1) {
    final amount0Adj = amount0.value * BigInt.from(10).pow(decimalOffset0);
    final amount1Adj = amount1.value * BigInt.from(10).pow(decimalOffset1);

    final totalValue = amount0Adj + amount1Adj;

    return (totalValue / (reserve0Adjusted + reserve1Adjusted + totalValue))
            .toDouble() *
        100;
  }

  double totalValueLocked(double price0, double price1) {
    return amount0.displayDouble * price0 + amount1.displayDouble * price1;
  }

  double percentageOfTvl0(double price0, double price1) {
    final tvl = totalValueLocked(price0, price1);
    return (amount0.displayDouble * price0 / tvl) * 100;
  }

  double percentageOfTvl1(double price0, double price1) {
    final tvl = totalValueLocked(price0, price1);
    return (amount1.displayDouble * price1 / tvl) * 100;
  }

  PairInfo._({
    required this.pair,
    required this.token0,
    required this.token1,
    required this.reserve0,
    required this.reserve1,
    required this.allowEntering,
  });

  static Future<PairInfo?> fromPair(UniswapV2Pair pair,
      {required bool allowEntering}) async {
    final results = await Future.wait([
      pair.token0().then(
            (contractAddress) => getTokenInfo(
              contractAddress: contractAddress,
              rpc: pair.rpc,
            ).then(
              (info) => info?.toEntity(
                pair.rpc.type.chainId,
              ),
            ),
          ),
      pair.token1().then(
            (contractAddress) => getTokenInfo(
              contractAddress: contractAddress,
              rpc: pair.rpc,
            ).then(
              (info) => info?.toEntity(
                pair.rpc.type.chainId,
              ),
            ),
          ),
      pair.getReserves(),
    ]);

    final token0 = results[0] as ERC20Entity?;
    final token1 = results[1] as ERC20Entity?;

    if (token1 == null || token0 == null) return null;

    final (reserves0, reserves1) = results[2] as (BigInt, BigInt);

    return PairInfo._(
        pair: pair,
        token0: token0,
        token1: token1,
        reserve0: reserves0,
        reserve1: reserves1,
        allowEntering: allowEntering);
  }

  Future<PairInfo> update() async {
    final (reserve0, reserve1) = await pair.getReserves();

    return copyWith(
      reserve0: reserve0,
      reserve1: reserve1,
    );
  }

  PairInfo copyWith({
    BigInt? reserve0,
    BigInt? reserve1,
  }) =>
      PairInfo._(
        pair: pair,
        token0: token0,
        token1: token1,
        allowEntering: allowEntering,
        reserve0: reserve0 ?? this.reserve0,
        reserve1: reserve1 ?? this.reserve1,
      );

  @override
  String toString() {
    return "(token0: $token0, token1: $token1, reserve0: $reserve0, reserve1: $reserve1)";
  }
}

extension on TokenInfo {
  ERC20Entity toEntity(int chainID) => ERC20Entity(
        name: name,
        symbol: symbol,
        decimals: decimals,
        chainID: chainID,
        contractAddress: contractAddress,
      );
}

class InheritedPoolProvider extends InheritedWidget {
  const InheritedPoolProvider({
    super.key,
    required this.poolProvider,
    required super.child,
  });

  final PoolProvider poolProvider;

  static PoolProvider of(BuildContext context) {
    final result =
        context.dependOnInheritedWidgetOfExactType<InheritedPoolProvider>();
    if (result == null) {
      throw Exception('InheritedSwapProvider not found in context');
    }
    return result.poolProvider;
  }

  @override
  bool updateShouldNotify(InheritedPoolProvider oldWidget) {
    return false;
  }
}
