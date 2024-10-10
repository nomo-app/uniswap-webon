import 'package:flutter/material.dart';
import 'package:nomo_ui_kit/components/buttons/primary/nomo_primary_button.dart';
import 'package:nomo_ui_kit/components/text/nomo_text.dart';
import 'package:nomo_ui_kit/theme/nomo_theme.dart';
import 'package:nomo_ui_kit/utils/layout_extensions.dart';
import 'package:zeniq_swap_frontend/providers/pool_provider.dart';
import 'package:zeniq_swap_frontend/widgets/asset_picture.dart';

class PairRatioDisplay extends StatefulWidget {
  final PairInfo pairInfo;

  const PairRatioDisplay({super.key, required this.pairInfo});

  @override
  State<PairRatioDisplay> createState() => _PairRatioDisplayState();
}

class _PairRatioDisplayState extends State<PairRatioDisplay> {
  late final ValueNotifier<bool> invertRatioNotifier = ValueNotifier(true);

  @override
  void dispose() {
    invertRatioNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: invertRatioNotifier,
      builder: (context, invert, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (invert) ...[
              AssetPicture(token: widget.pairInfo.token1),
              8.hSpacing,
              NomoText(
                "1 ${widget.pairInfo.token1.symbol}",
                style: context.typography.b2,
              )
            ] else ...[
              AssetPicture(token: widget.pairInfo.token0),
              8.hSpacing,
              NomoText(
                "1 ${widget.pairInfo.token0.symbol}",
                style: context.typography.b2,
              )
            ],
            8.hSpacing,
            PrimaryNomoButton(
              onPressed: () {
                invertRatioNotifier.value = !invertRatioNotifier.value;
              },
              icon: Icons.swap_horiz,
              height: 32,
              width: 32,
              shape: BoxShape.circle,
              padding: EdgeInsets.zero,
              elevation: 0,
              backgroundColor: Colors.transparent,
            ),
            8.hSpacing,
            if (invert) ...[
              AssetPicture(token: widget.pairInfo.token0),
              8.hSpacing,
              NomoText(
                "${widget.pairInfo.ratio0.toStringAsFixed(3)} ${widget.pairInfo.token0.symbol}",
                style: context.typography.b2,
              )
            ] else ...[
              AssetPicture(token: widget.pairInfo.token1),
              8.hSpacing,
              NomoText(
                "${widget.pairInfo.ratio1.toStringAsFixed(3)} ${widget.pairInfo.token1.symbol}",
                style: context.typography.b2,
              )
            ],
          ],
        );
      },
    );
  }
}
