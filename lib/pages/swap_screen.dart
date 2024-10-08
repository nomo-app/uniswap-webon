import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nomo_router/nomo_router.dart';
import 'package:nomo_ui_kit/app/notifications/app_notification.dart';
import 'package:nomo_ui_kit/components/app/routebody/nomo_route_body.dart';
import 'package:nomo_ui_kit/components/buttons/link/nomo_link_button.dart';
import 'package:nomo_ui_kit/components/buttons/primary/nomo_primary_button.dart';
import 'package:nomo_ui_kit/components/buttons/secondary/nomo_secondary_button.dart';
import 'package:nomo_ui_kit/components/card/nomo_card.dart';
import 'package:nomo_ui_kit/components/divider/nomo_divider.dart';
import 'package:nomo_ui_kit/components/info_item/nomo_info_item.dart';
import 'package:nomo_ui_kit/components/input/textInput/nomo_input.dart';
import 'package:nomo_ui_kit/components/loading/loading.dart';
import 'package:nomo_ui_kit/components/loading/shimmer/loading_shimmer.dart';
import 'package:nomo_ui_kit/components/loading/shimmer/shimmer.dart';
import 'package:nomo_ui_kit/components/notification/nomo_notification.dart';
import 'package:nomo_ui_kit/components/text/nomo_text.dart';
import 'package:nomo_ui_kit/theme/nomo_theme.dart';
import 'package:nomo_ui_kit/utils/layout_extensions.dart';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/common/async_value.dart';
import 'package:zeniq_swap_frontend/common/extensions.dart';
import 'package:zeniq_swap_frontend/common/price_repository.dart';
import 'package:zeniq_swap_frontend/main.dart';
import 'package:zeniq_swap_frontend/pages/background.dart';
import 'package:zeniq_swap_frontend/providers/asset_notifier.dart';
import 'package:zeniq_swap_frontend/providers/image_provider.dart';
import 'package:zeniq_swap_frontend/providers/swap_provider.dart';
import 'package:zeniq_swap_frontend/routes.dart';

class SwappingScreen extends StatefulWidget {
  const SwappingScreen({super.key});

  @override
  State<SwappingScreen> createState() => _SwappingScreenState();
}

class _SwappingScreenState extends State<SwappingScreen> {
  late SwapProvider swapProvider;
  late AssetNotifier assetProvider;

  late final ValueNotifier<String?> fromErrorNotifier = ValueNotifier(null);
  late final ValueNotifier<String?> toErrorNotifier = ValueNotifier(null);

  late final ValueNotifier<bool> inversePriceRateNotifer = ValueNotifier(false);

  late final FocusNode fromFocusNode = FocusNode();
  late final FocusNode toFocusNode = FocusNode();

  bool keyboardShown = false;

  @override
  void didChangeDependencies() {
    swapProvider = InheritedSwapProvider.of(context);
    assetProvider = InheritedAssetProvider.of(context);

    swapProvider.swapState.addListener(swapStateChanged);
    swapProvider.fromAmount.addListener(fromAmountChanged);
    swapProvider.toAmount.addListener(toAmountChanged);

    swapProvider.addressNotifier.addListener(recheckBalances);

    keyboardShown = MediaQuery.of(context).viewInsets.bottom > 0;

    super.didChangeDependencies();
  }

  void recheckBalances() {
    if (swapProvider.lastAmountChanged == LastAmountChanged.From) {
      fromAmountChanged();
    } else {
      toAmountChanged();
    }
  }

  /// Checking Balance
  void toAmountChanged() {
    if (swapProvider.shouldRecalculateSwapType == false) return;

    final toToken = swapProvider.toToken.value;
    if (toToken == null) return;

    final toAmount = swapProvider.toAmount.value;
    if (toAmount == null || toAmount.value == BigInt.zero) {
      return;
    }

    final balanceNotifier = assetProvider.balanceNotifierForToken(toToken);
    final balanceAsync = balanceNotifier.value;

    void checkToAmountError(Amount balance, Amount toAmount) {
      fromErrorNotifier.value = null;
      if (toAmount.value > balance.value) {
        toErrorNotifier.value = "Insufficient balance";
        swapProvider.swapState.value = SwapState.InsufficientBalance;
      } else {
        toErrorNotifier.value = null;
        swapProvider.swapState.value = SwapState.None;
      }
    }

    if (balanceAsync is Value) {
      checkToAmountError((balanceAsync as Value<Amount>).value, toAmount);
      return;
    }

    if (balanceAsync is AsyncLoading) {
      void listener() {
        final balanceAsync = balanceNotifier.value;
        if (balanceAsync is Value) {
          checkToAmountError(
            (balanceAsync as Value<Amount>).value,
            toAmount,
          );
          balanceNotifier.removeListener(listener);
        }
      }

      balanceNotifier.addListener(listener);
    }
  }

  /// Checking Balance
  void fromAmountChanged() {
    if (swapProvider.shouldRecalculateSwapType == false) return;

    final fromToken = swapProvider.fromToken.value;
    if (fromToken == null) return;

    final fromAmount = swapProvider.fromAmount.value;
    if (fromAmount == null || fromAmount.value == BigInt.zero) {
      return;
    }

    final balanceNotifier = assetProvider.balanceNotifierForToken(fromToken);
    final balanceAsync = balanceNotifier.value;

    void checkFromAmountError(Amount balance, Amount fromAmount) {
      toErrorNotifier.value = null;
      if (fromAmount.value > balance.value) {
        fromErrorNotifier.value = "Insufficient balance";
        swapProvider.swapState.value = SwapState.InsufficientBalance;
      } else {
        fromErrorNotifier.value = null;
        swapProvider.swapState.value = SwapState.None;
      }
    }

    if (balanceAsync is Value) {
      checkFromAmountError((balanceAsync as Value<Amount>).value, fromAmount);
      return;
    }

    if (balanceAsync is AsyncLoading) {
      void listener() {
        final balanceAsync = balanceNotifier.value;
        if (balanceAsync is Value) {
          checkFromAmountError(
            (balanceAsync as Value<Amount>).value,
            fromAmount,
          );
          balanceNotifier.removeListener(listener);
        }
      }

      balanceNotifier.addListener(listener);
    }
  }

  @override
  void dispose() {
    swapProvider.swapState.removeListener(swapStateChanged);
    swapProvider.fromAmount.removeListener(fromAmountChanged);
    swapProvider.toAmount.removeListener(toAmountChanged);
    swapProvider.addressNotifier.removeListener(recheckBalances);
    super.dispose();
  }

  void swapStateChanged() {
    if (mounted == false) return;
    print("Swap State: ${swapProvider.swapState.value}");

    final swapState = swapProvider.swapState.value;

    /// User just completed the swap
    if (swapState == SwapState.Swapped) {
      final swapInfo = swapProvider.swapInfo.value;

      assetProvider.refresh();
      InAppNotification.show(
        right: 16,
        top: 16,
        child: NomoNotification(
          title: "Swap Completed",
          subtitle: swapInfo.toString(),
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
    if (swapState == SwapState.Confirming) {
      assetProvider.refresh();
      InAppNotification.show(
        right: 16,
        top: 16,
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
    if (swapState == SwapState.Error) {
      InAppNotification.show(
        right: 16,
        top: 16,
        child: NomoNotification(
          title: "Swap Error",
          subtitle: "An error occurred while swapping",
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
    if (swapState == SwapState.TokenApprovalError) {
      InAppNotification.show(
        right: 16,
        top: 16,
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
    return Shimmer(
      child: NomoRouteBody(
        background: AppBackground(),
        maxContentWidth: 480,
        padding: EdgeInsets.zero,
        child: TapIgnoreDragDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: TextFieldTapRegion(
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      NomoText(
                        "Swap",
                        style: context.typography.h3.copyWith(fontSize: 64),
                      ),
                      const Spacer(),
                      Image.asset(
                        'assets/logo.png',
                        width: 64,
                        height: 64,
                      ),
                    ],
                  ),
                  32.vSpacing,
                  Row(
                    children: [
                      const Spacer(),
                      PrimaryNomoButton(
                        backgroundColor: context.colors.background2,
                        foregroundColor: context.colors.foreground1,
                        height: 32,
                        width: 48,
                        iconSize: 18,
                        borderRadius: BorderRadius.circular(16),
                        icon: Icons.refresh_rounded,
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          swapProvider.checkSwapInfo();
                          assetProvider.refresh();
                        },
                      ),
                      12.hSpacing,
                      PrimaryNomoButton(
                        backgroundColor: context.colors.background2,
                        foregroundColor: context.colors.foreground1,
                        height: 32,
                        width: 48,
                        iconSize: 18,
                        borderRadius: BorderRadius.circular(16),
                        icon: Icons.settings_outlined,
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          NomoNavigator.of(context).push(SettingsDialogRoute());
                        },
                      ),
                    ],
                  ),
                  16.vSpacing,
                  Column(
                    children: [
                      ListenableBuilder(
                        listenable: Listenable.merge([
                          swapProvider.fromToken,
                          swapProvider.swapState,
                        ]),
                        builder: (context, child) {
                          final token = swapProvider.fromToken.value;
                          final enabled =
                              swapProvider.swapState.value.inputEnabled;
                          return NomoInput(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            placeHolderStyle: context.typography.b3,
                            borderRadius: BorderRadius.circular(16),
                            style: context.typography.b3.copyWith(
                              color: context.colors.foreground1,
                            ),
                            border: const Border.fromBorderSide(
                              BorderSide(color: Colors.white10),
                            ),
                            hitTestBehavior: HitTestBehavior.deferToChild,
                            top: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  NomoText(
                                    "From",
                                    style: context.typography.b2,
                                  ),
                                  ValueListenableBuilder(
                                    valueListenable: swapProvider.swapInfo,
                                    builder: (context, swapInfo, child) {
                                      final fromEstimated =
                                          swapInfo is ToSwapInfo;
                                      if (fromEstimated) {
                                        return NomoText(
                                          " (estimated)",
                                          style: context.typography.b1,
                                          opacity: 0.8,
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                  Spacer(),
                                  if (token != null)
                                    TokenPriceDisplay(token: token),
                                ],
                              ),
                            ),
                            focusNode: fromFocusNode,
                            onTap: () {
                              if (fromFocusNode.hasFocus && !keyboardShown) {
                                fromFocusNode.unfocus();
                                Future.microtask(
                                    () => fromFocusNode.requestFocus());
                              }
                            },
                            background:
                                context.colors.background2.withOpacity(0.5),
                            enabled: enabled,
                            errorNotifier: fromErrorNotifier,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            placeHolder: '0',
                            valueNotifier: swapProvider.fromAmountString,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(
                                  r'^\d+([.,]?\d{0,' +
                                      (token?.decimals ?? 18).toString() +
                                      r'})',
                                ),
                              ),
                            ],
                            scrollable: true,
                            maxLines: 1,
                            bottom: SwapInputBottom(
                              token: token,
                              isFrom: true,
                            ),
                            trailling: SwapInputTrailling(
                              token: token,
                              onTokenSelected: (token) {
                                if (swapProvider.toAmount.value == null) {
                                  fromFocusNode.requestFocus();
                                }
                                swapProvider.setFromToken(token);
                              },
                            ),
                          );
                        },
                      ),
                      16.vSpacing,
                      Center(
                        child: PrimaryNomoButton(
                          icon: Icons.swap_vert,
                          height: 48,
                          width: 48,
                          shape: BoxShape.circle,
                          padding: EdgeInsets.zero,
                          foregroundColor: Colors.white,
                          backgroundColor:
                              context.colors.background2.withOpacity(0.5),
                          onPressed: () {
                            swapProvider.changePosition();
                          },
                        ),
                      ),
                      16.vSpacing,
                      ListenableBuilder(
                        listenable: Listenable.merge([
                          swapProvider.toToken,
                          swapProvider.swapState,
                        ]),
                        builder: (context, child) {
                          final token = swapProvider.toToken.value;
                          final enabled =
                              swapProvider.swapState.value.inputEnabled;
                          return NomoInput(
                            top: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  NomoText(
                                    "To",
                                    style: context.typography.b2,
                                  ),
                                  ValueListenableBuilder(
                                    valueListenable: swapProvider.swapInfo,
                                    builder: (context, swapInfo, child) {
                                      final toEstimated =
                                          swapInfo is FromSwapInfo;
                                      if (toEstimated) {
                                        return NomoText(
                                          " (estimated)",
                                          style: context.typography.b1,
                                          opacity: 0.8,
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                  Spacer(),
                                  if (token != null)
                                    TokenPriceDisplay(token: token),
                                ],
                              ),
                            ),
                            hitTestBehavior: HitTestBehavior.deferToChild,
                            focusNode: toFocusNode,
                            onTap: () {
                              if (toFocusNode.hasFocus && !keyboardShown) {
                                toFocusNode.unfocus();
                                Future.microtask(
                                    () => toFocusNode.requestFocus());
                              }
                            },
                            enabled: enabled,
                            maxLines: 1,
                            scrollable: true,
                            style: context.typography.b3.copyWith(
                              color: context.colors.foreground1,
                            ),
                            placeHolderStyle: context.typography.b3,
                            background:
                                context.colors.background2.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(16),
                            errorNotifier: toErrorNotifier,
                            placeHolder: '0',
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            bottom: ValueListenableBuilder(
                              valueListenable: swapProvider.fromToken,
                              builder: (context, fromToken, _) {
                                return SwapInputBottom(
                                  token: token,
                                  showMax: false,
                                  isFrom: false,
                                  otherToken: fromToken,
                                );
                              },
                            ),
                            border: const Border.fromBorderSide(
                              BorderSide(color: Colors.white10),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(
                                  r'^\d+([.,]?\d{0,' +
                                      (token?.decimals ?? 18).toString() +
                                      r'})',
                                ),
                              ),
                            ],
                            valueNotifier: swapProvider.toAmountString,
                            trailling: ValueListenableBuilder(
                              valueListenable: swapProvider.toToken,
                              builder: (context, value, child) {
                                return SwapInputTrailling(
                                  token: value,
                                  onTokenSelected: (token) {
                                    if (swapProvider.fromAmount.value == null) {
                                      toFocusNode.requestFocus();
                                    }
                                    swapProvider.setToToken(token);
                                  },
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  32.vSpacing,
                  ValueListenableBuilder(
                    valueListenable: swapProvider.swapInfo,
                    builder: (context, swapInfo, child) {
                      return AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: swapInfo == null ? 0 : 1,
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          child: swapInfo == null
                              ? Row()
                              : Builder(builder: (context) {
                                  final priceImpactInfo =
                                      swapInfo.priceImpact.formatPriceImpact();

                                  final priceImpactStyle =
                                      context.typography.b1.copyWith(
                                    color: priceImpactInfo.$2,
                                  );

                                  return Column(
                                    children: [
                                      NomoDividerThemeOverride(
                                        data: NomoDividerThemeDataNullable(
                                          crossAxisSpacing: 12,
                                          color: Colors.white12,
                                        ),
                                        child: NomoInfoItemThemeOverride(
                                          data: NomoInfoItemThemeDataNullable(
                                            titleStyle: context.typography.b1
                                                .copyWith(
                                                    color: context
                                                        .colors.foreground3),
                                            valueStyle: context.typography.b1,
                                          ),
                                          child: NomoCard(
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 24),
                                            backgroundColor: context
                                                .colors.background2
                                                .withOpacity(0.5),
                                            border: const Border.fromBorderSide(
                                              BorderSide(color: Colors.white10),
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                ...switch (swapInfo) {
                                                  FromSwapInfo info => [
                                                      ValueListenableBuilder(
                                                        valueListenable:
                                                            inversePriceRateNotifer,
                                                        builder: (context,
                                                            inverse, _) {
                                                          return Row(
                                                            children: [
                                                              Expanded(
                                                                child:
                                                                    NomoInfoItem(
                                                                  title:
                                                                      "Price",
                                                                  value: info
                                                                      .getPrice(
                                                                          inverse),
                                                                ),
                                                              ),
                                                              8.hSpacing,
                                                              PrimaryNomoButton(
                                                                icon: Icons
                                                                    .swap_horiz,
                                                                backgroundColor: context
                                                                    .colors
                                                                    .background2
                                                                    .withOpacity(
                                                                        0.5),
                                                                padding:
                                                                    EdgeInsets
                                                                        .all(8),
                                                                iconSize: 20,
                                                                shape: BoxShape
                                                                    .circle,
                                                                onPressed: () =>
                                                                    inversePriceRateNotifer
                                                                            .value =
                                                                        !inversePriceRateNotifer
                                                                            .value,
                                                              ),
                                                            ],
                                                          );
                                                        },
                                                      ),
                                                      const NomoDivider(),
                                                      NomoInfoItem(
                                                        title:
                                                            "Slippage Tolerance",
                                                        value:
                                                            "${info.slippage}%",
                                                      ),
                                                      const NomoDivider(),
                                                      NomoInfoItem(
                                                        title: "Price Impact",
                                                        value:
                                                            "${priceImpactInfo.$1}%",
                                                        valueStyle:
                                                            priceImpactStyle,
                                                      ),
                                                      const NomoDivider(),
                                                      NomoInfoItem(
                                                        title: "Fee",
                                                        value:
                                                            "${info.fee.displayDouble.toMaxPrecisionWithoutScientificNotation(5)} ${info.fromToken.symbol}",
                                                      ),
                                                      const NomoDivider(),
                                                      NomoInfoItem(
                                                        title:
                                                            "Minimum Received",
                                                        value:
                                                            "${info.amountOutMin.displayDouble.toMaxPrecisionWithoutScientificNotation(5)} ${info.toToken.symbol}",
                                                      ),
                                                    ],
                                                  ToSwapInfo info => [
                                                      ValueListenableBuilder(
                                                        valueListenable:
                                                            inversePriceRateNotifer,
                                                        builder: (context,
                                                            inverse, _) {
                                                          return Row(
                                                            children: [
                                                              Expanded(
                                                                child:
                                                                    NomoInfoItem(
                                                                  title:
                                                                      "Price",
                                                                  value: info
                                                                      .getPrice(
                                                                          inverse),
                                                                ),
                                                              ),
                                                              8.hSpacing,
                                                              PrimaryNomoButton(
                                                                icon: Icons
                                                                    .swap_horiz,
                                                                iconSize: 20,
                                                                backgroundColor: context
                                                                    .colors
                                                                    .background2
                                                                    .withOpacity(
                                                                        0.5),
                                                                padding:
                                                                    EdgeInsets
                                                                        .all(8),
                                                                shape: BoxShape
                                                                    .circle,
                                                                onPressed: () =>
                                                                    inversePriceRateNotifer
                                                                            .value =
                                                                        !inversePriceRateNotifer
                                                                            .value,
                                                              ),
                                                            ],
                                                          );
                                                        },
                                                      ),
                                                      const NomoDivider(),
                                                      NomoInfoItem(
                                                        title:
                                                            "Slippage Tolerance",
                                                        value:
                                                            "${info.slippage}%",
                                                      ),
                                                      const NomoDivider(),
                                                      NomoInfoItem(
                                                        title: "Price Impact",
                                                        value:
                                                            "${priceImpactInfo.$1}%",
                                                        valueStyle:
                                                            priceImpactStyle,
                                                      ),
                                                      const NomoDivider(),
                                                      NomoInfoItem(
                                                        title: "Fee",
                                                        value:
                                                            "${info.fee.displayDouble.toMaxPrecisionWithoutScientificNotation(5)} ${info.fromToken.symbol}",
                                                      ),
                                                      const NomoDivider(),
                                                      NomoInfoItem(
                                                        title: "Maximum sold",
                                                        value:
                                                            "${info.amountInMax.displayDouble.toMaxPrecisionWithoutScientificNotation(5)} ${info.fromToken.symbol}",
                                                      ),
                                                    ]
                                                },
                                                if (swapInfo.path.length >
                                                    2) ...[
                                                  const NomoDivider(),
                                                  4.vSpacing,
                                                  NomoText(
                                                    "Route",
                                                    style: context.typography.b1
                                                        .copyWith(
                                                            color:
                                                                Colors.white60),
                                                  ),
                                                  12.vSpacing,
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            8.0),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        AssetPicture(
                                                          token: swapInfo
                                                              .fromToken,
                                                        ),
                                                        8.hSpacing,
                                                        NomoText(swapInfo
                                                            .fromToken.symbol),
                                                        const Spacer(),
                                                        const Icon(
                                                          Icons.arrow_forward,
                                                          color: Colors.white60,
                                                        ),
                                                        const Spacer(),
                                                        const AssetPicture(
                                                          token:
                                                              zeniqTokenWrapper,
                                                        ),
                                                        8.hSpacing,
                                                        NomoText(
                                                          zeniqTokenWrapper
                                                              .name,
                                                        ),
                                                        const Spacer(),
                                                        const Icon(
                                                          Icons.arrow_forward,
                                                          color: Colors.white60,
                                                        ),
                                                        const Spacer(),
                                                        AssetPicture(
                                                          token:
                                                              swapInfo.toToken,
                                                        ),
                                                        8.hSpacing,
                                                        NomoText(
                                                          swapInfo
                                                              .toToken.symbol,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      32.vSpacing,
                                    ],
                                  );
                                }),
                        ),
                      );
                    },
                  ),
                  ListenableBuilder(
                    listenable: swapProvider.swapInfo,
                    builder: (context, child) {
                      final priceImpact =
                          swapProvider.swapInfo.value?.priceImpact;

                      if (priceImpact != null && priceImpact > 5) {
                        return NomoCard(
                          backgroundColor: context.colors.error,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          margin: EdgeInsets.only(bottom: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error, color: Colors.white),
                              8.hSpacing,
                              NomoText(
                                "High Price Impact, you may get a bad price",
                                style: context.typography.b1.copyWith(
                                  color: Colors.white,
                                ),
                                maxLines: 2,
                              ),
                            ],
                          ),
                        );
                      }

                      return const SizedBox.shrink();
                    },
                  ),
                  ListenableBuilder(
                    listenable: Listenable.merge([
                      swapProvider.swapState,
                      if ($inMetamask && $metamask != null) ...[
                        $metamask!.chainIdNotifier,
                        $metamask!.currentAccountNotifier,
                      ]
                    ]),
                    builder: (context, child) {
                      final showMetamask = $inMetamask &&
                          $metamask != null &&
                          ($metamask!.currentAccount == null ||
                              $metamask!.chainId != ZeniqSmartNetwork.chainId);

                      if (showMetamask) {
                        final connect = $metamask!.currentAccount == null;

                        return PrimaryNomoButton(
                          text: connect ? 'Connect Wallet' : 'Switch Network',
                          expandToConstraints: true,
                          height: 64,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          borderRadius: BorderRadius.circular(16),
                          textStyle: context.typography.h1,
                          onPressed: () {
                            if (connect) {
                              $metamask!.connect();
                              return;
                            }

                            $metamask!.switchChain(zeniqSmartChainInfo);
                          },
                        );
                      }

                      final state = swapProvider.swapState.value;
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Row(
                          children: [
                            Expanded(
                              child: PrimaryNomoButton(
                                text: switch (state) {
                                  SwapState.NeedsTokenApproval => 'Approve',
                                  SwapState.ApprovingToken => 'Approving',
                                  SwapState.Broadcasting ||
                                  SwapState.Confirming ||
                                  SwapState.WaitingForUserApproval =>
                                    'Swapping',
                                  SwapState.InsufficientLiquidity =>
                                    'Insufficient Liquidity',
                                  _ => 'Swap',
                                },
                                type: switch (state) {
                                  SwapState.Broadcasting ||
                                  SwapState.Confirming ||
                                  SwapState.WaitingForUserApproval ||
                                  SwapState.ApprovingToken =>
                                    ActionType.loading,
                                  SwapState.None ||
                                  SwapState.InsufficientLiquidity ||
                                  SwapState.Preview ||
                                  SwapState.InsufficientBalance =>
                                    ActionType.nonInteractive,
                                  _ => ActionType.def,
                                },
                                height: 64,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                borderRadius: BorderRadius.circular(16),
                                textStyle: context.typography.h1,
                                onPressed: () {
                                  if (state == SwapState.ReadyForSwap ||
                                      state == SwapState.NeedsTokenApproval ||
                                      state == SwapState.TokenApprovalError ||
                                      state == SwapState.Error) {
                                    swapProvider.swap();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  MediaQuery.of(context).viewInsets.bottom.vSpacing,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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

class SwapInputBottom extends StatelessWidget {
  final ERC20Entity? token;
  final ERC20Entity? otherToken;
  final bool showMax;
  final bool isFrom;

  const SwapInputBottom({
    super.key,
    required this.token,
    required this.isFrom,
    this.otherToken,
    this.showMax = true,
  });

  @override
  Widget build(BuildContext context) {
    final balanceNotifier = InheritedAssetProvider.of(context);
    final swapProvider = InheritedSwapProvider.of(context);

    final balanceListenable =
        token != null ? balanceNotifier.balanceNotifierForToken(token!) : null;
    final priceListenable =
        token != null ? balanceNotifier.priceNotifierForToken(token!) : null;

    final otherPriceListenable = otherToken != null
        ? balanceNotifier.priceNotifierForToken(otherToken!)
        : null;

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: switch ((balanceListenable, priceListenable)) {
        (
          ValueNotifier<AsyncValue<Amount>> balanceListenable,
          ValueNotifier<AsyncValue<PriceState>> priceListenable
        ) =>
          ListenableBuilder(
            listenable: Listenable.merge(
              [
                $addressNotifier,
                balanceListenable,
                priceListenable,
                swapProvider.swapInfo,
                if (isFrom) swapProvider.fromAmount else swapProvider.toAmount,
              ],
            ),
            builder: (context, child) {
              final hasAddress = $addressNotifier.value != null;
              final balanceAsync = balanceListenable.value;
              final priceAsync = priceListenable.value;
              final otherPriceAsync = otherPriceListenable?.value;
              final amount = isFrom
                  ? swapProvider.swapInfo.value?.fromAmount ??
                      swapProvider.fromAmount.value
                  : swapProvider.swapInfo.value?.toAmount ??
                      swapProvider.toAmount.value;

              final otherAmount = isFrom
                  ? swapProvider.swapInfo.value?.toAmount ??
                      swapProvider.toAmount.value
                  : swapProvider.swapInfo.value?.fromAmount ??
                      swapProvider.fromAmount.value;

              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    priceAsync.when(
                      data: (price) {
                        final priceAmount = switch (amount) {
                          Amount amount when amount.value > BigInt.zero =>
                            price.price * amount.displayDouble,
                          _ => null,
                        };
                        final priceAmountString = switch (amount) {
                          Amount amount when amount.value > BigInt.zero =>
                            "${price.currency.symbol}${(price.price * amount.displayDouble).toStringAsFixed(5)}",
                          _ => "${price.currency.symbol}0.00",
                        };
                        return Row(
                          children: [
                            NomoText(
                              priceAmountString,
                              style: context.typography.b1,
                              fontWeight: FontWeight.bold,
                              opacity: 0.8,
                            ),
                            if (otherPriceAsync != null)
                              otherPriceAsync.when(
                                data: (otherPrice) {
                                  if (swapProvider.swapInfo.value == null) {
                                    return SizedBox.shrink();
                                  }

                                  final otherPriceAmount =
                                      switch (otherAmount) {
                                    Amount amount
                                        when amount.value > BigInt.zero =>
                                      (otherPrice.price * amount.displayDouble),
                                    _ => null,
                                  };

                                  if (otherPriceAmount == null ||
                                      priceAmount == null ||
                                      otherAmount == null) {
                                    return SizedBox.shrink();
                                  }

                                  final priceDiff =
                                      (priceAmount - otherPriceAmount) /
                                          otherPriceAmount *
                                          100;

                                  if (priceDiff.abs() < 1) {
                                    return SizedBox.shrink();
                                  }

                                  final info =
                                      priceDiff.abs().formatPriceImpact();

                                  return NomoText(
                                    "  (${priceDiff > 0 ? '+' : '-'}${info.$1}%)",
                                    style: context.typography.b1,
                                    fontWeight: FontWeight.bold,
                                    color: priceDiff > 0
                                        ? Colors.greenAccent
                                        : context.colors.error,
                                  );
                                },
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
                                error: (error) => SizedBox.shrink(),
                              ),
                          ],
                        );
                      },
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
                      error: (error) {
                        return NomoText(
                          "No price available",
                          style: context.typography.b1,
                          color: context.colors.error,
                        );
                      },
                    ),
                    const Spacer(),
                    if (hasAddress)
                      balanceAsync.when(
                        data: (balance) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              NomoText(
                                "Balance: ",
                                style: context.typography.b1,
                                opacity: 0.6,
                              ),
                              NomoText(
                                balance.displayDouble.toStringAsFixed(2),
                                style: context.typography.b1,
                                opacity: 0.8,
                              ),
                              if (showMax && balance.displayDouble > 0) ...[
                                8.hSpacing,
                                NomoLinkButton(
                                  text: "Max",
                                  width: 48,
                                  height: 32,
                                  foregroundColor: context.colors.primary,
                                  selectionColor:
                                      context.colors.primary.lighten(),
                                  tapDownColor: context.colors.primary.darken(),
                                  padding: EdgeInsets.zero,
                                  textStyle: context.typography.b1,
                                  onPressed: () {
                                    swapProvider.fromAmountString.value =
                                        balance.displayValue;
                                  },
                                ),
                              ],
                              4.hSpacing,
                            ],
                          );
                        },
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
                        error: (error) => const Icon(Icons.error),
                      ),
                  ],
                ),
              );
            },
          ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

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
    final imageProvider = InheritedImageProvider.of(context);

    final image = imageProvider.imageNotifierForToken(token);

    return ValueListenableBuilder(
      valueListenable: image,
      builder: (context, image, child) {
        return image.when(
          data: (value) {
            return ClipOval(
              child: Image.network(
                value.small,
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

class TapIgnoreDragDetector extends StatefulWidget {
  final Widget child;

  final void Function() onTap;

  const TapIgnoreDragDetector({
    super.key,
    required this.child,
    required this.onTap,
  });

  @override
  State<TapIgnoreDragDetector> createState() => _TapIgnoreDragDetectorState();
}

class _TapIgnoreDragDetectorState extends State<TapIgnoreDragDetector> {
  bool hasScrollUpdate = false;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          hasScrollUpdate = true;
        }
        if (notification is ScrollEndNotification) {
          if (hasScrollUpdate == false) {
            widget.onTap();
          }
          hasScrollUpdate = false;
        }
        return true;
      },
      child: widget.child,
    );
  }
}
