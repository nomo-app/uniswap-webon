import 'package:flutter/widgets.dart';
import 'package:nomo_ui_kit/components/loading/loading.dart';
import 'package:nomo_ui_kit/components/text/nomo_text.dart';
import 'package:nomo_ui_kit/theme/nomo_theme.dart';
import 'package:nomo_ui_kit/utils/layout_extensions.dart';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/providers/asset_notifier.dart';

class AddLiqudityInputBottom extends StatelessWidget {
  final ERC20Entity token;
  final ValueNotifier<Amount?> amountNotifier;

  const AddLiqudityInputBottom({
    super.key,
    required this.token,
    required this.amountNotifier,
  });

  @override
  Widget build(BuildContext context) {
    final balanceNotifier =
        InheritedAssetProvider.of(context).balanceNotifierForToken(token);
    final priceNotifier =
        InheritedAssetProvider.of(context).priceNotifierForToken(token);
    return ListenableBuilder(
      listenable: Listenable.merge([
        balanceNotifier,
        priceNotifier,
        amountNotifier,
      ]),
      builder: (context, child) {
        final balanceAsync = balanceNotifier.value;
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
                      final value =
                          (amount?.displayDouble ?? 0) * priceState.price!;

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
                            "Balance: ${balanceState.displayDouble.toStringAsFixed(2)}",
                            style: context.typography.b2,
                          ),
                          8.hSpacing,
                          priceAsync.when(
                            loading: () => const SizedBox.shrink(),
                            error: (error) => NomoText(error.toString()),
                            data: (priceState) {
                              final value = balanceState.displayDouble *
                                  priceState.price!;

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
