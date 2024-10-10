import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nomo_ui_kit/components/app/bottom_bar/nomo_bottom_bar.dart';
import 'package:nomo_ui_kit/components/buttons/primary/nomo_primary_button.dart';
import 'package:nomo_ui_kit/components/dialog/nomo_dialog.dart';
import 'package:nomo_ui_kit/components/divider/nomo_divider.dart';
import 'package:nomo_ui_kit/components/dropdownmenu/drop_down_item.dart';
import 'package:nomo_ui_kit/components/dropdownmenu/dropdownmenu.dart';
import 'package:nomo_ui_kit/components/input/textInput/nomo_input.dart';
import 'package:nomo_ui_kit/components/text/nomo_text.dart';
import 'package:nomo_ui_kit/entities/menu_item.dart';
import 'package:nomo_ui_kit/theme/nomo_theme.dart';
import 'package:nomo_ui_kit/theme/theme_provider.dart';
import 'package:nomo_ui_kit/utils/layout_extensions.dart';
import 'package:webon_kit_dart/webon_kit_dart.dart';
import 'package:zeniq_swap_frontend/common/price_repository.dart';
import 'package:zeniq_swap_frontend/providers/asset_notifier.dart';
import 'package:zeniq_swap_frontend/providers/swap_provider.dart';
import 'package:zeniq_swap_frontend/theme.dart';

class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final assetNotifer = InheritedAssetProvider.of(context);
    final swapProcider = InheritedSwapProvider.of(context);
    return NomoDialog(
      maxWidth: 420,
      widthRatio: 0.9,
      leading: NomoText(
        "Settings",
        style: context.typography.h1,
        fontSize: context.typography.b3.fontSize,
      ),
      backgroundColor: context.colors.background2,
      padding: const EdgeInsets.all(24),
      elevation: 0.0.ifElse(context.isDark, other: 1),
      border: Border.all(
        color: Colors.white24,
        strokeAlign: BorderSide.strokeAlignInside,
        width: 1,
      ).ifElseNull(context.isDark),
      showCloseButton: false,
      borderRadius: BorderRadius.circular(16),
      content: Column(
        children: [
          12.vSpacing,
          Row(
            children: [
              NomoText("Theme", style: context.typography.b1),
              const Spacer(),
              SizedBox(
                width: 160,
                child: NomoBottomBar(
                  items: const [
                    NomoMenuIconItem(
                      title: "Dark",
                      key: ColorMode.DARK,
                      icon: Icons.dark_mode,
                    ),
                    NomoMenuIconItem(
                      title: "Light",
                      key: ColorMode.LIGHT,
                      icon: Icons.light_mode,
                    ),
                  ],
                  elevation: 0,
                  selected: context.getColorMode(),
                  onTap: (item) {
                    ThemeProvider.of(context).changeColorTheme(item.key);
                    WebLocalStorage.setItem("theme",
                        item.key == ColorMode.LIGHT ? "light" : "dark");
                  },
                  borderRadius: BorderRadius.circular(16),
                  background: context.colors.background1,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  itemWidth: 64,
                  style: context.typography.b1.copyWith(fontSize: 12),
                  itemPadding: EdgeInsets.zero,
                  iconSize: 22,
                  height: 58,
                ),
              ),
            ],
          ),
          16.vSpacing,
          Row(
            children: [
              NomoText("Currency", style: context.typography.b1),
              const Spacer(),
              NomoDropDownMenu(
                width: 160,
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
            ],
          ),
          32.vSpacing,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NomoText("Slippage Tolerance", style: context.typography.b1),
              16.vSpacing,
              NomoInput(
                background: context.colors.background1,
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                trailling: NomoText(
                  "%",
                  style: context.typography.b1,
                ),
                valueNotifier: swapProcider.slippageString,
                style: context.typography.b1,
                textAlign: TextAlign.end,
                maxLines: 1,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(
                      r'^\d+([.,]?\d{0,' + (3).toString() + r'})',
                    ),
                  ),
                ],
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final slippage in [0.1, 0.5, 1.0])
                      PrimaryNomoButton(
                        text: "$slippage%",
                        padding: EdgeInsets.zero,
                        backgroundColor: context.colors.background3,
                        width: 48,
                        height: 32,
                        textStyle: context.typography.b1,
                        foregroundColor: context.colors.foreground3,
                        margin: const EdgeInsets.only(right: 8),
                        onPressed: () {
                          swapProcider.slippageString.value =
                              slippage.toString();
                        },
                      )
                  ],
                ),
              ),
            ],
          ),
          16.vSpacing,
        ],
      ),
    );
  }
}
