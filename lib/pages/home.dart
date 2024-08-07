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
import 'package:zeniq_swap_frontend/pages/background.dart';
import 'package:zeniq_swap_frontend/providers/asset_notifier.dart';
import 'package:zeniq_swap_frontend/providers/swap_provider.dart';
import 'package:zeniq_swap_frontend/widgets/select_asset_dialog.dart';
import 'package:zeniq_swap_frontend/widgets/settings_dialog.dart';

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
      final swapInfo = swapProvider.swapInfo.value;
      print(swapInfo);
      assetNotifer.fetchAllBalances();
      assetNotifer.fetchAllPrices();
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
          spacing: 12,
          showCloseButton: false,
        ),
        context: context,
      );
      return;
    }

    /// User just completed the swap
    if (swapState == SwapState.Confirming) {
      assetNotifer.fetchAllBalances();
      assetNotifer.fetchAllPrices();
      InAppNotification.show(
        right: 16,
        top: 16,
        child: const NomoNotification(
          title: "Transaction Pending",
          subtitle: "Waiting for transaction confirmation",
          leading: Loading(
            size: 20,
          ),
          spacing: 12,
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
          spacing: 12,
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
          spacing: 12,
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
        //  backgroundColor: context.colors.background3,
        background: const AppBackground(),
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
                  NomoNavigator.of(context).showModal(
                    context: context,
                    builder: (context) => const SettingsDialog(),
                  );
                },
              ),
            ],
          ),
          16.vSpacing,
          ListenableBuilder(
            listenable: Listenable.merge([
              swapProvider.fromToken,
              swapProvider.swapState,
            ]),
            builder: (context, child) {
              final token = swapProvider.fromToken.value;
              final enabled = switch (swapProvider.swapState.value) {
                SwapState.None ||
                SwapState.ReadyForSwap ||
                SwapState.Error ||
                SwapState.TokenApprovalError ||
                SwapState.NeedsTokenApproval =>
                  true,
                _ => false,
              };
              return NomoInput(
                margin: const EdgeInsets.symmetric(vertical: 8),
                placeHolderStyle: context.typography.b3,
                borderRadius: BorderRadius.circular(16),
                style: context.typography.b3,
                border: const Border.fromBorderSide(
                  BorderSide(color: Colors.white10),
                ),
                top: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      NomoText(
                        "From",
                        style: context.typography.b2,
                      ),
                    ],
                  ),
                ),
                background: context.colors.background2.withOpacity(0.5),
                enabled: enabled,
                errorNotifier: fromErrorNotifier,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                placeHolder: '0',
                valueNotifier: swapProvider.fromAmountString,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
            child: PrimaryNomoButton(
              icon: Icons.swap_vert,
              height: 48,
              width: 48,
              shape: BoxShape.circle,
              padding: EdgeInsets.zero,
              foregroundColor: Colors.white,
              backgroundColor: context.colors.background2.withOpacity(0.5),
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
              final enabled = switch (swapProvider.swapState.value) {
                SwapState.None ||
                SwapState.ReadyForSwap ||
                SwapState.Error ||
                SwapState.TokenApprovalError =>
                  true,
                _ => false,
              };
              return NomoInput(
                top: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      NomoText(
                        "To",
                        style: context.typography.b2,
                      ),
                    ],
                  ),
                ),
                enabled: enabled,
                maxLines: 1,
                scrollable: true,
                style: context.typography.b3,
                placeHolderStyle: context.typography.b3,
                background: context.colors.background2.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
                errorNotifier: toErrorNotifier,
                placeHolder: '0',
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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

              final priceImpactInfo = swapInfo.priceImpact.formatPriceImpact();

              final priceImpactStyle = context.typography.b1.copyWith(
                color: priceImpactInfo.$2,
              );

              return Column(
                children: [
                  NomoDividerThemeOverride(
                    data: const NomoDividerThemeDataNullable(
                      crossAxisSpacing: 12,
                    ),
                    child: NomoInfoItemThemeOverride(
                      data: NomoInfoItemThemeDataNullable(
                        titleStyle: context.typography.b1
                            .copyWith(color: Colors.white60),
                        valueStyle: context.typography.b1,
                      ),
                      child: NomoCard(
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 24),
                        backgroundColor:
                            context.colors.background2.withOpacity(0.5),
                        border: const Border.fromBorderSide(
                          BorderSide(color: Colors.white10),
                        ),
                        borderRadius: BorderRadius.circular(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...switch (swapInfo) {
                              FromSwapInfo info => [
                                  NomoInfoItem(
                                    title: "Price",
                                    value: info.getPrice(),
                                  ),
                                  const NomoDivider(),
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
                                ],
                              ToSwapInfo info => [
                                  NomoInfoItem(
                                    title: "Price",
                                    value: info.getPrice(),
                                  ),
                                  const NomoDivider(),
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
                                ]
                            },
                            if (swapInfo.path.length > 2) ...[
                              const NomoDivider(),
                              4.vSpacing,
                              NomoText(
                                "Route",
                                style: context.typography.b2
                                    .copyWith(color: Colors.white60),
                              ),
                              12.vSpacing,
                              NomoCard(
                                elevation: 0,
                                padding: const EdgeInsets.all(16),
                                borderRadius: BorderRadius.circular(12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    AssetPicture(
                                      token: swapInfo.fromToken,
                                    ),
                                    8.hSpacing,
                                    NomoText(swapInfo.fromToken.name),
                                    const Spacer(),
                                    const Icon(
                                      Icons.arrow_forward,
                                      color: Colors.white60,
                                    ),
                                    const Spacer(),
                                    const AssetPicture(
                                      token: zeniqSmart,
                                    ),
                                    8.hSpacing,
                                    NomoText(zeniqSmart.name),
                                    const Spacer(),
                                    const Icon(
                                      Icons.arrow_forward,
                                      color: Colors.white60,
                                    ),
                                    const Spacer(),
                                    AssetPicture(
                                      token: swapInfo.toToken,
                                    ),
                                    8.hSpacing,
                                    NomoText(swapInfo.toToken.name),
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
            },
          ),
        ],
      ),
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
    final result = await NomoNavigator.of(context).showModal(
      context: context,
      builder: (context) => const SelectAssetDialog(),
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
                          style: context.typography.b1,
                          fontWeight: FontWeight.bold,
                          opacity: 0.8,
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
                    balanceAsync.when(
                      data: (value) {
                        return Row(
                          children: [
                            NomoText(
                              value.displayDouble.toStringAsFixed(5),
                              style: context.typography.b1,
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
                                textStyle: context.typography.b1,
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
        _ => const SizedBox(),
      },
    );
  }
}

class AssetPicture extends StatelessWidget {
  final TokenEntity token;
  final double size;

  const AssetPicture({
    super.key,
    required this.token,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    final assetNotifer = InheritedAssetProvider.of(context);

    final image = assetNotifer.imageNotifierForToken(token);

    if (image == null) {
      return ShimmerLoading(
        isLoading: true,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.colors.background2,
          ),
        ),
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
          error: (error) => const Icon(Icons.error),
        );
      },
    );
  }
}
