import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:nomo_ui_kit/components/buttons/primary/nomo_primary_button.dart';
import 'package:nomo_ui_kit/components/card/nomo_card.dart';
import 'package:nomo_ui_kit/components/info_item/nomo_info_item.dart';
import 'package:nomo_ui_kit/components/text/nomo_text.dart';
import 'package:nomo_ui_kit/theme/nomo_theme.dart';
import 'package:nomo_ui_kit/utils/layout_extensions.dart';
import 'package:provider/provider.dart';
import 'package:zeniq_swap_frontend/common/async_value.dart';
import 'package:zeniq_swap_frontend/main.dart';
import 'package:zeniq_swap_frontend/pages/home_page.dart';
import 'package:zeniq_swap_frontend/providers/models/pair_info.dart';
import 'package:zeniq_swap_frontend/providers/price_provider.dart';
import 'package:zeniq_swap_frontend/widgets/asset_picture.dart';
import 'package:zeniq_swap_frontend/widgets/liquidity/pair_ratio_display.dart';

class PoolOverview extends StatefulWidget {
  final PairInfoEntity pairInfo;

  const PoolOverview({super.key, required this.pairInfo});

  @override
  State<PoolOverview> createState() => _PoolOverviewState();
}

class _PoolOverviewState extends State<PoolOverview> {
  late final ValueNotifier<bool> invertRatioNotifier = ValueNotifier(true);
  late PriceProvider assetNotifier;

  @override
  didChangeDependencies() {
    assetNotifier = context.read<PriceProvider>();
    super.didChangeDependencies();
  }

  PairInfoEntity get pairInfo => widget.pairInfo;

  OwnedPairInfo? get ownedPairInfo =>
      pairInfo is OwnedPairInfo ? pairInfo as OwnedPairInfo : null;

  @override
  Widget build(BuildContext context) {
    final price0Notifier = assetNotifier.priceNotifierForToken(pairInfo.token0);
    final price1Notifier = assetNotifier.priceNotifierForToken(pairInfo.token1);

    return NomoInfoItemThemeOverride(
      data: NomoInfoItemThemeDataNullable(
        titleStyle: context.typography.b1,
        valueStyle: context.typography.b1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                NomoText("Contract", style: context.typography.b2),
                8.hSpacing,
                NomoText(
                  shortenAddress(pairInfo.pair.contractAddress),
                  style: context.typography.b2,
                ),
                8.hSpacing,
                PrimaryNomoButton(
                  backgroundColor: Colors.transparent,
                  icon: Icons.copy,
                  padding: EdgeInsets.zero,
                  shape: BoxShape.circle,
                  height: 32,
                  width: 32,
                  iconSize: 18,
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: widget.pairInfo.pair.contractAddress),
                    );
                  },
                )
              ],
            ),
          ),
          24.vSpacing,
          NomoCard(
            backgroundColor: context.colors.background2.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            padding: EdgeInsets.all(24),
            child: PairRatioDisplay.fromPairInfo(pairInfo),
          ),
          24.vSpacing,
          ListenableBuilder(
            listenable: Listenable.merge([
              price0Notifier,
              price1Notifier,
            ]),
            builder: (context, child) {
              final price0Async = price0Notifier.value;
              final price1Async = price1Notifier.value;

              if (price0Async is AsyncLoading || price1Async is AsyncLoading) {
                return SizedBox.shrink();
              }
              if (price0Async is AsyncError || price1Async is AsyncError) {
                return NomoText("Error");
              }

              final price0 = price0Async.valueOrNull!
                  .getPriceForType(widget.pairInfo.type);
              final price1 = price1Async.valueOrNull!
                  .getPriceForType(widget.pairInfo.type);
              final currency = $currencyNotifier.value;

              return Column(
                children: [
                  NomoCard(
                    backgroundColor:
                        context.colors.background2.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    padding: EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        NomoText(
                          "Assets in Pool",
                          style: context.typography.b2,
                        ),
                        24.vSpacing,
                        Row(
                          children: [
                            AssetPicture(
                              token: widget.pairInfo.token0,
                              size: 24,
                            ),
                            12.hSpacing,
                            NomoText(
                              "${widget.pairInfo.amount0.displayDouble.toStringAsFixed(0)} ${widget.pairInfo.token0.symbol}",
                              style: context.typography.b2,
                            ),
                          ],
                        ),
                        16.vSpacing,
                        Row(
                          children: [
                            AssetPicture(
                              token: widget.pairInfo.token1,
                              size: 24,
                            ),
                            12.hSpacing,
                            NomoText(
                              "${widget.pairInfo.amount1.displayDouble.toStringAsFixed(0)} ${widget.pairInfo.token1.symbol}",
                              style: context.typography.b2,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  24.vSpacing,
                  NomoCard(
                    backgroundColor:
                        context.colors.background2.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    padding: EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            NomoText(
                              "Total Value Locked",
                              style: context.typography.b2,
                            ),
                            12.hSpacing,
                            NomoText(
                              "${currency.symbol}${widget.pairInfo.totalValueLocked(price0, price1).toStringAsFixed(0)}",
                              style: context.typography.b2,
                            ),
                          ],
                        ),
                        24.vSpacing,
                        Row(
                          children: [
                            AssetPicture(
                              token: widget.pairInfo.token0,
                              size: 24,
                            ),
                            12.hSpacing,
                            NomoText(
                              "${currency.symbol}${(widget.pairInfo.amount0.displayDouble * price0).toStringAsFixed(0)}",
                              style: context.typography.b2,
                            ),
                          ],
                        ),
                        16.vSpacing,
                        Row(
                          children: [
                            AssetPicture(
                              token: widget.pairInfo.token1,
                              size: 24,
                            ),
                            12.hSpacing,
                            NomoText(
                              "${currency.symbol}${(widget.pairInfo.amount1.displayDouble * price1).toStringAsFixed(0)}",
                              style: context.typography.b2,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (ownedPairInfo != null) ...[
                    24.vSpacing,
                    NomoCard(
                      backgroundColor:
                          context.colors.background2.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      padding: EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          NomoText(
                            "My Position",
                            style: context.typography.b2,
                          ),
                          24.vSpacing,
                          NomoInfoItem(
                            title: "My Pool Tokens",
                            value:
                                "${ownedPairInfo!.pairTokenAmountAmount.displayDouble.toStringAsFixed(3)}",
                          ),
                          24.vSpacing,
                          NomoInfoItem(
                            title: "My Pool Share",
                            value:
                                "${ownedPairInfo!.myPoolSharePercentage.toStringAsFixed(2)}%",
                          ),
                          24.vSpacing,
                          Row(
                            children: [
                              AssetPicture(
                                token: widget.pairInfo.token0,
                                size: 24,
                              ),
                              12.hSpacing,
                              NomoText(
                                "${(ownedPairInfo!.myAmount0.displayDouble).toStringAsFixed(5)}",
                                style: context.typography.b2,
                              ),
                            ],
                          ),
                          16.vSpacing,
                          Row(
                            children: [
                              AssetPicture(
                                token: widget.pairInfo.token1,
                                size: 24,
                              ),
                              12.hSpacing,
                              NomoText(
                                "${(ownedPairInfo!.myAmount1.displayDouble).toStringAsFixed(5)}",
                                style: context.typography.b2,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    24.vSpacing,
                    NomoCard(
                      backgroundColor:
                          context.colors.background2.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      padding: EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              NomoText(
                                "My Total Value Locked",
                                style: context.typography.b2,
                              ),
                              12.hSpacing,
                              NomoText(
                                "${currency.symbol}${ownedPairInfo!.myTotalValueLocked(price0, price1).toStringAsFixed(2)}",
                                style: context.typography.b2,
                              ),
                            ],
                          ),
                          24.vSpacing,
                          Row(
                            children: [
                              AssetPicture(
                                token: widget.pairInfo.token0,
                                size: 24,
                              ),
                              12.hSpacing,
                              NomoText(
                                "${currency.symbol}${(ownedPairInfo!.myAmount0.displayDouble * price0).toStringAsFixed(2)}",
                                style: context.typography.b2,
                              ),
                            ],
                          ),
                          16.vSpacing,
                          Row(
                            children: [
                              AssetPicture(
                                token: widget.pairInfo.token1,
                                size: 24,
                              ),
                              12.hSpacing,
                              NomoText(
                                "${currency.symbol}${(ownedPairInfo!.myAmount1.displayDouble * price1).toStringAsFixed(2)}",
                                style: context.typography.b2,
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
