import 'package:flutter/material.dart';
import 'package:nomo_ui_kit/app/notifications/app_notification.dart';
import 'package:nomo_ui_kit/components/buttons/primary/nomo_primary_button.dart';
import 'package:nomo_ui_kit/components/card/nomo_card.dart';
import 'package:nomo_ui_kit/components/divider/nomo_divider.dart';
import 'package:nomo_ui_kit/components/info_item/nomo_info_item.dart';
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
import 'package:zeniq_swap_frontend/providers/balance_provider.dart';
import 'package:zeniq_swap_frontend/providers/models/pair_info.dart';
import 'package:zeniq_swap_frontend/providers/pool_provider.dart';
import 'package:zeniq_swap_frontend/widgets/asset_picture.dart';
import 'package:zeniq_swap_frontend/widgets/liquidity/add/add_liquidity_input_bottom.dart';
import 'package:zeniq_swap_frontend/widgets/liquidity/pair_ratio_display.dart';
import 'package:zeniq_swap_frontend/common/extensions.dart';

class PoolAddLiquidity extends StatefulWidget {
  final ValueNotifier<PairInfoEntity> pairInfoNotifer;

  const PoolAddLiquidity({
    super.key,
    required this.pairInfoNotifer,
  });

  @override
  State<PoolAddLiquidity> createState() => _PoolAddLiquidityState();
}

class _PoolAddLiquidityState extends State<PoolAddLiquidity> {
  PairInfoEntity get pairInfo => widget.pairInfoNotifer.value;

  late final AddLiquidityProvider provider = AddLiquidityProvider(
    pairInfoNotifier: widget.pairInfoNotifer,
    balanceProvider: context.read<BalanceProvider>(),
    poolProvider: context.read<PoolProvider>(),
    addressNotifier: $addressNotifier,
    slippageNotifier: $slippageNotifier,
    needToBroadcast: $inNomo,
    signer: $inNomo ? WebonKitDart.signTransaction : metamaskSigner,
  );

  @override
  void initState() {
    provider.depositState.addListener(depositStateChanged);
    super.initState();
  }

  void depositStateChanged() {
    if (mounted == false) return;
    final depositState = provider.depositState.value;
    print("Deposit state changed: ${depositState}");

    /// User just completed the swap
    if (depositState == AddLiquidityState.deposited) {
      final depositInfo = provider.depositInfoNotifier.value;

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
    if (depositState == AddLiquidityState.confirming) {
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
    if (depositState == AddLiquidityState.error) {
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
    if (depositState == AddLiquidityState.tokenApprovalError) {
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
  void dispose() {
    provider.depositState.removeListener(depositStateChanged);
    provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NomoText(
          "Deposit",
          style: context.typography.b3,
        ),
        12.vSpacing,
        NomoText(
          "Deposit tokens to start earning trading fees",
          style: context.typography.b2,
        ),
        24.vSpacing,
        Column(
          children: [
            ValueListenableBuilder(
                valueListenable: provider.depositState,
                builder: (context, state, child) {
                  final enabled = state.buttonEnabled;
                  return NomoInput(
                    trailling: AssetPicture(
                      token: pairInfo.token0,
                      size: 36,
                    ),
                    enabled: enabled,
                    background: context.colors.background2.withOpacity(0.5),
                    valueNotifier: provider.token0InputNotifier,
                    errorNotifier: provider.token0ErrorNotifier,
                    padding: EdgeInsets.all(24),
                    placeHolder: "0",
                    style: context.typography.b3,
                    placeHolderStyle: context.typography.b3,
                    maxLines: 1,
                    bottom: AddLiqudityInputBottom(
                      token: pairInfo.token0,
                      amountNotifier: provider.token0AmountNotifier,
                    ),
                  );
                }),
            12.vSpacing,
            ValueListenableBuilder(
              valueListenable: provider.depositState,
              builder: (context, state, child) {
                final enabled = state.buttonEnabled;
                return NomoInput(
                  trailling: AssetPicture(
                    token: pairInfo.token1,
                    size: 36,
                  ),
                  enabled: enabled,
                  padding: EdgeInsets.all(24),
                  background: context.colors.background2.withOpacity(0.5),
                  valueNotifier: provider.token1InputNotifier,
                  errorNotifier: provider.token1ErrorNotifier,
                  placeHolder: "0",
                  style: context.typography.b3,
                  placeHolderStyle: context.typography.b3,
                  maxLines: 1,
                  bottom: AddLiqudityInputBottom(
                    token: pairInfo.token1,
                    amountNotifier: provider.token1AmountNotifier,
                  ),
                );
              },
            ),
            12.vSpacing,
            NomoDividerThemeOverride(
              data: NomoDividerThemeDataNullable(
                crossAxisSpacing: 12,
              ),
              child: NomoInfoItemThemeOverride(
                data: NomoInfoItemThemeDataNullable(
                  titleStyle: context.typography.b1,
                  valueStyle: context.typography.b1,
                ),
                child: NomoCard(
                  backgroundColor: context.colors.background2.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PairRatioDisplay.fromPairInfo(pairInfo),
                      ValueListenableBuilder(
                        valueListenable: provider.depositInfoNotifier,
                        builder: (context, depositInfo, child) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (depositInfo != null) ...[
                                NomoDivider(),
                                NomoInfoItem(
                                  title:
                                      "Minimum ${depositInfo.pairInfo.token0.symbol} provided",
                                  value:
                                      "${depositInfo.amount0Min.displayDouble.toStringAsFixed(2)} ${depositInfo.pairInfo.token0.symbol}",
                                ),
                                NomoDivider(),
                                NomoInfoItem(
                                  title:
                                      "Minimum ${depositInfo.pairInfo.token1.symbol} provided",
                                  value:
                                      "${depositInfo.amount1Min.displayDouble.toStringAsFixed(2)} ${depositInfo.pairInfo.token1.symbol}",
                                ),
                                NomoDivider(),
                                NomoInfoItem(
                                  title: "Pool Share",
                                  value:
                                      "${(depositInfo.poolShare.formatPriceImpact().$1)}%",
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            24.vSpacing,
            ValueListenableBuilder(
              valueListenable: provider.depositState,
              builder: (context, state, child) {
                return PrimaryNomoButton(
                  text: state.buttonText,
                  type: state.buttonType,
                  onPressed: provider.deposit,
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
      ],
    );
  }
}
