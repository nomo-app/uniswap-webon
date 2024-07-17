import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:nomo_ui_kit/components/buttons/secondary/nomo_secondary_button.dart';
import 'package:nomo_ui_kit/components/dialog/nomo_dialog.dart';
import 'package:nomo_ui_kit/components/divider/nomo_divider.dart';
import 'package:nomo_ui_kit/components/input/textInput/nomo_input.dart';
import 'package:nomo_ui_kit/components/loading/shimmer/loading_shimmer.dart';
import 'package:nomo_ui_kit/components/loading/shimmer/shimmer.dart';
import 'package:nomo_ui_kit/components/text/nomo_text.dart';
import 'package:nomo_ui_kit/theme/nomo_theme.dart';
import 'package:nomo_ui_kit/utils/layout_extensions.dart';
import 'package:zeniq_swap_frontend/pages/home.dart';
import 'package:zeniq_swap_frontend/providers/asset_notifier.dart';

class SelectAssetDialog extends StatelessWidget {
  const SelectAssetDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final balanceNotifer = InheritedAssetProvider.of(context);
    final assets = balanceNotifer.tokens;
    return Shimmer(
      child: NomoDialog(
        padding: const EdgeInsets.all(24),
        maxWidth: 480,
        widthRatio: 0.9,
        borderRadius: BorderRadius.circular(16),
        titleStyle: context.typography.h2,
        leading: NomoText(
          "Select Asset",
          style: context.typography.h2,
        ),
        content: SingleChildScrollView(
          child: Column(
            children: [
              NomoInput(
                titleStyle: context.typography.h2,
                placeHolder: "Search name or paste address",
                placeHolderStyle: context.typography.b3,
                height: 64,
              ),
              32.vSpacing,
              const Row(
                children: [
                  NomoText("Name"),
                  Spacer(),
                  SecondaryNomoButton(
                    icon: Icons.sort,
                    backgroundColor: Colors.transparent,
                    border: Border.fromBorderSide(BorderSide.none),
                  )
                ],
              ),
              const NomoDivider(),
              ListView.builder(
                shrinkWrap: true,
                itemCount: assets.length,
                itemBuilder: (context, index) {
                  final asset = assets[index];
                  final balanceListenable =
                      balanceNotifer.notifierForToken(asset);
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).pop(asset);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        height: 48,
                        child: Row(
                          children: [
                            4.hSpacing,
                            AssetPicture(token: asset),
                            12.hSpacing,
                            NomoText(
                              asset.name,
                              style: context.typography.h1,
                            ),
                            const Spacer(),
                            ValueListenableBuilder(
                              valueListenable: balanceListenable,
                              builder: (context, value, child) {
                                return value.when(
                                  data: (value) {
                                    return NomoText(
                                      value.displayDouble
                                          .toStringAsPrecision(5),
                                      style: context.typography.h1,
                                    );
                                  },
                                  error: (error) => NomoText(
                                    "Error",
                                    style: context.typography.h1,
                                  ),
                                  loading: () => ShimmerLoading(
                                    isLoading: true,
                                    child: Container(
                                      width: 100,
                                      height: 32,
                                      color: Colors.red,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}
