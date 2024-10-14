import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nomo_ui_kit/app/notifications/app_notification.dart';
import 'package:nomo_ui_kit/components/buttons/primary/nomo_primary_button.dart';
import 'package:nomo_ui_kit/components/card/nomo_card.dart';
import 'package:nomo_ui_kit/components/divider/nomo_divider.dart';
import 'package:nomo_ui_kit/components/expandable/expandable.dart';
import 'package:nomo_ui_kit/components/info_item/nomo_info_item.dart';
import 'package:nomo_ui_kit/components/input/textInput/nomo_input.dart';
import 'package:nomo_ui_kit/components/loading/loading.dart';
import 'package:nomo_ui_kit/components/notification/nomo_notification.dart';
import 'package:nomo_ui_kit/components/text/nomo_text.dart';
import 'package:nomo_ui_kit/theme/nomo_theme.dart';
import 'package:nomo_ui_kit/utils/layout_extensions.dart';
import 'package:provider/provider.dart';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/common/async_value.dart';
import 'package:zeniq_swap_frontend/common/extensions.dart';
import 'package:zeniq_swap_frontend/main.dart';
import 'package:zeniq_swap_frontend/providers/balance_provider.dart';
import 'package:zeniq_swap_frontend/providers/price_provider.dart';
import 'package:zeniq_swap_frontend/providers/swap_provider.dart';
import 'package:zeniq_swap_frontend/widgets/asset_picture.dart';
import 'package:zeniq_swap_frontend/widgets/liquidity/pair_ratio_display.dart';
import 'package:zeniq_swap_frontend/widgets/swap/swap_input_bottom.dart';
import 'package:zeniq_swap_frontend/widgets/swap/swap_input_trailling.dart';
import 'package:zeniq_swap_frontend/widgets/swap/token_price_display.dart';

class SwapWidget extends StatefulWidget {
  const SwapWidget({super.key});

  @override
  State<SwapWidget> createState() => _SwapWidgetState();
}

class _SwapWidgetState extends State<SwapWidget> {
  late SwapProvider swapProvider;
  late BalanceProvider balanceProvider;
  late PriceProvider priceProvider;

  late final ValueNotifier<String?> fromErrorNotifier = ValueNotifier(null);
  late final ValueNotifier<String?> toErrorNotifier = ValueNotifier(null);

  late final ValueNotifier<bool> inversePriceRateNotifer = ValueNotifier(false);

  late final FocusNode fromFocusNode = FocusNode();
  late final FocusNode toFocusNode = FocusNode();

  bool keyboardShown = false;

  @override
  void didChangeDependencies() {
    swapProvider = context.read<SwapProvider>();
    balanceProvider = context.read<BalanceProvider>();
    priceProvider = context.read<PriceProvider>();

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

    final balanceNotifier = balanceProvider.balanceNotifierForToken(toToken);
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

    final balanceNotifier = balanceProvider.balanceNotifierForToken(fromToken);
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

  void refresh() {
    final info = swapProvider.swapInfo.value;
    if (info == null) return;
    balanceProvider.refreshForToken(info.fromToken);
    balanceProvider.refreshForToken(info.toToken);
    priceProvider.refreshToken(info.fromToken);
    priceProvider.refreshToken(info.toToken);
  }

  void swapStateChanged() {
    if (mounted == false) return;
    print("Swap State: ${swapProvider.swapState.value}");

    final swapState = swapProvider.swapState.value;

    /// User just completed the swap
    if (swapState == SwapState.Swapped) {
      final swapInfo = swapProvider.swapInfo.value;
      refresh();
      InAppNotification.show(
        right: 16,
        top: 16,
        useRootNavigator: true,
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
      refresh();
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
    if (swapState == SwapState.Error) {
      InAppNotification.show(
        right: 16,
        top: 16,
        useRootNavigator: true,
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
    return Column(
      children: [
        Row(
          children: [
            const Spacer(),
            PrimaryNomoButton(
              backgroundColor: context.colors.background2.withOpacity(0.5),
              foregroundColor: context.colors.foreground1,
              border: const Border.fromBorderSide(
                BorderSide(color: Colors.white10),
              ),
              elevation: 0,
              height: 42,
              width: 42,
              iconSize: 18,
              borderRadius: BorderRadius.circular(16),
              icon: Icons.refresh_rounded,
              padding: EdgeInsets.zero,
              onPressed: () {
                swapProvider.checkSwapInfo();
                //   assetProvider.refresh();
              },
            ),
          ],
        ),
        16.vSpacing,
        Stack(
          children: [
            Column(
              children: [
                ListenableBuilder(
                  listenable: Listenable.merge([
                    swapProvider.fromToken,
                    swapProvider.swapState,
                  ]),
                  builder: (context, child) {
                    final token = swapProvider.fromToken.value;
                    final enabled = swapProvider.swapState.value.inputEnabled;
                    return NomoInput(
                      placeHolderStyle: context.typography.b3.copyWith(
                          color: context.colors.foreground3.withOpacity(0.6)),
                      borderRadius: BorderRadius.circular(16),
                      style: context.typography.b3.copyWith(
                        color: context.colors.foreground1,
                      ),
                      border: const Border.fromBorderSide(
                        BorderSide(color: Colors.white10),
                      ),
                      hitTestBehavior: HitTestBehavior.deferToChild,
                      top: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Row(
                          children: [
                            NomoText(
                              "From",
                              style: context.typography.b2,
                            ),
                            ValueListenableBuilder(
                              valueListenable: swapProvider.swapInfo,
                              builder: (context, swapInfo, child) {
                                final fromEstimated = swapInfo is ToSwapInfo;
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
                            if (token != null) TokenPriceDisplay(token: token),
                          ],
                        ),
                      ),
                      focusNode: fromFocusNode,
                      onTap: () {
                        if (fromFocusNode.hasFocus && !keyboardShown) {
                          fromFocusNode.unfocus();
                          Future.microtask(() => fromFocusNode.requestFocus());
                        }
                      },
                      background: context.colors.background2.withOpacity(0.5),
                      enabled: enabled,
                      errorNotifier: fromErrorNotifier,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      placeHolder: '0',
                      valueNotifier: swapProvider.fromAmountString,
                      padding: const EdgeInsets.all(24),
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
                12.vSpacing,
                ListenableBuilder(
                  listenable: Listenable.merge([
                    swapProvider.toToken,
                    swapProvider.swapState,
                  ]),
                  builder: (context, child) {
                    final token = swapProvider.toToken.value;
                    final enabled = swapProvider.swapState.value.inputEnabled;
                    return NomoInput(
                      top: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Row(
                          children: [
                            NomoText(
                              "To",
                              style: context.typography.b2,
                            ),
                            ValueListenableBuilder(
                              valueListenable: swapProvider.swapInfo,
                              builder: (context, swapInfo, child) {
                                final toEstimated = swapInfo is FromSwapInfo;
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
                            if (token != null) TokenPriceDisplay(token: token),
                          ],
                        ),
                      ),
                      hitTestBehavior: HitTestBehavior.deferToChild,
                      focusNode: toFocusNode,
                      onTap: () {
                        if (toFocusNode.hasFocus && !keyboardShown) {
                          toFocusNode.unfocus();
                          Future.microtask(() => toFocusNode.requestFocus());
                        }
                      },
                      enabled: enabled,
                      maxLines: 1,
                      scrollable: true,
                      style: context.typography.b3.copyWith(
                        color: context.colors.foreground1,
                      ),
                      placeHolderStyle: context.typography.b3.copyWith(
                          color: context.colors.foreground3.withOpacity(0.6)),
                      background: context.colors.background2.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      errorNotifier: toErrorNotifier,
                      placeHolder: '0',
                      padding: const EdgeInsets.all(24),
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
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
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
            ListenableBuilder(
              listenable: Listenable.merge(
                [swapProvider.fromToken, swapProvider.toToken],
              ),
              builder: (context, child) {
                final fromTokenVisible = swapProvider.fromToken.value != null;
                final toTokenVisible = swapProvider.toToken.value != null;
                return AnimatedPositioned(
                  top: switch (fromTokenVisible) {
                    true when toTokenVisible => 0,
                    true => 48 - 24,
                    _ => -48 + 24,
                  },
                  right: 0,
                  curve: Curves.easeInOut,
                  duration: const Duration(milliseconds: 200),
                  left: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.colors.background1,
                      ),
                      padding: EdgeInsets.all(2),
                      child: PrimaryNomoButton(
                        icon: Icons.swap_vert,
                        height: 42,
                        width: 42,
                        iconSize: 22,
                        shape: BoxShape.circle,
                        padding: EdgeInsets.zero,
                        elevation: 0,

                        //border: Border.fromBorderSide(BorderSide.none),
                        foregroundColor: context.colors.foreground3,
                        backgroundColor: context.colors.background3,
                        onPressed: () {
                          swapProvider.changePosition();
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        24.vSpacing,
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

                        final priceImpactStyle = context.typography.b1.copyWith(
                          color: priceImpactInfo.$2,
                        );

                        final additionalInfo = swapInfo.path.length > 2
                            ? [
                                const NomoDivider(),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      AssetPicture(
                                        token: swapInfo.fromToken,
                                      ),
                                      8.hSpacing,
                                      NomoText(swapInfo.fromToken.symbol),
                                      const Spacer(),
                                      Icon(
                                        Icons.arrow_forward,
                                        color: context.colors.foreground3,
                                      ),
                                      const Spacer(),
                                      const AssetPicture(
                                        token: zeniqTokenWrapper,
                                      ),
                                      8.hSpacing,
                                      NomoText(
                                        zeniqTokenWrapper.name,
                                      ),
                                      const Spacer(),
                                      Icon(
                                        Icons.arrow_forward,
                                        color: context.colors.foreground3,
                                      ),
                                      const Spacer(),
                                      AssetPicture(
                                        token: swapInfo.toToken,
                                      ),
                                      8.hSpacing,
                                      NomoText(
                                        swapInfo.toToken.symbol,
                                      ),
                                    ],
                                  ),
                                ),
                              ]
                            : null;

                        return Column(
                          children: [
                            NomoDividerThemeOverride(
                              data: NomoDividerThemeDataNullable(
                                crossAxisSpacing: 12,
                                color: Colors.white12,
                              ),
                              child: NomoInfoItemThemeOverride(
                                data: NomoInfoItemThemeDataNullable(
                                  titleStyle: context.typography.b1.copyWith(
                                      color: context.colors.foreground3),
                                  valueStyle: context.typography.b1,
                                ),
                                child: ExpandableThemeOverride(
                                  data: ExpandableThemeDataNullable(
                                    iconSize: 22,
                                    iconColor: context.colors.foreground3,
                                    childrenPadding: EdgeInsets.only(
                                      left: 20,
                                      right: 20,
                                      bottom: 20,
                                      top: 0,
                                    ),
                                    titlePadding: EdgeInsets.only(
                                      left: 20,
                                      right: 20,
                                      top: 12,
                                      bottom: 12,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: NomoCard(
                                    elevation: 0,
                                    // padding: const EdgeInsets.symmetric(
                                    //     horizontal: 20, vertical: 20),
                                    backgroundColor: context.colors.background2
                                        .withOpacity(0.5),
                                    border: const Border.fromBorderSide(
                                      BorderSide(color: Colors.white10),
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    child: switch (swapInfo) {
                                      FromSwapInfo info => Expandable(
                                          title: ValueListenableBuilder(
                                            valueListenable:
                                                inversePriceRateNotifer,
                                            builder: (context, inverse, _) {
                                              return PairRatioDisplay(
                                                token0: info.toToken,
                                                token1: info.fromToken,
                                                ratio0: info.rate,
                                                ratio1: 1 / info.rate,
                                              );
                                            },
                                          ),
                                          children: [
                                            NomoDivider(
                                              crossAxisSpacing: 1,
                                            ),
                                            11.vSpacing,
                                            NomoInfoItem(
                                              title: "Slippage Tolerance",
                                              value: "${info.slippage}%",
                                            ),
                                            const NomoDivider(),
                                            NomoInfoItem(
                                              title: "Price Impact",
                                              value: "${priceImpactInfo.$1}%",
                                              valueStyle: priceImpactStyle,
                                            ),
                                            const NomoDivider(),
                                            NomoInfoItem(
                                              title: "Fee",
                                              value:
                                                  "${info.fee.displayDouble.toMaxPrecisionWithoutScientificNotation(5)} ${info.fromToken.symbol}",
                                            ),
                                            const NomoDivider(),
                                            NomoInfoItem(
                                              title: "Minimum Received",
                                              value:
                                                  "${info.amountOutMin.displayDouble.toMaxPrecisionWithoutScientificNotation(5)} ${info.toToken.symbol}",
                                            ),
                                            ...?additionalInfo,
                                          ],
                                        ),
                                      ToSwapInfo info => Expandable(
                                          title: ValueListenableBuilder(
                                            valueListenable:
                                                inversePriceRateNotifer,
                                            builder: (context, inverse, _) {
                                              return PairRatioDisplay(
                                                token0: info.fromToken,
                                                token1: info.toToken,
                                                ratio0: info.rate,
                                                ratio1: 1 / info.rate,
                                              );
                                            },
                                          ),
                                          children: [
                                            NomoDivider(
                                              crossAxisSpacing: 1,
                                            ),
                                            11.vSpacing,
                                            NomoInfoItem(
                                              title: "Slippage Tolerance",
                                              value: "${info.slippage}%",
                                            ),
                                            const NomoDivider(),
                                            NomoInfoItem(
                                              title: "Price Impact",
                                              value: "${priceImpactInfo.$1}%",
                                              valueStyle: priceImpactStyle,
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
                                            ...?additionalInfo,
                                          ],
                                        )
                                    },
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
            final priceImpact = swapProvider.swapInfo.value?.priceImpact;

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
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      borderRadius: BorderRadius.circular(16),
                      elevation: 0,
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
      ],
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
