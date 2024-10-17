import 'package:flutter/material.dart';
import 'package:nomo_router/nomo_router.dart';
import 'package:nomo_ui_kit/components/app/routebody/nomo_route_body.dart';
import 'package:nomo_ui_kit/components/buttons/primary/nomo_primary_button.dart';
import 'package:nomo_ui_kit/components/buttons/secondary/nomo_secondary_button.dart';
import 'package:nomo_ui_kit/components/buttons/text/nomo_text_button.dart';
import 'package:nomo_ui_kit/components/card/nomo_card.dart';
import 'package:nomo_ui_kit/components/info_item/nomo_info_item.dart';
import 'package:nomo_ui_kit/components/input/textInput/nomo_input.dart';
import 'package:nomo_ui_kit/components/loading/loading.dart';
import 'package:nomo_ui_kit/components/outline_container/nomo_outline_container.dart';
import 'package:nomo_ui_kit/components/text/nomo_text.dart';
import 'package:nomo_ui_kit/utils/layout_extensions.dart';
import 'package:provider/provider.dart';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/common/async_value.dart';
import 'package:zeniq_swap_frontend/main.dart';
import 'package:zeniq_swap_frontend/providers/models/pair_info.dart';
import 'package:zeniq_swap_frontend/providers/models/token_entity.dart';
import 'package:zeniq_swap_frontend/providers/pool_provider.dart';
import 'package:zeniq_swap_frontend/providers/price_provider.dart';
import 'package:zeniq_swap_frontend/providers/swap_provider.dart';
import 'package:zeniq_swap_frontend/routes.dart';
import 'package:zeniq_swap_frontend/theme.dart';
import 'package:zeniq_swap_frontend/widgets/asset_picture.dart';
import 'package:nomo_ui_kit/theme/nomo_theme.dart';

enum Sorting {
  ascending(Icons.arrow_upward),
  descending(Icons.arrow_downward),
  none(null);

  final IconData? icon;

  const Sorting(this.icon);
}

class PoolsPage extends StatefulWidget {
  const PoolsPage({super.key});

  @override
  State<PoolsPage> createState() => _PoolsPageState();
}

class _PoolsPageState extends State<PoolsPage>
    with SingleTickerProviderStateMixin {
  late PoolProvider poolProvider;
  late final ValueNotifier<bool> showMyPoolsNotifier;
  late final ValueNotifier<String> searchInputNotifier;
  late final ValueNotifier<Sorting> liquiditySortingNotifier;
  late final ValueNotifier<PairType?> typeSortingNotifier;

  late final LayerLink _layerLink = LayerLink();
  late final OverlayPortalController _optionsViewController =
      OverlayPortalController();

  @override
  void initState() {
    showMyPoolsNotifier = ValueNotifier($addressNotifier.value != null);
    liquiditySortingNotifier = ValueNotifier(Sorting.none);
    typeSortingNotifier = ValueNotifier(null);
    searchInputNotifier = ValueNotifier("");
    $addressNotifier.addListener(_onAddressChanged);
    super.initState();
  }

  void _onAddressChanged() {
    showMyPoolsNotifier.value = $addressNotifier.value != null;
  }

  @override
  void dispose() {
    showMyPoolsNotifier.dispose();
    typeSortingNotifier.dispose();
    liquiditySortingNotifier.dispose();
    searchInputNotifier.dispose();
    $addressNotifier.removeListener(_onAddressChanged);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    poolProvider = context.read<PoolProvider>();
    super.didChangeDependencies();
  }

  void createPool() async {
    final selectedToken = await NomoNavigator.fromKey.push<TokenEntity?>(
      SelectAssetDialogRoute(
        forSwap: false,
      ),
    );

    if (selectedToken != null) {
      NomoNavigator.fromKey.push(CreatePairPageRoute(token: selectedToken));
    }
  }

  List<PairInfoEntity> filterPairs(List<PairInfoEntity> pairs) {
    final searchInput = searchInputNotifier.value;

    var filteredPairs = switch (searchInput.isEmpty) {
      true => pairs,
      _ => pairs.where((pair) {
          final token0 = pair.token0.symbol.toLowerCase();
          final token1 = pair.token1.symbol.toLowerCase();
          final search = searchInput.toLowerCase();
          return token0.contains(search) || token1.contains(search);
        }).toList()
    };

    final typeSorting = typeSortingNotifier.value;

    if (typeSorting != null) {
      filteredPairs =
          filteredPairs.where((pair) => pair.type == typeSorting).toList();
    }

    if (liquiditySortingNotifier.value == Sorting.descending) {
      filteredPairs
          .sort((a, b) => a.zeniqAmount.value > b.zeniqAmount.value ? -1 : 1);
    }

    if (liquiditySortingNotifier.value == Sorting.ascending) {
      filteredPairs
          .sort((a, b) => a.zeniqAmount.value > b.zeniqAmount.value ? 1 : -1);
    }

    return filteredPairs;
  }

  @override
  Widget build(BuildContext context) {
    final buttonWidth = context.responsiveValue<double>(
      small: 96,
      medium: 128,
      large: 128,
    );
    final spacing = context.responsiveValue<double>(
      small: 8,
      medium: 16,
      large: 16,
    );
    return NomoRouteBody(
      maxContentWidth: 1000,
      padding: context.responsiveValue(
        small: EdgeInsets.all(8),
        medium: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        large: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      ),
      child: Column(
        children: [
          ValueListenableBuilder(
            valueListenable: showMyPoolsNotifier,
            builder: (context, showMyPools, child) {
              return SizedBox(
                height: 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    ValueListenableBuilder(
                      valueListenable: $addressNotifier,
                      builder: (context, address, myPoolsButton) =>
                          switch (address) {
                        String _ => myPoolsButton!,
                        _ => SizedBox.shrink(),
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: SecondaryNomoButton(
                          height: 48,
                          width: buttonWidth,
                          text: "My Pools",
                          backgroundColor: Colors.transparent,
                          foregroundColor: showMyPools
                              ? context.colors.primary
                              : context.colors.disabled,
                          onPressed: () {
                            showMyPoolsNotifier.value = true;
                          },
                        ),
                      ),
                    ),
                    SecondaryNomoButton(
                      height: 48,
                      width: buttonWidth,
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
                      width: buttonWidth,
                      padding: EdgeInsets.zero,
                      borderRadius: BorderRadius.circular(16),
                      onPressed: createPool,
                    ),
                  ],
                ),
              );
            },
          ),
          spacing.vSpacing,
          NomoInput(
            placeHolder: "Search",
            height: 48,
            background: Colors.transparent,
            valueNotifier: searchInputNotifier,
            leading: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                Icons.search,
                color: context.colors.foreground2,
              ),
            ),
          ),
          spacing.vSpacing,
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16),
            height: 48,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                NomoText(
                  "Pool",
                  style: context.typography.b1,
                ),
                Spacer(),
                if (context.isSmall == false)
                  SizedBox(
                    width: 100,
                    child: OverlayPortal.targetsRootOverlay(
                      controller: _optionsViewController,
                      overlayChildBuilder: (context) {
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: GestureDetector(
                                onTap: () {
                                  _optionsViewController.hide();
                                },
                                child: Container(
                                  color: Colors.transparent,
                                ),
                              ),
                            ),
                            CompositedTransformFollower(
                              link: _layerLink,
                              showWhenUnlinked: false,
                              targetAnchor: Alignment.bottomLeft,
                              child: SizedBox(
                                width: 200,
                                child: NomoCard(
                                  backgroundColor: context.colors.background3,
                                  borderRadius: BorderRadius.circular(16),
                                  padding: EdgeInsets.all(16),
                                  child: ValueListenableBuilder(
                                    valueListenable: typeSortingNotifier,
                                    builder: (context, selType, child) {
                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          for (final type in PairType.values)
                                            Row(
                                              children: [
                                                NomoText(type.name),
                                                Spacer(),
                                                Material(
                                                  type:
                                                      MaterialType.transparency,
                                                  child: Switch(
                                                    activeColor:
                                                        context.colors.primary,
                                                    inactiveTrackColor:
                                                        context.colors.disabled,
                                                    value: type == selType,
                                                    onChanged: (value) {
                                                      typeSortingNotifier
                                                              .value =
                                                          value ? type : null;
                                                    },
                                                  ),
                                                ),
                                              ],
                                            )
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                      child: CompositedTransformTarget(
                        link: _layerLink,
                        child: NomoTextButton(
                          height: 48,
                          width: 100,
                          onPressed: () {
                            _optionsViewController.show();
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              NomoText(
                                "Type",
                                style: context.typography.b1,
                              ),
                              8.hSpacing,
                              ValueListenableBuilder(
                                valueListenable: typeSortingNotifier,
                                builder: (context, type, child) {
                                  return Icon(
                                    type == null
                                        ? Icons.filter_alt_outlined
                                        : Icons.filter_alt,
                                    size: 16,
                                    color: context.colors.foreground2,
                                  );
                                },
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                32.hSpacing,
                NomoTextButton(
                  height: 48,
                  width: 100,
                  onPressed: () {
                    liquiditySortingNotifier.value =
                        switch (liquiditySortingNotifier.value) {
                      Sorting.ascending => Sorting.descending,
                      Sorting.descending => Sorting.ascending,
                      _ => Sorting.ascending,
                    };
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      NomoText(
                        "Liquidity",
                        style: context.typography.b1,
                      ),
                      ValueListenableBuilder(
                        valueListenable: liquiditySortingNotifier,
                        builder: (context, sorting, child) {
                          return switch (sorting.icon) {
                            IconData icon => Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Icon(
                                  icon,
                                  size: 16,
                                  color: context.colors.foreground2,
                                ),
                              ),
                            _ => const SizedBox.shrink(),
                          };
                        },
                      ),
                    ],
                  ),
                ),
                if (context.isSmall == false) ...[
                  32.hSpacing,
                  SizedBox(
                    width: 100,
                    child: NomoText(
                      "My Liquidity",
                      style: context.typography.b1,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
                if (context.isLarge) 74.hSpacing,
              ],
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge([
                showMyPoolsNotifier,
                searchInputNotifier,
                liquiditySortingNotifier,
                typeSortingNotifier,
                poolProvider.allPairsNotifier,
              ]),
              builder: (context, child) {
                final showMyPools = showMyPoolsNotifier.value;
                final allPairsAsync = poolProvider.allPairsNotifier.value;

                return allPairsAsync.when(
                  data: (allPairs) {
                    final pairs = switch (showMyPools) {
                      true => allPairs.whereType<OwnedPairInfo>().toList(),
                      _ => allPairs,
                    };

                    final filteredPairs = filterPairs(pairs);

                    return ListView.separated(
                      itemBuilder: (context, index) => PairItem(
                        pair: filteredPairs[index],
                      ),
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 16),
                      itemCount: filteredPairs.length,
                    );
                  },
                  loading: () => Center(child: Loading()),
                  error: (error) => NomoText(error.toString()),
                );
              },
            ),
          ),
        ],
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

  void onPressed() {
    NomoNavigator.fromKey.push(
      PoolDetailPageRoute(
        address: pair.pair.contractAddress,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final priceProvider = context.watch<PriceProvider>();

    final token0PriceNotifier =
        priceProvider.priceNotifierForToken(pair.token0);
    final token1PriceNotifier =
        priceProvider.priceNotifierForToken(pair.token1);

    final items = [
      SizedBox(
        width: 100,
        child: Align(
          alignment: Alignment.centerRight,
          child: NomoOutlineContainer(
            padding: EdgeInsets.symmetric(horizontal: 16),
            background: switch (pair.type) {
              PairType.v2 => context.colors.primary.withOpacity(0.1),
              _ => context.colors.error.withOpacity(0.1),
            },
            height: 48,
            radius: 16,
            child: Center(child: NomoText(pair.type.name)),
          ),
        ),
      ),
      32.hSpacing,
      Container(
        width: 100,
        // color: Colors.yellow,
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

            return NomoText(
              "${currency.symbol}${tvl.toStringAsFixed(2)}",
              style: context.typography.b1,
              textAlign: TextAlign.right,
            );
          },
        ),
      ),
      32.hSpacing,
      if (pair is OwnedPairInfo)
        SizedBox(
          width: 100,
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
              final tvl = (pair as OwnedPairInfo)
                  .myTotalValueLocked(token0Price, token1Price);

              return NomoText(
                "${currency.symbol}${tvl.toStringAsFixed(2)}",
                style: context.typography.b1,
                textAlign: TextAlign.right,
              );
            },
          ),
        )
      else
        SizedBox(
          width: 100,
        ),
    ];

    final pictureSize =
        context.responsiveValue<double>(small: 42, medium: 48, large: 48);

    return SizedBox(
      height: context.isLarge ? 64 : null,
      child: PrimaryNomoButton(
        backgroundColor: context.colors.background2.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        padding: EdgeInsets.symmetric(horizontal: 16),
        onPressed: onPressed,
        child: Column(
          children: [
            SizedBox(
              height: 64,
              child: Row(
                children: [
                  SizedBox(
                    width: pictureSize * 1.75,
                    child: Stack(
                      children: [
                        AssetPicture(
                          token: zeniqTokenWrapper,
                          size: pictureSize,
                        ),
                        Positioned(
                          left: pictureSize * 3 / 4,
                          child: AssetPicture(
                            token: pair.token,
                            size: pictureSize,
                          ),
                        ),
                      ],
                    ),
                  ),
                  12.hSpacing,
                  NomoText(
                    "${pair.token.symbol}",
                    style: context.typography.b2,
                  ),
                  Spacer(),
                  if (context.isLarge) ...[
                    ...items,
                    32.hSpacing,
                    SecondaryNomoButton(
                      backgroundColor: Colors.transparent,
                      height: 42,
                      width: 42,
                      iconSize: 18,
                      border: Border.fromBorderSide(BorderSide.none),
                      icon: Icons.arrow_forward_ios,
                      onPressed: onPressed,
                    )
                  ] else
                    SecondaryNomoButton(
                      backgroundColor: Colors.transparent,
                      height: 42,
                      width: 42,
                      iconSize: 18,
                      border: Border.fromBorderSide(BorderSide.none),
                      icon: Icons.arrow_forward_ios,
                      onPressed: onPressed,
                    )
                ],
              ),
            ),
            if (context.isLarge == false)
              SizedBox(
                child: Column(
                  children: [
                    Row(
                      children: [
                        NomoText(
                          "Liquidity",
                          style: context.typography.b1,
                        ),
                        Spacer(),
                        ListenableBuilder(
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
                            final isLoading =
                                token0PriceAsync is AsyncLoading ||
                                    token1PriceAsync is AsyncLoading;

                            if (isLoading) {
                              return Loading();
                            }

                            final token0Price = token0PriceAsync.valueOrNull!
                                .getPriceForType(pair.type);
                            final token1Price = token1PriceAsync.valueOrNull!
                                .getPriceForType(pair.type);
                            final currency =
                                token1PriceAsync.valueOrNull!.currency;
                            final tvl =
                                pair.totalValueLocked(token0Price, token1Price);

                            return NomoText(
                              "${currency.symbol}${tvl.toStringAsFixed(2)}",
                              style: context.typography.b1,
                              fontWeight: FontWeight.bold,
                              textAlign: TextAlign.right,
                            );
                          },
                        )
                      ],
                    ),
                    if (pair is OwnedPairInfo)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            NomoText("My Liquidity",
                                style: context.typography.b1),
                            Spacer(),
                            ListenableBuilder(
                              listenable: Listenable.merge([
                                token0PriceNotifier,
                                token1PriceNotifier,
                              ]),
                              builder: (context, child) {
                                final token0PriceAsync =
                                    token0PriceNotifier.value;
                                final token1PriceAsync =
                                    token1PriceNotifier.value;
                                final isError =
                                    token0PriceAsync is AsyncError ||
                                        token1PriceAsync is AsyncError;

                                if (isError) {
                                  // print(token0PriceAsync.errorOrNull);
                                  // print(token1PriceAsync.errorOrNull);
                                  return NomoText('Error');
                                }
                                final isLoading =
                                    token0PriceAsync is AsyncLoading ||
                                        token1PriceAsync is AsyncLoading;

                                if (isLoading) {
                                  return Loading();
                                }

                                final token0Price = token0PriceAsync
                                    .valueOrNull!
                                    .getPriceForType(pair.type);
                                final token1Price = token1PriceAsync
                                    .valueOrNull!
                                    .getPriceForType(pair.type);
                                final currency =
                                    token1PriceAsync.valueOrNull!.currency;
                                final tvl = (pair as OwnedPairInfo)
                                    .myTotalValueLocked(
                                        token0Price, token1Price);

                                return NomoText(
                                  "${currency.symbol}${tvl.toStringAsFixed(2)}",
                                  style: context.typography.b1,
                                  fontWeight: FontWeight.bold,
                                  textAlign: TextAlign.right,
                                );
                              },
                            )
                          ],
                        ),
                      ),
                    16.vSpacing,
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
