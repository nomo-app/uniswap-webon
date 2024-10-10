import 'package:flutter/widgets.dart';
import 'package:nomo_ui_kit/components/loading/shimmer/loading_shimmer.dart';
import 'package:nomo_ui_kit/components/text/nomo_text.dart';
import 'package:nomo_ui_kit/theme/nomo_theme.dart';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/providers/asset_notifier.dart';

class TokenPriceDisplay extends StatelessWidget {
  final ERC20Entity token;
  const TokenPriceDisplay({
    super.key,
    required this.token,
  });

  @override
  Widget build(BuildContext context) {
    final priceNotifier =
        InheritedAssetProvider.of(context).priceNotifierForToken(token);

    return ValueListenableBuilder(
      valueListenable: priceNotifier,
      builder: (context, priceAsync, child) {
        return priceAsync.when(
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
          data: (pricestate) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NomoText(
                    "Price: ",
                    style: context.typography.b1,
                    color: context.colors.foreground1,
                    opacity: 0.6,
                  ),
                  NomoText(
                    "${pricestate.currency.symbol}${pricestate.price.toStringAsFixed(5)}",
                    style: context.typography.b1,
                    color: context.colors.foreground1,
                    opacity: 0.8,
                  ),
                ],
              ),
            );
          },
          error: (error) => SizedBox.shrink(),
        );
      },
    );
  }
}
