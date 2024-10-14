import 'package:flutter/material.dart';
import 'package:nomo_ui_kit/components/buttons/primary/nomo_primary_button.dart';
import 'package:nomo_ui_kit/components/buttons/secondary/nomo_secondary_button.dart';
import 'package:nomo_ui_kit/components/card/nomo_card.dart';
import 'package:nomo_ui_kit/components/input/textInput/nomo_input.dart';
import 'package:nomo_ui_kit/components/text/nomo_text.dart';
import 'package:nomo_ui_kit/theme/nomo_theme.dart';
import 'package:nomo_ui_kit/utils/layout_extensions.dart';
import 'package:zeniq_swap_frontend/providers/models/pair_info.dart';
import 'package:zeniq_swap_frontend/widgets/asset_picture.dart';

final percentages = [0.25, 0.5, 0.75, 1];

class PoolRemoveLiquidity extends StatelessWidget {
  final OwnedPairInfo pairInfo;

  const PoolRemoveLiquidity({
    super.key,
    required this.pairInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NomoText(
          "Withdraw",
          style: context.typography.b3,
        ),
        12.vSpacing,
        NomoText(
          "Withdraw to receive pool tokens and earned trading fees",
          style: context.typography.b2,
        ),
        24.vSpacing,
        NomoCard(
          backgroundColor: context.colors.background2.withOpacity(0.5),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                child: Slider(
                  value: 1,
                  onChanged: (value) {},
                ),
              ),
              Row(
                children: [
                  for (final percentage in percentages)
                    Expanded(
                      child: SecondaryNomoButton(
                        backgroundColor: Colors.transparent,
                        height: 36,
                        text: "${(percentage * 100).toInt()}%",
                        onPressed: () {},
                      ),
                    )
                ].spacingH(12),
              )
            ],
          ),
        ),
        48.vSpacing,
        NomoInput(
          background: context.colors.background2.withOpacity(0.5),
          trailling: AssetPicture(
            token: pairInfo.token0,
            size: 36,
          ),
        ),
        24.vSpacing,
        NomoInput(
          background: context.colors.background2.withOpacity(0.5),
          trailling: AssetPicture(
            token: pairInfo.token1,
            size: 36,
          ),
        ),
        48.vSpacing,
        PrimaryNomoButton(
          text: "Withdraw", //state.buttonText,
          //type: state.buttonType,
          // onPressed: provider.deposit,
          expandToConstraints: true,
          //    enabled: state.buttonEnabled,
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          borderRadius: BorderRadius.circular(16),
          textStyle: context.typography.h1,
        ),
      ],
    );
  }
}
