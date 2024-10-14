import 'package:flutter/material.dart';
import 'package:nomo_ui_kit/components/buttons/link/nomo_link_button.dart';
import 'package:nomo_ui_kit/components/loading/shimmer/loading_shimmer.dart';
import 'package:nomo_ui_kit/components/text/nomo_text.dart';
import 'package:nomo_ui_kit/theme/nomo_theme.dart';
import 'package:nomo_ui_kit/utils/layout_extensions.dart';
import 'package:provider/provider.dart';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/common/async_value.dart';
import 'package:zeniq_swap_frontend/common/extensions.dart';
import 'package:zeniq_swap_frontend/main.dart';
import 'package:zeniq_swap_frontend/providers/balance_provider.dart';
import 'package:zeniq_swap_frontend/providers/models/price_state.dart';
import 'package:zeniq_swap_frontend/providers/price_provider.dart';
import 'package:zeniq_swap_frontend/providers/swap_provider.dart';

class SwapInputBottom extends StatelessWidget {
  final ERC20Entity? token;
  final ERC20Entity? otherToken;
  final bool showMax;
  final bool isFrom;

  const SwapInputBottom({
    super.key,
    required this.token,
    required this.isFrom,
    this.otherToken,
    this.showMax = true,
  });

  @override
  Widget build(BuildContext context) {
    final balanceNotifier = context.watch<BalanceProvider>();
    final swapProvider = context.watch<SwapProvider>();
    final priceNotifier = context.watch<PriceProvider>();

    final balanceListenable =
        token != null ? balanceNotifier.balanceNotifierForToken(token!) : null;
    final priceListenable =
        token != null ? priceNotifier.priceNotifierForToken(token!) : null;

    final otherPriceListenable = otherToken != null
        ? priceNotifier.priceNotifierForToken(otherToken!)
        : null;

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: switch ((balanceListenable, priceListenable)) {
        (
          ValueNotifier<AsyncValue<Amount>> balanceListenable,
          ValueNotifier<AsyncValue<PriceState>> priceListenable
        ) =>
          ListenableBuilder(
            listenable: Listenable.merge(
              [
                $addressNotifier,
                balanceListenable,
                priceListenable,
                swapProvider.swapInfo,
                if (isFrom) swapProvider.fromAmount else swapProvider.toAmount,
              ],
            ),
            builder: (context, child) {
              final hasAddress = $addressNotifier.value != null;
              final balanceAsync = balanceListenable.value;
              final priceAsync = priceListenable.value;
              final otherPriceAsync = otherPriceListenable?.value;
              final amount = isFrom
                  ? swapProvider.swapInfo.value?.fromAmount ??
                      swapProvider.fromAmount.value
                  : swapProvider.swapInfo.value?.toAmount ??
                      swapProvider.toAmount.value;

              final otherAmount = isFrom
                  ? swapProvider.swapInfo.value?.toAmount ??
                      swapProvider.toAmount.value
                  : swapProvider.swapInfo.value?.fromAmount ??
                      swapProvider.fromAmount.value;

              return Container(
                margin: EdgeInsets.only(top: 20),
                alignment: Alignment.center,
                child: Row(
                  children: [
                    priceAsync.when(
                      data: (price) {
                        final priceAmount = switch (amount) {
                          Amount amount when amount.value > BigInt.zero =>
                            price.price! * amount.displayDouble,
                          _ => null,
                        };
                        final priceAmountString = switch (amount) {
                          Amount amount when amount.value > BigInt.zero =>
                            "${price.currency.symbol}${(price.price! * amount.displayDouble).toStringAsFixed(5)}",
                          _ => "${price.currency.symbol}0.00",
                        };
                        return Row(
                          children: [
                            NomoText(
                              priceAmountString,
                              style: context.typography.b1,
                              fontWeight: FontWeight.bold,
                              opacity: 0.8,
                            ),
                            if (otherPriceAsync != null)
                              otherPriceAsync.when(
                                data: (otherPrice) {
                                  if (swapProvider.swapInfo.value == null) {
                                    return SizedBox.shrink();
                                  }

                                  final otherPriceAmount =
                                      switch (otherAmount) {
                                    Amount amount
                                        when amount.value > BigInt.zero =>
                                      (otherPrice.price! *
                                          amount.displayDouble),
                                    _ => null,
                                  };

                                  if (otherPriceAmount == null ||
                                      priceAmount == null ||
                                      otherAmount == null) {
                                    return SizedBox.shrink();
                                  }

                                  final priceDiff =
                                      (priceAmount - otherPriceAmount) /
                                          otherPriceAmount *
                                          100;

                                  if (priceDiff.abs() < 1) {
                                    return SizedBox.shrink();
                                  }

                                  final info =
                                      priceDiff.abs().formatPriceImpact();

                                  return NomoText(
                                    "  (${priceDiff > 0 ? '+' : '-'}${info.$1}%)",
                                    style: context.typography.b1,
                                    fontWeight: FontWeight.bold,
                                    color: priceDiff > 0
                                        ? Colors.greenAccent
                                        : context.colors.error,
                                  );
                                },
                                loading: () => ShimmerLoading(
                                  isLoading: true,
                                  child: Container(
                                    width: 64,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      color: context.colors.background2,
                                    ),
                                  ),
                                ),
                                error: (error) => SizedBox.shrink(),
                              ),
                          ],
                        );
                      },
                      loading: () => ShimmerLoading(
                        isLoading: true,
                        child: Container(
                          width: 64,
                          height: 24,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: context.colors.background2,
                          ),
                        ),
                      ),
                      error: (error) {
                        return NomoText(
                          "No price available",
                          style: context.typography.b1,
                          color: context.colors.error,
                        );
                      },
                    ),
                    const Spacer(),
                    if (hasAddress)
                      balanceAsync.when(
                        data: (balance) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              NomoText(
                                "Balance: ",
                                style: context.typography.b1,
                                opacity: 0.6,
                              ),
                              NomoText(
                                balance.displayDouble.toStringAsFixed(2),
                                style: context.typography.b1,
                                opacity: 0.8,
                              ),
                              if (showMax && balance.displayDouble > 0) ...[
                                8.hSpacing,
                                NomoLinkButton(
                                  text: "Max",
                                  width: 48,
                                  height: 32,
                                  foregroundColor: context.colors.primary,
                                  selectionColor:
                                      context.colors.primary.lighten(),
                                  tapDownColor: context.colors.primary.darken(),
                                  padding: EdgeInsets.zero,
                                  textStyle: context.typography.b1,
                                  onPressed: () {
                                    swapProvider.fromAmountString.value =
                                        balance.displayValue;
                                  },
                                ),
                              ],
                              4.hSpacing,
                            ],
                          );
                        },
                        loading: () => ShimmerLoading(
                          isLoading: true,
                          child: Container(
                            width: 64,
                            height: 24,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: context.colors.background2,
                            ),
                          ),
                        ),
                        error: (error) => const Icon(Icons.error),
                      ),
                  ],
                ),
              );
            },
          ),
        _ => const SizedBox(
            height: 12,
          ),
      },
    );
  }
}
