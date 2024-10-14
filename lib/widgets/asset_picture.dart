import 'package:flutter/widgets.dart';
import 'package:nomo_ui_kit/components/loading/shimmer/loading_shimmer.dart';
import 'package:nomo_ui_kit/theme/nomo_theme.dart';
import 'package:provider/provider.dart';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/providers/token_provider.dart';

class AssetPicture extends StatelessWidget {
  final ERC20Entity token;
  final double size;

  const AssetPicture({
    super.key,
    required this.token,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    final imageProvider = context.watch<TokenProvider>();
    final image = imageProvider.imageNotifierForToken(token);

    return ValueListenableBuilder(
      valueListenable: image,
      builder: (context, image, child) {
        return image.when(
          data: (value) {
            return ClipOval(
              child: Image.network(
                value,
                width: size,
                height: size,
              ),
            );
          },
          loading: () => ShimmerLoading(
            isLoading: true,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.background2,
              ),
            ),
          ),
          error: (error) => ClipOval(
            child: Image.asset(
              "assets/blank-token.png",
              width: size,
              height: size,
            ),
          ),
        );
      },
    );
  }
}
