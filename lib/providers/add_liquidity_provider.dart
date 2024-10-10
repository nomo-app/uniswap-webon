import 'package:flutter/foundation.dart';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/providers/pool_provider.dart';
import 'package:zeniq_swap_frontend/providers/swap_provider.dart';

enum LastTokenChanged {
  token0,
  token1,
}

enum AddLiquidityState {
  none,
  error,
  needTokenApproval,
  depositing,
  deposited,
}

class AddLiquidityProvider {
  final PairInfo pairInfo;

  ERC20Entity get token0 => pairInfo.token0;
  ERC20Entity get token1 => pairInfo.token1;

  final ValueNotifier<String> token0InputNotifier = ValueNotifier("");
  final ValueNotifier<String> token1InputNotifier = ValueNotifier("");

  final ValueNotifier<Amount?> token0AmountNotifier = ValueNotifier(null);
  final ValueNotifier<Amount?> token1AmountNotifier = ValueNotifier(null);

  final ValueNotifier<double?> poolShareNotifier = ValueNotifier(null);

  final ValueNotifier<AddLiquidityState> stateNotifier =
      ValueNotifier(AddLiquidityState.none);

  LastTokenChanged? lastTokenChanged;

  bool recalculateInputs = true;

  AddLiquidityProvider({required this.pairInfo}) {
    token0InputNotifier
      ..addListener(token0InputChanged)
      ..addListener(checkDepositInfo);
    token1InputNotifier
      ..addListener(token1InputChanged)
      ..addListener(checkDepositInfo);

    token0AmountNotifier.addListener(calculateToken1);
    token1AmountNotifier.addListener(calculateToken0);
  }

  void checkDepositInfo() {
    final amount0 = token0AmountNotifier.value;
    final amount1 = token1AmountNotifier.value;

    if (amount0 == null || amount1 == null) {
      return;
    }

    final poolShare = pairInfo.calculatePoolShare(amount0, amount1);
    poolShareNotifier.value = poolShare;
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
    token0InputNotifier
      ..removeListener(token0InputChanged)
      ..removeListener(checkDepositInfo)
      ..dispose();
    token1InputNotifier
      ..removeListener(token1InputChanged)
      ..removeListener(checkDepositInfo)
      ..dispose();
    token0AmountNotifier
      ..removeListener(calculateToken1)
      ..dispose();
    token1AmountNotifier
      ..removeListener(calculateToken0)
      ..dispose();
    stateNotifier.dispose();
  }
}
