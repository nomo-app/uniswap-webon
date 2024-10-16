import 'package:flutter/widgets.dart';
import 'package:nomo_ui_kit/components/loading/loading.dart';
import 'package:nomo_ui_kit/components/text/nomo_text.dart';
import 'package:nomo_ui_kit/theme/nomo_theme.dart';
import 'package:nomo_ui_kit/utils/layout_extensions.dart';
import 'package:provider/provider.dart';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/common/async_value.dart';
import 'package:zeniq_swap_frontend/main.dart';
import 'package:zeniq_swap_frontend/providers/balance_provider.dart';
import 'package:zeniq_swap_frontend/providers/models/pair_info.dart';
import 'package:zeniq_swap_frontend/providers/price_provider.dart';

class AddLiqudityInputBottom extends StatelessWidget {
  final ERC20Entity token;
  final ValueNotifier<Amount?> amountNotifier;

  final Amount? balance;
  final String? balanceString;

  const AddLiqudityInputBottom({
    super.key,
    required this.token,
    required this.amountNotifier,
    this.balance,
    this.balanceString,
  });

  @override
  Widget build(BuildContext context) {
    final balanceNotifier =
        context.watch<BalanceProvider>().balanceNotifierForToken(token);
    final priceNotifier =
        context.watch<PriceProvider>().priceNotifierForToken(token);
    return ListenableBuilder(
      listenable: Listenable.merge([
        if (balance == null) balanceNotifier,
        priceNotifier,
        amountNotifier,
      ]),
      builder: (context, child) {
        final balanceAsync = balance != null
            ? AsyncValue.value(balance!)
            : balanceNotifier.value;
        final priceAsync = priceNotifier.value;
        final amount = amountNotifier.value;

        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              Builder(
                builder: (context) {
                  return priceAsync.when(
                    loading: () => const Loading(),
                    error: (error) => NomoText(error.toString()),
                    data: (priceState) {
                      final value = (amount?.displayDouble ?? 0) *
                          (priceState.price ?? 0);

                      return NomoText(
                        "${priceState.currency.symbol}${value.toStringAsFixed(2)}",
                        style: context.typography.b2,
                      );
                    },
                  );
                },
              ),
              Spacer(),
              Builder(
                builder: (context) {
                  return balanceAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (error) => NomoText(error.toString()),
                    data: (balanceState) {
                      return Row(
                        children: [
                          NomoText(
                            "${balanceString ?? "Balance:"} ${balanceState.displayDouble.toStringAsFixed(2)}",
                            style: context.typography.b2,
                          ),
                          8.hSpacing,
                          priceAsync.when(
                            loading: () => const SizedBox.shrink(),
                            error: (error) => NomoText(error.toString()),
                            data: (priceState) {
                              final value = balanceState.displayDouble *
                                  (priceState.price ?? 0);

                              return NomoText(
                                "${priceState.currency.symbol}${value.toStringAsFixed(2)}",
                                style: context.typography.b2,
                              );
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              )
            ],
          ),
        );
      },
    );
  }
}

class PoolTokenInputBottom extends StatelessWidget {
  final OwnedPairInfo pair;
  final ValueNotifier<Amount?> amountNotifier;

  const PoolTokenInputBottom({
    super.key,
    required this.pair,
    required this.amountNotifier,
  });

  @override
  Widget build(BuildContext context) {
    final price0Notifier =
        context.watch<PriceProvider>().priceNotifierForToken(pair.token0);

    final price1Notifier =
        context.watch<PriceProvider>().priceNotifierForToken(pair.token1);

    return ListenableBuilder(
      listenable: Listenable.merge([
        price0Notifier,
        price1Notifier,
        amountNotifier,
      ]),
      builder: (context, child) {
        final poolAmount = amountNotifier.value;
        final currency = $currencyNotifier.value.symbol;
        if (poolAmount == null) {
          return NomoText("${currency}0.00");
        }

        final price0Async = price0Notifier.value;
        final price1Async = price1Notifier.value;

        if (price0Async is! Value || price1Async is! Value) {
          return NomoText("${currency}0.00");
        }

        final (amount0, amount1) =
            pair.calculateTokeAmountsFromPoolAmount(poolAmount);

        final value0 = amount0.displayDouble *
            (price0Notifier.value.valueOrNull?.price ?? 0);
        final value1 = amount1.displayDouble *
            (price1Notifier.value.valueOrNull?.price ?? 0);

        final totalValue = value0 + value1;

        return NomoText("${currency}${totalValue.toStringAsFixed(2)}");
      },
    );
  }
}
