import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:nomo_router/router/nomo_navigator.dart';
import 'package:nomo_ui_kit/components/buttons/primary/nomo_primary_button.dart';
import 'package:nomo_ui_kit/components/buttons/secondary/nomo_secondary_button.dart';
import 'package:nomo_ui_kit/components/text/nomo_text.dart';
import 'package:nomo_ui_kit/theme/nomo_theme.dart';
import 'package:nomo_ui_kit/utils/layout_extensions.dart';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/routes.dart';
import 'package:zeniq_swap_frontend/widgets/asset_picture.dart';

class SwapInputTrailling extends StatelessWidget {
  final ERC20Entity? token;

  final void Function(ERC20Entity token) onTokenSelected;

  const SwapInputTrailling({
    super.key,
    required this.token,
    required this.onTokenSelected,
  });

  void onPressed(BuildContext context) async {
    final result = await NomoNavigator.fromKey.push(SelectAssetDialogRoute());

    if (result is ERC20Entity) {
      onTokenSelected(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(
        milliseconds: 1200,
      ),
      child: token == null
          ? PrimaryNomoButton(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              borderRadius: BorderRadius.circular(12),
              onPressed: () => onPressed(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  4.hSpacing,
                  NomoText(
                    'Select Token',
                    style: context.typography.b1,
                    color: context.colors.onPrimary,
                  ),
                  4.hSpacing,
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            )
          : SecondaryNomoButton(
              backgroundColor: context.colors.background2,
              height: 42,
              onPressed: () => onPressed(context),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              border: const Border.fromBorderSide(BorderSide.none),
              borderRadius: BorderRadius.circular(12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AssetPicture(token: token!),
                  8.hSpacing,
                  NomoText(
                    token!.name.length > 12
                        ? "${token!.name.substring(0, 12)}..."
                        : token!.name,
                    style: context.typography.b2,
                    useInheritedTheme: true,
                  ),
                  8.hSpacing,
                  const Icon(
                    Icons.arrow_downward,
                    size: 18,
                  ),
                ],
              ),
            ),
    );
  }
}
