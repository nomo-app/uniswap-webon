import 'package:flutter/material.dart';
import 'package:nomo_router/nomo_router.dart';
import 'package:nomo_ui_kit/components/app/routebody/nomo_route_body.dart';
import 'package:nomo_ui_kit/components/buttons/primary/nomo_primary_button.dart';
import 'package:nomo_ui_kit/components/buttons/secondary/nomo_secondary_button.dart';
import 'package:nomo_ui_kit/components/card/nomo_card.dart';
import 'package:nomo_ui_kit/components/input/textInput/nomo_input.dart';
import 'package:nomo_ui_kit/components/loading/loading.dart';
import 'package:nomo_ui_kit/components/outline_container/nomo_outline_container.dart';
import 'package:nomo_ui_kit/components/text/nomo_text.dart';
import 'package:nomo_ui_kit/utils/layout_extensions.dart';
import 'package:provider/provider.dart';
import 'package:zeniq_swap_frontend/common/async_value.dart';
import 'package:zeniq_swap_frontend/providers/models/pair_info.dart';
import 'package:zeniq_swap_frontend/providers/pool_provider.dart';
import 'package:zeniq_swap_frontend/providers/price_provider.dart';
import 'package:zeniq_swap_frontend/routes.dart';
import 'package:zeniq_swap_frontend/widgets/asset_picture.dart';
import 'package:nomo_ui_kit/theme/nomo_theme.dart';

class PoolsPage extends StatefulWidget {
  const PoolsPage({super.key});

  @override
  State<PoolsPage> createState() => _PoolsPageState();
}

class _PoolsPageState extends State<PoolsPage>
    with SingleTickerProviderStateMixin {
  late PoolProvider poolProvider;
  late final ValueNotifier<bool> showMyPoolsNotifier;

  @override
  void initState() {
    showMyPoolsNotifier = ValueNotifier(true);

    super.initState();
  }

  @override
  void didChangeDependencies() {
    poolProvider = context.read<PoolProvider>();
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    final header = Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          ValueListenableBuilder(
            valueListenable: showMyPoolsNotifier,
            builder: (context, showMyPools, child) {
              return SizedBox(
                height: 48,
                child: Row(
                  children: [
                    SecondaryNomoButton(
                      height: 48,
                      width: 128,
                      text: "My Pools",
                      backgroundColor: Colors.transparent,
                      foregroundColor: showMyPools
                          ? context.colors.primary
                          : context.colors.disabled,
                      onPressed: () {
                        showMyPoolsNotifier.value = true;
                      },
                    ),
                    12.hSpacing,
                    SecondaryNomoButton(
                      height: 48,
                      width: 128,
                      text: "All Pools",
                      backgroundColor: Colors.transparent,
                      foregroundColor: showMyPools
                          ? context.colors.disabled
                          : context.colors.primary,
                      onPressed: () {
                        showMyPoolsNotifier.value = false;
                      },
                    ),
                    Spacer(),
                    PrimaryNomoButton(
                      text: "Create Pool",
                      height: 48,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ],
                ),
              );
            },
          ),
          32.vSpacing,
          NomoInput(
            placeHolder: "Search",
          ),
          32.vSpacing,
          SizedBox(
            height: 48,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                NomoText(
                  "Pool",
                  style: context.typography.b2,
                ),
                Spacer(),
                NomoText(
                  "Type",
                  style: context.typography.b2,
                ),
                64.hSpacing,
                SizedBox(
                  width: 128,
                  child: NomoText(
                    "Liquidity",
                    style: context.typography.b2,
                  ),
                ),
                64.hSpacing,
                42.hSpacing,
              ],
            ),
          ),
        ],
      ),
    );

    return NomoRouteBody(
      maxContentWidth: 1000,
      child: ValueListenableBuilder(
        valueListenable: showMyPoolsNotifier,
        builder: (context, showMyPools, child) {
          return ValueListenableBuilder(
            valueListenable: poolProvider.allPairsNotifier,
            builder: (context, pairsAsync, child) {
              return pairsAsync.when(
                loading: () => Center(child: Loading()),
                data: (allPairs) {
                  final pairs = switch (showMyPools) {
                    true => allPairs.whereType<OwnedPairInfo>().toList(),
                    _ => allPairs,
                  };
                  return ListView.separated(
                    itemBuilder: (context, index) => switch (index) {
                      0 => header,
                      _ => PairItem(
                          pair: pairs[index - 1],
                        ),
                    },
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemCount: pairs.length + 1,
                  );
                },
                error: (error) => NomoText(error.toString()),
              );
            },
          );
        },
      ),
    );
  }
}

class PairItem extends StatelessWidget {
  final PairInfoEntity pair;

  const PairItem({
    super.key,
    required this.pair,
  });

  @override
  Widget build(BuildContext context) {
    final priceProvider = context.watch<PriceProvider>();

    final token0PriceNotifier =
        priceProvider.priceNotifierForToken(pair.token0);
    final token1PriceNotifier =
        priceProvider.priceNotifierForToken(pair.token1);

    return SizedBox(
      height: 64,
      child: NomoCard(
        backgroundColor: context.colors.background2.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Container(
              height: 48,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white54,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  8.hSpacing,
                  AssetPicture(
                    token: pair.token0,
                    size: 32,
                  ),
                  8.hSpacing,
                  NomoText(pair.token0.symbol),
                  12.hSpacing,
                ],
              ),
            ),
            12.hSpacing,
            Container(
              height: 48,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white54,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  8.hSpacing,
                  AssetPicture(
                    token: pair.token1,
                    size: 32,
                  ),
                  8.hSpacing,
                  NomoText(pair.token1.symbol),
                  12.hSpacing,
                ],
              ),
            ),
            if (pair.type == PairType.legacy)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: NomoOutlineContainer(
                  padding: EdgeInsets.all(8),
                  background: context.colors.error,
                  radius: 16,
                  child: NomoText("Legacy"),
                ),
              ),
            Spacer(),
            //  NomoText(pair.type ? "Open" : "Closed"),
            64.hSpacing,
            SizedBox(
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  token0PriceNotifier,
                  token1PriceNotifier,
                ]),
                builder: (context, child) {
                  final token0PriceAsync = token0PriceNotifier.value;
                  final token1PriceAsync = token1PriceNotifier.value;
                  final isError = token0PriceAsync is AsyncError ||
                      token1PriceAsync is AsyncError;

                  if (isError) {
                    // print(token0PriceAsync.errorOrNull);
                    // print(token1PriceAsync.errorOrNull);
                    return NomoText('Error');
                  }
                  final isLoading = token0PriceAsync is AsyncLoading ||
                      token1PriceAsync is AsyncLoading;

                  if (isLoading) {
                    return Loading();
                  }

                  final token0Price =
                      token0PriceAsync.valueOrNull!.getPriceForType(pair.type);
                  final token1Price =
                      token1PriceAsync.valueOrNull!.getPriceForType(pair.type);
                  final currency = token1PriceAsync.valueOrNull!.currency;
                  final tvl = pair.totalValueLocked(token0Price, token1Price);

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      NomoText(
                        "${currency.symbol}${tvl.toStringAsFixed(2)}",
                        style: context.typography.b1,
                      ),
                      if (pair is OwnedPairInfo)
                        NomoText(
                          "Your Liquidity: ${currency.symbol}${(pair as OwnedPairInfo).myTotalValueLocked(token0Price, token1Price).toStringAsFixed(2)}",
                          style: context.typography.b1,
                        ),
                    ],
                  );
                },
              ),
            ),
            64.hSpacing,
            SecondaryNomoButton(
              backgroundColor: Colors.transparent,
              height: 42,
              width: 42,
              iconSize: 22,
              icon: Icons.arrow_forward_ios,
              onPressed: () {
                NomoNavigator.fromKey.push(PoolDetailPageRoute(
                  address: pair.pair.contractAddress,
                ));
              },
            )
          ],
        ),
      ),
    );
  }
}
