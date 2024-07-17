import 'package:flutter/material.dart';
import 'package:nomo_ui_kit/components/buttons/primary/nomo_primary_button.dart';
import 'package:nomo_ui_kit/components/dialog/nomo_dialog.dart';
import 'package:nomo_ui_kit/components/dropdownmenu/drop_down_item.dart';
import 'package:nomo_ui_kit/components/dropdownmenu/dropdownmenu.dart';
import 'package:nomo_ui_kit/components/input/textInput/nomo_input.dart';
import 'package:nomo_ui_kit/components/text/nomo_text.dart';
import 'package:nomo_ui_kit/theme/nomo_theme.dart';
import 'package:nomo_ui_kit/utils/layout_extensions.dart';
import 'package:zeniq_swap_frontend/common/price_repository.dart';
import 'package:zeniq_swap_frontend/providers/asset_notifier.dart';
import 'package:zeniq_swap_frontend/providers/swap_provider.dart';

class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final assetNotifer = InheritedAssetProvider.of(context);
    final swapProcider = InheritedSwapProvider.of(context);
    return NomoDialog(
      maxWidth: 480,
      leading: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NomoText("Settings", style: context.typography.h1),
          8.vSpacing,
          NomoText(
            "Adjust to your personal preference",
            style: context.typography.b1,
            color: Colors.white54,
          ),
        ],
      ),
      backgroundColor: context.colors.background2,
      padding: EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(16),
      content: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            16.vSpacing,
            Row(
              children: [
                NomoText("Currency", style: context.typography.b3),
                Spacer(),
                SizedBox(
                  width: 200,
                  child: NomoDropDownMenu(
                    backgroundColor: context.colors.background1,
                    dropdownColor: context.colors.background1,
                    borderRadius: BorderRadius.circular(16),
                    itemPadding: const EdgeInsets.symmetric(horizontal: 24),
                    valueNotifer: assetNotifer.currencyNotifier,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    iconColor: context.colors.foreground1,
                    height: 48,
                    items: [
                      for (final currency in Currency.values)
                        NomoDropDownItemString(
                          value: currency,
                          title: "${currency.displayName} ${currency.symbol} ",
                        )
                    ],
                  ),
                ),
              ],
            ),
            16.vSpacing,
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NomoText("Slippage Tolerance", style: context.typography.b3),
                16.vSpacing,
                NomoInput(
                  background: context.colors.background1,
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  trailling: NomoText(
                    "%",
                    style: context.typography.b3,
                  ),
                  valueNotifier: swapProcider.slippageString,
                  style: context.typography.b3,
                  textAlign: TextAlign.end,
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final slippage in [0.1, 0.5, 1.0])
                        PrimaryNomoButton(
                          text: "$slippage%",
                          padding: EdgeInsets.zero,
                          backgroundColor:
                              const Color.fromARGB(0, 212, 102, 102),
                          width: 48,
                          height: 32,
                          textStyle: context.typography.b1,
                          margin: EdgeInsets.only(right: 8),
                          onPressed: () {
                            swapProcider.slippageString.value =
                                slippage.toString();
                          },
                        )
                    ],
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
