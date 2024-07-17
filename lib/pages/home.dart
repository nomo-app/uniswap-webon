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
import 'package:nomo_ui_kit/components/notification/nomo_notification.dart';
import 'package:nomo_ui_kit/components/text/nomo_text.dart';
import 'package:nomo_ui_kit/theme/nomo_theme.dart';
import 'package:nomo_ui_kit/utils/layout_extensions.dart';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/common/async_value.dart';
import 'package:zeniq_swap_frontend/common/price_repository.dart';
import 'package:zeniq_swap_frontend/providers/asset_notifier.dart';
import 'package:zeniq_swap_frontend/providers/swap_provider.dart';
import 'package:zeniq_swap_frontend/routes.dart';
import 'package:zeniq_swap_frontend/widgets/select_asset_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late SwapProvider swapProvider;
  late AssetNotifier assetNotifer;

  late final ValueNotifier<String?> fromErrorNotifier = ValueNotifier(null);
  late final ValueNotifier<String?> toErrorNotifier = ValueNotifier(null);

  @override
  void didChangeDependencies() {
    swapProvider = InheritedSwapProvider.of(context);
    assetNotifer = InheritedAssetProvider.of(context);

    swapProvider.swapState.addListener(swapStateChanged);

    swapProvider.fromAmount.addListener(fromAmountChanged);
    swapProvider.toAmount.addListener(toAmountChanged);

    super.didChangeDependencies();
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

    final balance = assetNotifer.notifierForToken(toToken).value.valueOrNull;

    if (balance == null) return;

    fromErrorNotifier.value = null;

    if (toAmount.value > balance.value) {
      toErrorNotifier.value = "Insufficient balance";
    } else {
      toErrorNotifier.value = null;
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

    final balance = assetNotifer.notifierForToken(fromToken).value.valueOrNull;

    if (balance == null) return;

    toErrorNotifier.value = null;

    if (fromAmount.value > balance.value) {
      fromErrorNotifier.value = "Insufficient balance";
    } else {
      fromErrorNotifier.value = null;
    }
  }

  @override
  void dispose() {
    swapProvider.swapState.removeListener(swapStateChanged);
    super.dispose();
  }

  void swapStateChanged() {
    print("Swap State: ${swapProvider.swapState.value}");

    final swapState = swapProvider.swapState.value;

    /// User just completed the swap
    if (swapState == SwapState.Swapped) {
      assetNotifer.fetchAllBalances();
      assetNotifer.fetchAllPrices();
      InAppNotification.show(
        right: 16,
        top: 16,
        child: NomoNotification(
          title: "Swap Completed",
          subtitle: "Your swap has been completed successfully.",
          leading: Icon(
            Icons.check,
            color: context.colors.primary,
            size: 36,
          ),
          spacing: 8,
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
          spacing: 8,
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
          spacing: 8,
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
    return NomoRouteBody(
      backgroundColor: context.colors.background3,
      padding: const EdgeInsets.all(16),
      scrollable: true,
      maxContentWidth: 480,
      footer: ValueListenableBuilder(
        valueListenable: swapProvider.swapState,
        builder: (context, state, child) {
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
                      _ => 'Swap',
                    },
                    type: switch (state) {
                      SwapState.Broadcasting ||
                      SwapState.Confirming ||
                      SwapState.WaitingForUserApproval ||
                      SwapState.ApprovingToken =>
                        ActionType.loading,
                      SwapState.None => ActionType.nonInteractive,
                      _ => ActionType.def,
                    },
                    height: 64,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
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
      children: [
        NomoText(
          "Swap",
          style: context.typography.h1.copyWith(fontSize: 48),
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
                assetNotifer.fetchAllBalances();
                assetNotifer.fetchAllPrices();
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
        ValueListenableBuilder(
          valueListenable: swapProvider.fromToken,
          builder: (context, token, child) {
            return NomoInput(
              margin: const EdgeInsets.symmetric(vertical: 8),
              placeHolderStyle: context.typography.h1.copyWith(fontSize: 28),
              borderRadius: BorderRadius.circular(16),
              style: context.typography.h1.copyWith(fontSize: 28),
              border: const Border.fromBorderSide(
                BorderSide(color: Colors.white10),
              ),
              top: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    NomoText(
                      "From",
                      style: context.typography.b3,
                    ),
                  ],
                ),
              ),
              errorNotifier: fromErrorNotifier,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              placeHolder: '0',
              valueNotifier: swapProvider.fromAmountString,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
              bottom: SwapInputBottom(token: token),
              trailling: SwapInputTrailling(
                token: token,
                onTokenSelected: (token) {
                  swapProvider.setFromToken(token);
                },
              ),
            );
          },
        ),
        16.vSpacing,
        Center(
          child: SecondaryNomoButton(
            icon: Icons.swap_vert,
            height: 48,
            width: 48,
            shape: BoxShape.circle,
            foregroundColor: Colors.white.withOpacity(0.6),
            backgroundColor: Colors.transparent,
            onPressed: () {
              swapProvider.changePosition();
            },
          ),
        ),
        16.vSpacing,
        ValueListenableBuilder(
          valueListenable: swapProvider.toToken,
          builder: (context, token, child) {
            return NomoInput(
              top: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    NomoText(
                      "To",
                      style: context.typography.b3,
                    ),
                  ],
                ),
              ),
              style: context.typography.h1.copyWith(fontSize: 28),
              placeHolderStyle: context.typography.h1.copyWith(fontSize: 28),
              borderRadius: BorderRadius.circular(16),
              errorNotifier: toErrorNotifier,
              placeHolder: '0',
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              bottom: SwapInputBottom(
                token: token,
                showMax: false,
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
                      swapProvider.setToToken(token);
                    },
                  );
                },
              ),
            );
          },
        ),
        32.vSpacing,
        ValueListenableBuilder(
            valueListenable: swapProvider.swapInfo,
            builder: (context, swapInfo, child) {
              if (swapInfo == null) {
                return const SizedBox();
              }
              return NomoInfoItemThemeOverride(
                data: NomoInfoItemThemeDataNullable(
                  titleStyle:
                      context.typography.b2.copyWith(color: Colors.white60),
                  valueStyle: context.typography.b2,
                ),
                child: NomoCard(
                  elevation: 0,
                  padding: const EdgeInsets.all(16),
                  backgroundColor: context.colors.background2,
                  border: const Border.fromBorderSide(
                    BorderSide(color: Colors.white10),
                  ),
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    children: [
                      ...switch (swapInfo) {
                        FromSwapInfo info => [
                            NomoInfoItem(
                              title: "Price",
                              value: info.getPrice(),
                            ),
                            const NomoDivider(),
                            const NomoInfoItem(
                              title: "Slippage Tolerance",
                              value: "0.5%",
                            ),
                            const NomoDivider(),
                            const NomoInfoItem(
                              title: "Liquidity Provider Fee",
                              value: "0.3%",
                            ),
                            const NomoDivider(),
                            NomoInfoItem(
                              title: "Minimum Received",
                              value:
                                  "${info.amountOutMin.displayDouble.toStringAsFixed(5)} ${info.toToken.symbol}",
                            ),
                          ],
                        ToSwapInfo info => [
                            NomoInfoItem(
                              title: "Price",
                              value: info.getPrice(),
                            ),
                            const NomoDivider(),
                            const NomoInfoItem(
                              title: "Slippage Tolerance",
                              value: "0.5%",
                            ),
                            const NomoDivider(),
                            const NomoInfoItem(
                              title: "Liquidity Provider Fee",
                              value: "0.3%",
                            ),
                            const NomoDivider(),
                            NomoInfoItem(
                              title: "Maximum sold",
                              value:
                                  "${info.amountInMax.displayDouble.toStringAsFixed(5)} ${info.fromToken.symbol}",
                            ),
                          ]
                      }
                    ],
                  ),
                ),
              );
            }),
      ],
    );
  }
}

class SwapInputTrailling extends StatelessWidget {
  final TokenEntity? token;

  final void Function(TokenEntity token) onTokenSelected;

  const SwapInputTrailling({
    super.key,
    required this.token,
    required this.onTokenSelected,
  });

  void onPressed(BuildContext context) async {
    final result = await showDialog(
      context: context,
      builder: (c) => const SelectAssetDialog(),
    );

    if (result is TokenEntity) {
      onTokenSelected(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(
        milliseconds: 200,
      ),
      child: token == null
          ? PrimaryNomoButton(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              borderRadius: BorderRadius.circular(12),
              textStyle: context.typography.b2,
              onPressed: () => onPressed(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NomoText(
                    'Select Token',
                    style: context.typography.b2,
                    color: context.colors.onPrimary,
                  ),
                  4.hSpacing,
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            )
          : SecondaryNomoButton(
              backgroundColor: context.colors.background1,
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
                    token!.name,
                    style: context.typography.h1,
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
  final TokenEntity? token;
  final bool showMax;

  const SwapInputBottom({
    super.key,
    required this.token,
    this.showMax = true,
  });

  @override
  Widget build(BuildContext context) {
    final balanceNotifier = InheritedAssetProvider.of(context);
    final swapProvider = InheritedSwapProvider.of(context);
    final balanceListenable =
        token != null ? balanceNotifier.notifierForToken(token!) : null;
    final priceListenable =
        token != null ? balanceNotifier.priceNotifierForToken(token!) : null;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) {
        return SizeTransition(sizeFactor: animation, child: child);
      },
      child: switch ((balanceListenable, priceListenable)) {
        (
          ValueNotifier<AsyncValue<Amount>> balanceListenable,
          ValueNotifier<AsyncValue<PriceState>> priceListenable
        ) =>
          ListenableBuilder(
            listenable: Listenable.merge(
              [balanceListenable, priceListenable, swapProvider.fromAmount],
            ),
            builder: (context, child) {
              final balanceAsync = balanceListenable.value;
              final priceAsync = priceListenable.value;
              final fromAmount = swapProvider.fromAmount.value;
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    priceAsync.when(
                      data: (value) {
                        return NomoText(
                          switch (fromAmount) {
                            Amount amount when amount.value > BigInt.zero =>
                              "${value.currency.symbol}${(value.price * amount.displayDouble).toStringAsFixed(5)}",
                            _ => "${value.currency.symbol}0.00",
                          },
                          style: context.typography.b2,
                          fontWeight: FontWeight.bold,
                          opacity: 0.8,
                        );
                      },
                      loading: () => const CircularProgressIndicator(),
                      error: (error) => const Icon(Icons.error),
                    ),
                    const Spacer(),
                    balanceAsync.when(
                      data: (value) {
                        return Row(
                          children: [
                            NomoText(
                              value.displayDouble.toStringAsFixed(5),
                              style: context.typography.b2,
                              fontWeight: FontWeight.bold,
                              opacity: 0.8,
                            ),
                            if (showMax) ...[
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
                                textStyle: context.typography.b2,
                                onPressed: () {
                                  swapProvider.fromAmountString.value =
                                      value.displayValue;
                                },
                              ),
                            ],
                            4.hSpacing,
                          ],
                        );
                      },
                      loading: () => const CircularProgressIndicator(),
                      error: (error) => const Icon(Icons.error),
                    ),
                  ],
                ),
              );
            },
          ),
        _ => const SizedBox(),
      },
    );
  }
}

class AssetPicture extends StatelessWidget {
  final TokenEntity token;

  const AssetPicture({super.key, required this.token});

  @override
  Widget build(BuildContext context) {
    final assetNotifer = InheritedAssetProvider.of(context);

    final image = assetNotifer.imageNotifierForToken(token);

    if (image == null) {
      return const SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(),
      );
    }

    return ValueListenableBuilder(
      valueListenable: image,
      builder: (context, image, child) {
        return image.when(
          data: (value) {
            return ClipOval(
              child: Image.network(
                value.small,
                width: 24,
                height: 24,
              ),
            );
          },
          loading: () => const CircularProgressIndicator(),
          error: (error) => const Icon(Icons.error),
        );
      },
    );
  }
}
