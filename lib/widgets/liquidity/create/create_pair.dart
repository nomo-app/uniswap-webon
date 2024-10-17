import 'package:flutter/material.dart';
import 'package:nomo_router/router/nomo_navigator.dart';
import 'package:nomo_ui_kit/app/notifications/app_notification.dart';
import 'package:nomo_ui_kit/components/app/routebody/nomo_route_body.dart';
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
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:webon_kit_dart/webon_kit_dart.dart';
import 'package:zeniq_swap_frontend/common/extensions.dart';
import 'package:zeniq_swap_frontend/main.dart';
import 'package:zeniq_swap_frontend/providers/add_liquidity_provider.dart';
import 'package:zeniq_swap_frontend/providers/balance_provider.dart';
import 'package:zeniq_swap_frontend/providers/create_pair_provider.dart';
import 'package:zeniq_swap_frontend/providers/models/token_entity.dart';
import 'package:zeniq_swap_frontend/providers/pool_provider.dart';
import 'package:zeniq_swap_frontend/providers/price_provider.dart';
import 'package:zeniq_swap_frontend/providers/swap_provider.dart';
import 'package:zeniq_swap_frontend/routes.dart';
import 'package:zeniq_swap_frontend/widgets/asset_picture.dart';
import 'package:zeniq_swap_frontend/widgets/liquidity/add/add_liquidity_input_bottom.dart';
import 'package:zeniq_swap_frontend/widgets/liquidity/pair_ratio_display.dart';

class CreatePairPage extends StatefulWidget {
  final TokenEntity? token;

  const CreatePairPage({
    super.key,
    this.token,
  });

  @override
  State<CreatePairPage> createState() => _CreatePairPageState();
}

class _CreatePairPageState extends State<CreatePairPage> {
  late CreatePairProvider provider;

  ERC20Entity get token0 => zeniqTokenWrapper;
  ERC20Entity get token1 => widget.token!;

  @override
  void didChangeDependencies() {
    if (widget.token == null) {
      Future.microtask(
        () {
          NomoNavigator.fromKey.replace(PoolsPageRoute());
        },
      );
      return;
    }
    provider = CreatePairProvider(
      token0: token0,
      token1: token1,
      priceProvider: context.read<PriceProvider>(),
      assetNotifier: context.read<BalanceProvider>(),
      poolProvider: context.read<PoolProvider>(),
      addressNotifier: $addressNotifier,
      slippageNotifier: $slippageNotifier,
      needToBroadcast: $inNomo,
      signer: $inNomo ? WebonKitDart.signTransaction : metamaskSigner,
    );
    provider.createState.addListener(depositStateChanged);
    super.didChangeDependencies();
  }

  void depositStateChanged() {
    if (mounted == false) return;
    final createState = provider.createState.value;
    print("Deposit state changed: ${createState}");

    /// User just completed the swap
    if (createState == AddLiquidityState.deposited) {
      final depositInfo = provider.createInfoNotifier
          .value; // TODO: This needs to be more precise and only refresh the tokens that are affected

      //  widget.assetNotifier.refresh();
      InAppNotification.show(
        right: 16,
        top: 16,
        useRootNavigator: true,
        child: NomoNotification(
          title: "Pair created added",
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

      NomoNavigator.fromKey.pop();

      return;
    }

    /// User just completed the swap
    if (createState == AddLiquidityState.confirming) {
      // widget.assetNotifier
      //     .refresh(); // TODO: This needs to be more precise and only refresh the tokens that are affected
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
    if (createState == AddLiquidityState.error) {
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
    if (createState == AddLiquidityState.tokenApprovalError) {
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
    if (widget.token == null) {
      return const SizedBox();
    }
    return NomoRouteBody(
      maxContentWidth: 1000,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NomoText(
            "Create",
            style: context.typography.b3,
          ),
          12.vSpacing,
          NomoText(
            "Create a Pool and provide tokens to start earning trading fees",
            style: context.typography.b2,
          ),
          24.vSpacing,
          Column(
            children: [
              ValueListenableBuilder(
                  valueListenable: provider.createState,
                  builder: (context, state, child) {
                    final enabled = state.buttonEnabled;
                    return NomoInput(
                      trailling: AssetPicture(
                        token: token0,
                        size: 36,
                      ),
                      enabled: enabled,
                      background: context.colors.background2.withOpacity(0.5),
                      valueNotifier: provider.token0InputNotifier,
                      errorNotifier: provider.token0ErrorNotifier,
                      placeHolder: "0",
                      style: context.typography.b3,
                      placeHolderStyle: context.typography.b3,
                      maxLines: 1,
                      bottom: AddLiqudityInputBottom(
                        token: token0,
                        amountNotifier: provider.token0AmountNotifier,
                      ),
                    );
                  }),
              12.vSpacing,
              ValueListenableBuilder(
                valueListenable: provider.createState,
                builder: (context, state, child) {
                  final enabled = state.buttonEnabled;
                  return NomoInput(
                    trailling: AssetPicture(
                      token: token1,
                      size: 36,
                    ),
                    enabled: enabled,
                    background: context.colors.background2.withOpacity(0.5),
                    valueNotifier: provider.token1InputNotifier,
                    errorNotifier: provider.token1ErrorNotifier,
                    placeHolder: "0",
                    style: context.typography.b3,
                    placeHolderStyle: context.typography.b3,
                    maxLines: 1,
                    bottom: AddLiqudityInputBottom(
                      token: token1,
                      amountNotifier: provider.token1AmountNotifier,
                    ),
                  );
                },
              ),
              12.vSpacing,
              NomoDividerThemeOverride(
                data: NomoDividerThemeDataNullable(
                  crossAxisSpacing: 16,
                ),
                child: NomoInfoItemThemeOverride(
                  data: NomoInfoItemThemeDataNullable(
                    titleStyle: context.typography.b2,
                    valueStyle: context.typography.b2,
                  ),
                  child: ValueListenableBuilder(
                    valueListenable: provider.createInfoNotifier,
                    builder: (context, createInfo, child) {
                      if (createInfo == null) {
                        return const SizedBox();
                      }
                      return NomoCard(
                        backgroundColor:
                            context.colors.background2.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                        padding: EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                NomoText(
                                  "Ratio",
                                  style: context.typography.b2,
                                ),
                                Spacer(),
                                PairRatioDisplay(
                                  token0: createInfo.token0,
                                  token1: createInfo.token1,
                                  ratio0: createInfo.ratio0,
                                  ratio1: createInfo.ratio1,
                                ),
                              ],
                            ),
                            NomoDivider(),
                            NomoInfoItem(
                              title:
                                  "Minimum ${createInfo.token0.symbol} provided",
                              value:
                                  "${createInfo.amount0Min.displayDouble.toStringAsFixed(2)} ${createInfo.token0.symbol}",
                            ),
                            NomoDivider(),
                            NomoInfoItem(
                              title:
                                  "Minimum ${createInfo.token1.symbol} provided",
                              value:
                                  "${createInfo.amount1Min.displayDouble.toStringAsFixed(2)} ${createInfo.token1.symbol}",
                            ),
                            NomoDivider(),
                            NomoInfoItem(
                              title: "Pool Share",
                              value:
                                  "${(createInfo.poolShare.formatPriceImpact().$1)}%",
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              24.vSpacing,
              ValueListenableBuilder(
                valueListenable: provider.createState,
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
      ),
    );
  }
}
