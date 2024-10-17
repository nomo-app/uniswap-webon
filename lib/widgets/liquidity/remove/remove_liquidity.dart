import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nomo_ui_kit/app/notifications/app_notification.dart';
import 'package:nomo_ui_kit/components/buttons/primary/nomo_primary_button.dart';
import 'package:nomo_ui_kit/components/buttons/secondary/nomo_secondary_button.dart';
import 'package:nomo_ui_kit/components/input/textInput/nomo_input.dart';
import 'package:nomo_ui_kit/components/loading/loading.dart';
import 'package:nomo_ui_kit/components/notification/nomo_notification.dart';
import 'package:nomo_ui_kit/components/text/nomo_text.dart';
import 'package:nomo_ui_kit/theme/nomo_theme.dart';
import 'package:nomo_ui_kit/utils/layout_extensions.dart';
import 'package:provider/provider.dart';
import 'package:webon_kit_dart/webon_kit_dart.dart';
import 'package:zeniq_swap_frontend/main.dart';
import 'package:zeniq_swap_frontend/providers/add_liquidity_provider.dart';
import 'package:zeniq_swap_frontend/providers/models/pair_info.dart';
import 'package:zeniq_swap_frontend/providers/pool_provider.dart';
import 'package:zeniq_swap_frontend/providers/remove_liqudity_provider.dart';
import 'package:zeniq_swap_frontend/widgets/asset_picture.dart';
import 'package:zeniq_swap_frontend/widgets/liquidity/add/add_liquidity_input_bottom.dart';
import 'package:zeniq_swap_frontend/widgets/swap/token_price_display.dart';

final percentages = <double>[0.25, 0.5, 0.75, 1];

class PoolRemoveLiquidity extends StatefulWidget {
  final ValueNotifier<PairInfoEntity> pairInfoNotifer;

  const PoolRemoveLiquidity({
    super.key,
    required this.pairInfoNotifer,
  });

  @override
  State<PoolRemoveLiquidity> createState() => _PoolRemoveLiquidityState();
}

class _PoolRemoveLiquidityState extends State<PoolRemoveLiquidity> {
  late final RemoveLiqudityProvider provider;

  OwnedPairInfo get pairInfo => widget.pairInfoNotifer.value as OwnedPairInfo;

  @override
  void initState() {
    provider = RemoveLiqudityProvider(
      poolProvider: context.read<PoolProvider>(),
      pairInfoNotifier: widget.pairInfoNotifer,
      addressNotifier: $addressNotifier,
      slippageNotifier: $slippageNotifier,
      needToBroadcast: $inNomo,
      signer: $inNomo ? WebonKitDart.signTransaction : metamaskSigner,
    );
    provider.removeState.addListener(removeStateChanged);
    super.initState();
  }

  @override
  void dispose() {
    provider.removeState.removeListener(removeStateChanged);
    provider.dispose();
    super.dispose();
  }

  void removeStateChanged() {
    if (mounted == false) return;
    final removeState = provider.removeState.value;
    print("Remove state changed: ${removeState}");

    /// User just completed the swap
    if (removeState == RemoveLiqudityState.removed) {
      final depositInfo = provider.removeInfoNotifier
          .value; // TODO: This needs to be more precise and only refresh the tokens that are affected

      InAppNotification.show(
        right: 16,
        top: 16,
        useRootNavigator: true,
        child: NomoNotification(
          title: "Liquidity added",
          subtitle: depositInfo.toString(),
          leading: Icon(
            Icons.check,
            color: context.colors.primary,
            size: 36,
          ),
          titleStyle: context.typography.b2,
          subtitleStyle: context.typography.b1,
          spacing: 16,
          showCloseButton: false,
        ),
        context: context,
      );
      return;
    }

    /// User just completed the swap
    if (removeState == RemoveLiqudityState.confirming) {
      InAppNotification.show(
        right: 16,
        top: 16,
        useRootNavigator: true,
        child: NomoNotification(
          title: "Transaction Pending",
          subtitle: "Waiting for transaction confirmation",
          leading: Loading(
            size: 20,
          ),
          titleStyle: context.typography.b2,
          subtitleStyle: context.typography.b1,
          spacing: 16,
          showCloseButton: false,
        ),
        context: context,
      );
      return;
    }

    /// Error when broadcasting or confirming the swap
    if (removeState == RemoveLiqudityState.error) {
      InAppNotification.show(
        right: 16,
        top: 16,
        useRootNavigator: true,
        child: NomoNotification(
          title: "Error",
          subtitle: "An error occurred while providing Liquidity",
          showCloseButton: false,
          titleStyle: context.typography.b2,
          subtitleStyle: context.typography.b1,
          spacing: 16,
          leading: Icon(
            Icons.error,
            color: context.colors.error,
            size: 36,
          ),
        ),
        context: context,
      );
      return;
    }

    /// Error when approving the token
    if (removeState == AddLiquidityState.tokenApprovalError) {
      InAppNotification.show(
        right: 16,
        top: 16,
        useRootNavigator: true,
        child: NomoNotification(
          title: "Token Approval Error",
          subtitle: "An error occurred while approving the token",
          showCloseButton: false,
          titleStyle: context.typography.b2,
          subtitleStyle: context.typography.b1,
          spacing: 16,
          leading: Icon(
            Icons.error,
            color: context.colors.error,
            size: 36,
          ),
        ),
        context: context,
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderThemeData(
        trackShape: CustomSliderTrackShape(),
        thumbShape: CustomSliderThumbShape(),
        overlayShape: CustomSliderOverlayShape(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NomoText(
                  "Remove",
                  style: context.typography.b3,
                ),
                12.vSpacing,
                NomoText(
                  "Remove to receive pool tokens and earned trading fees",
                  style: context.typography.b2,
                ),
              ],
            ),
          ),
          24.vSpacing,
          ValueListenableBuilder(
            valueListenable: provider.removeState,
            builder: (context, state, child) {
              return NomoInput(
                maxLines: 1,
                scrollable: true,
                enabled:
                    state.inputsEnabled && !provider.onlyAllowRemovingFully,
                valueNotifier: provider.poolTokenInputNotifier,
                style: context.typography.b3,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(
                      r'^\d+([.,]?\d{0,' + 18.toString() + r'})',
                    ),
                  ),
                ],
                errorNotifier: provider.inputErrorNotifer,
                trailling: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AssetPicture(
                      token: provider.pairInfo.token0,
                      size: 36,
                    ),
                    AssetPicture(
                      token: provider.pairInfo.token1,
                      size: 36,
                    )
                  ],
                ),
                padding: EdgeInsets.symmetric(vertical: 24, horizontal: 24),
                bottom: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          PoolTokenInputBottom(
                            pair: provider.pairInfo,
                            amountNotifier: provider.poolTokenAmountNotifier,
                          ),
                          Spacer(),
                          NomoText(
                            "Balance: ",
                            style: context.typography.b1,
                            opacity: 0.6,
                          ),
                          ValueListenableBuilder(
                            valueListenable: provider.pairInfoNotifier,
                            builder: (context, __, _) {
                              return NomoText(
                                "${pairInfo.pairTokenAmountAmount.displayDouble.toStringAsFixed(2)}",
                                style: context.typography.b1,
                              );
                            },
                          ),
                        ],
                      ),
                      8.vSpacing,
                      Material(
                        type: MaterialType.transparency,
                        child: ValueListenableBuilder(
                          valueListenable: provider.poolTokenAmountNotifier,
                          builder: (context, poolAmount, child) {
                            final _max = provider
                                .pairInfo.pairTokenAmountAmount.displayDouble;
                            final _val = poolAmount?.displayDouble ?? 0;
                            final value = min(_max, _val);
                            return Slider(
                              value: value,
                              min: 0,
                              max: _max,
                              onChanged: (value) {
                                provider.poolTokenInputNotifier.value =
                                    value.toString();
                              },
                              inactiveColor: context.theme.colors.primary,
                              activeColor: context.theme.colors.primary,
                            );
                          },
                        ),
                      ),
                      8.vSpacing,
                      Row(
                        children: [
                          for (final percentage in percentages)
                            Expanded(
                              child: SecondaryNomoButton(
                                backgroundColor: Colors.transparent,
                                height: 36,
                                text: "${(percentage * 100).toInt()}%",
                                onPressed: () {
                                  provider.setPoolTokenPercentage(percentage);
                                },
                              ),
                            )
                        ].spacingH(12),
                      )
                    ],
                  ),
                ),
              );
            },
          ),
          24.vSpacing,
          ValueListenableBuilder(
            valueListenable: provider.removeState,
            builder: (context, state, child) {
              return NomoInput(
                enabled:
                    state.inputsEnabled && !provider.onlyAllowRemovingFully,
                top: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      NomoText(
                        pairInfo.token0.symbol,
                      ),
                      Spacer(),
                      TokenPriceDisplay(
                        token: pairInfo.token0,
                        type: pairInfo.type,
                      ),
                    ],
                  ),
                ),
                maxLines: 1,
                scrollable: true,
                padding: EdgeInsets.all(24),
                style: context.typography.b3,
                valueNotifier: provider.token0InputNotifier,
                background: context.colors.background2.withOpacity(0.5),
                trailling: AssetPicture(
                  token: pairInfo.token0,
                  size: 36,
                ),
                errorNotifier: provider.inputErrorNotifer,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(
                      r'^\d+([.,]?\d{0,' +
                          pairInfo.token0.decimals.toString() +
                          r'})',
                    ),
                  ),
                ],
                bottom: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: ValueListenableBuilder(
                    valueListenable: provider.pairInfoNotifier,
                    builder: (context, __, _) {
                      return AddLiqudityInputBottom(
                        token: pairInfo.token0,
                        amountNotifier: provider.token0AmountNotifier,
                        balance: pairInfo.myAmount0,
                        balanceString: "In Pool:",
                      );
                    },
                  ),
                ),
              );
            },
          ),
          16.vSpacing,
          ValueListenableBuilder(
            valueListenable: provider.removeState,
            builder: (context, state, child) {
              return NomoInput(
                enabled:
                    state.inputsEnabled && !provider.onlyAllowRemovingFully,
                top: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      NomoText(
                        pairInfo.token1.symbol,
                      ),
                      Spacer(),
                      TokenPriceDisplay(
                        token: pairInfo.token1,
                        type: pairInfo.type,
                      ),
                    ],
                  ),
                ),
                scrollable: true,
                maxLines: 1,
                padding: EdgeInsets.all(24),
                style: context.typography.b3,
                valueNotifier: provider.token1InputNotifier,
                background: context.colors.background2.withOpacity(0.5),
                trailling: AssetPicture(
                  token: pairInfo.token1,
                  size: 36,
                ),
                errorNotifier: provider.inputErrorNotifer,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(
                      r'^\d+([.,]?\d{0,' +
                          pairInfo.token1.decimals.toString() +
                          r'})',
                    ),
                  ),
                ],
                bottom: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: ValueListenableBuilder(
                    valueListenable: provider.pairInfoNotifier,
                    builder: (context, __, _) {
                      return AddLiqudityInputBottom(
                        token: pairInfo.token1,
                        amountNotifier: provider.token1AmountNotifier,
                        balance: pairInfo.myAmount1,
                        balanceString: "In Pool:",
                      );
                    },
                  ),
                ),
              );
            },
          ),
          48.vSpacing,
          ValueListenableBuilder(
            valueListenable: provider.removeState,
            builder: (context, state, child) {
              return PrimaryNomoButton(
                text: state.buttonText,
                type: state.buttonType,
                onPressed: provider.remove,
                expandToConstraints: true,
                enabled: state.buttonEnabled,
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                borderRadius: BorderRadius.circular(16),
                textStyle: context.typography.h1,
              );
            },
          ),
        ],
      ),
    );
  }
}

class CustomSliderTrackShape extends RoundedRectSliderTrackShape {
  const CustomSliderTrackShape();
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight;
    final trackLeft = offset.dx;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight!) / 2;
    final trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}

class CustomSliderThumbShape extends RoundSliderThumbShape {
  const CustomSliderThumbShape({super.enabledThumbRadius = 10.0});

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    super.paint(context,
        center.translate(-(value - 0.5) / 0.5 * enabledThumbRadius, 0.0),
        activationAnimation: activationAnimation,
        enableAnimation: enableAnimation,
        isDiscrete: isDiscrete,
        labelPainter: labelPainter,
        parentBox: parentBox,
        sliderTheme: sliderTheme,
        textDirection: textDirection,
        value: value,
        textScaleFactor: textScaleFactor,
        sizeWithOverflow: sizeWithOverflow);
  }
}

class CustomSliderOverlayShape extends RoundSliderOverlayShape {
  final double thumbRadius;
  const CustomSliderOverlayShape({this.thumbRadius = 10.0});

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    super.paint(
        context, center.translate(-(value - 0.5) / 0.5 * thumbRadius, 0.0),
        activationAnimation: activationAnimation,
        enableAnimation: enableAnimation,
        isDiscrete: isDiscrete,
        labelPainter: labelPainter,
        parentBox: parentBox,
        sliderTheme: sliderTheme,
        textDirection: textDirection,
        value: value,
        textScaleFactor: textScaleFactor,
        sizeWithOverflow: sizeWithOverflow);
  }
}
