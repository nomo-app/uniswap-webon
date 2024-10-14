import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/providers/swap_provider.dart';

enum PairType {
  legacy,
  v2;

  static PairType fromIndex(int index) {
    switch (index) {
      case 0:
        return legacy;
      case 1:
        return v2;
      default:
        throw UnimplementedError();
    }
  }

  @override
  String toString() {
    return name;
  }

  static PairType fromString(String name) => PairType.values.singleWhere(
        (element) => element.name == name,
      );
}

sealed class PairInfoEntity {
  final UniswapV2Pair pair;

  ERC20Contract get erc20Contract {
    return ERC20Contract(contractAddress: pair.contractAddress, rpc: pair.rpc);
  }

  final ERC20Entity token0;
  final ERC20Entity token1;

  final BigInt poolSupply;

  final BigInt reserve0;
  final BigInt reserve1;

  final PairType type;

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

  PairInfoEntity._({
    required this.pair,
    required this.token0,
    required this.token1,
    required this.reserve0,
    required this.reserve1,
    required this.type,
    required this.poolSupply,
  });

  // Future<PairInfo> update() async {
  //   final (reserve0, reserve1) = await pair.getReserves();

  //   return copyWith(
  //     reserve0: reserve0,
  //     reserve1: reserve1,
  //   );
  // }

  // PairInfo copyWith({
  //   BigInt? reserve0,
  //   BigInt? reserve1,
  // }) =>
  //     PairInfo(
  //       pair: pair,
  //       token0: token0,
  //       token1: token1,
  //       type: type,
  //       reserve0: reserve0 ?? this.reserve0,
  //       reserve1: reserve1 ?? this.reserve1,
  //     );

  @override
  String toString() {
    return "(token0: $token0, token1: $token1, reserve0: $reserve0, reserve1: $reserve1)";
  }

  static PairInfo fromJson(
    Map<String, dynamic> json,
  ) {
    if (json
        case {
          'token0': Map<String, dynamic> token0Json,
          'token1': Map<String, dynamic> token1Json,
          'pair': String pairAddress,
          'reserve0': String reserve0S,
          'reserve1': String reserve1S,
          'poolSupply': String poolSupplyS,
          'type': int type,
        }) {
      final token0 = ERC20Entity.fromJson(
        token0Json,
        allowDeletion: false,
        chainID: token0Json['chainID'],
      );
      final token1 = ERC20Entity.fromJson(
        token1Json,
        allowDeletion: false,
        chainID: token1Json['chainID'],
      );

      final reserve0 = BigInt.parse(reserve0S);
      final reserve1 = BigInt.parse(reserve1S);
      final poolSupply = BigInt.parse(poolSupplyS);

      return PairInfo(
        pair: UniswapV2Pair(contractAddress: pairAddress, rpc: rpc),
        token0: token0,
        token1: token1,
        reserve0: reserve0,
        reserve1: reserve1,
        poolSupply: poolSupply,
        type: PairType.fromIndex(type),
      );
    }

    throw UnimplementedError();
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

final class PairInfo extends PairInfoEntity {
  PairInfo({
    required UniswapV2Pair pair,
    required ERC20Entity token0,
    required ERC20Entity token1,
    required BigInt reserve0,
    required BigInt reserve1,
    required PairType type,
    required BigInt poolSupply,
  }) : super._(
          pair: pair,
          token0: token0,
          token1: token1,
          reserve0: reserve0,
          reserve1: reserve1,
          type: type,
          poolSupply: poolSupply,
        );

  PairInfo copyWith({
    BigInt? reserve0,
    BigInt? reserve1,
    BigInt? poolSupply,
  }) =>
      PairInfo(
        pair: pair,
        token0: token0,
        token1: token1,
        type: type,
        poolSupply: poolSupply ?? this.poolSupply,
        reserve0: reserve0 ?? this.reserve0,
        reserve1: reserve1 ?? this.reserve1,
      );
}

final class OwnedPairInfo extends PairInfoEntity {
  final BigInt pairTokenAmount;

  Amount get pairTokenAmountAmount {
    return Amount(
      value: pairTokenAmount,
      decimals: 18,
    );
  }

  double get myPoolShare => pairTokenAmount / poolSupply;

  double get myPoolSharePercentage => myPoolShare * 100;

  Amount get myAmount0 {
    final val = reserve0.multiply(myPoolShare);
    return Amount(value: val, decimals: token0.decimals);
  }

  Amount get myAmount1 {
    final val = reserve1.multiply(myPoolShare);
    return Amount(value: val, decimals: token1.decimals);
  }

  double myTotalValueLocked(double price0, double price1) {
    return myAmount0.displayDouble * price0 + myAmount1.displayDouble * price1;
  }

  OwnedPairInfo({
    required this.pairTokenAmount,
    required PairInfo pairInfo,
  }) : super._(
          pair: pairInfo.pair,
          token0: pairInfo.token0,
          token1: pairInfo.token1,
          reserve0: pairInfo.reserve0,
          reserve1: pairInfo.reserve1,
          type: pairInfo.type,
          poolSupply: pairInfo.poolSupply,
        );
}
