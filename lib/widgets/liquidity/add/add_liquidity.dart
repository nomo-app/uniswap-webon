import 'package:flutter/widgets.dart';
import 'package:nomo_ui_kit/components/buttons/primary/nomo_primary_button.dart';
import 'package:nomo_ui_kit/components/card/nomo_card.dart';
import 'package:nomo_ui_kit/components/divider/nomo_divider.dart';
import 'package:nomo_ui_kit/components/info_item/nomo_info_item.dart';
import 'package:nomo_ui_kit/components/input/textInput/nomo_input.dart';
import 'package:nomo_ui_kit/components/text/nomo_text.dart';
import 'package:nomo_ui_kit/theme/nomo_theme.dart';
import 'package:nomo_ui_kit/utils/layout_extensions.dart';
import 'package:zeniq_swap_frontend/providers/add_liquidity_provider.dart';
import 'package:zeniq_swap_frontend/providers/pool_provider.dart';
import 'package:zeniq_swap_frontend/widgets/asset_picture.dart';
import 'package:zeniq_swap_frontend/widgets/liquidity/add/add_liquidity_input_bottom.dart';
import 'package:zeniq_swap_frontend/widgets/liquidity/pair_ratio_display.dart';
import 'package:zeniq_swap_frontend/common/extensions.dart';

class PoolAddLiquidity extends StatefulWidget {
  final PairInfo pairInfo;

  const PoolAddLiquidity({super.key, required this.pairInfo});

  @override
  State<PoolAddLiquidity> createState() => _PoolAddLiquidityState();
}

class _PoolAddLiquidityState extends State<PoolAddLiquidity> {
  late final AddLiquidityProvider provider = AddLiquidityProvider(
    pairInfo: widget.pairInfo,
  );

  @override
  void dispose() {
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
            NomoInput(
              trailling: AssetPicture(
                token: widget.pairInfo.token0,
                size: 36,
              ),
              background: context.colors.background2.withOpacity(0.5),
              valueNotifier: provider.token0InputNotifier,
              placeHolder: "0",
              style: context.typography.b3,
              placeHolderStyle: context.typography.b3,
              maxLines: 1,
              bottom: AddLiqudityInputBottom(
                token: widget.pairInfo.token0,
                amountNotifier: provider.token0AmountNotifier,
              ),
            ),
            12.vSpacing,
            NomoInput(
              trailling: AssetPicture(
                token: widget.pairInfo.token1,
                size: 36,
              ),
              background: context.colors.background2.withOpacity(0.5),
              valueNotifier: provider.token1InputNotifier,
              placeHolder: "0",
              style: context.typography.b3,
              placeHolderStyle: context.typography.b3,
              maxLines: 1,
              bottom: AddLiqudityInputBottom(
                token: widget.pairInfo.token1,
                amountNotifier: provider.token1AmountNotifier,
              ),
            ),
            12.vSpacing,
            NomoCard(
              backgroundColor: context.colors.background2.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      NomoText(
                        "Ratio",
                        style: context.typography.b2,
                      ),
                      Spacer(),
                      PairRatioDisplay(pairInfo: widget.pairInfo),
                    ],
                  ),
                  NomoDivider(
                    crossAxisSpacing: 16,
                  ),
                  ValueListenableBuilder(
                    valueListenable: provider.poolShareNotifier,
                    builder: (context, poolShare, child) {
                      return NomoInfoItem(
                        title: "Pool Share",
                        value: "${(poolShare?.formatPriceImpact().$1 ?? 0)}%",
                        titleStyle: context.typography.b2,
                        valueStyle: context.typography.b2,
                      );
                    },
                  ),
                ],
              ),
            ),
            24.vSpacing,
            PrimaryNomoButton(
              text: "Deposit",
              onPressed: () {},
              expandToConstraints: true,
              height: 48,
            ),
          ],
        ),
      ],
    );
  }
}
