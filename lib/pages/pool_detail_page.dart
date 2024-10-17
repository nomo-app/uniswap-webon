import 'package:flutter/material.dart';
import 'package:nomo_router/nomo_router.dart';
import 'package:nomo_ui_kit/components/app/routebody/nomo_route_body.dart';
import 'package:nomo_ui_kit/components/buttons/secondary/nomo_secondary_button.dart';
import 'package:nomo_ui_kit/components/loading/loading.dart';
import 'package:nomo_ui_kit/theme/nomo_theme.dart';
import 'package:nomo_ui_kit/utils/layout_extensions.dart';
import 'package:provider/provider.dart';
import 'package:zeniq_swap_frontend/common/notifier.dart';
import 'package:zeniq_swap_frontend/providers/balance_provider.dart';
import 'package:zeniq_swap_frontend/providers/models/pair_info.dart';
import 'package:zeniq_swap_frontend/providers/pool_provider.dart';
import 'package:zeniq_swap_frontend/routes.dart';
import 'package:zeniq_swap_frontend/widgets/liquidity/add/add_liquidity.dart';
import 'package:zeniq_swap_frontend/widgets/liquidity/overview/pool_overview.dart';
import 'package:zeniq_swap_frontend/widgets/liquidity/remove/remove_liquidity.dart';

class PoolDetailPage extends StatefulWidget {
  final String? address;

  const PoolDetailPage({super.key, this.address});

  @override
  State<PoolDetailPage> createState() => _PoolDetailPageState();
}

class _PoolDetailPageState extends State<PoolDetailPage> {
  late final AsyncNotifier<PairInfoEntity> pairInfoNotifier;

  @override
  void didChangeDependencies() {
    if (widget.address == null) {
      Future.microtask(
        () {
          NomoNavigator.fromKey.replace(PoolsPageRoute());
        },
      );
      return;
    }

    pairInfoNotifier =
        context.read<PoolProvider>().getPairNotifier(widget.address!);
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.address == null) {
      return const SizedBox();
    }
    return NomoRouteBody(
      maxContentWidth: 720,
      child: ValueListenableBuilder(
        valueListenable: pairInfoNotifier,
        builder: (context, pairInfoAsync, child) {
          return pairInfoAsync.when(
            loading: () => Center(child: const Loading()),
            data: (value) => PoolWrapper(pairInfo: value),
            error: (error) => Center(child: Text(error.toString())),
          );
        },
      ),
    );
  }
}

enum PoolDetailLocation {
  overview("Overview"),
  addLiquidity("Add Liquidity"),
  removeLiquidity("Remove Liquidity");

  final String title;

  const PoolDetailLocation(this.title);
}

class PoolWrapper extends StatefulWidget {
  final PairInfoEntity pairInfo;

  const PoolWrapper({
    super.key,
    required this.pairInfo,
  });

  @override
  State<PoolWrapper> createState() => _PoolWrapperState();
}

class _PoolWrapperState extends State<PoolWrapper> {
  PairInfoEntity get pairInfo => widget.pairInfo;

  late final ValueNotifier<PoolDetailLocation> locationNotifier =
      ValueNotifier(PoolDetailLocation.removeLiquidity);

  List<PoolDetailLocation> get locations => switch (pairInfo) {
        OwnedPairInfo pairInfo => [
            PoolDetailLocation.overview,
            if (pairInfo.type != PairType.legacy)
              PoolDetailLocation.addLiquidity,
            PoolDetailLocation.removeLiquidity,
          ],
        PairInfo pairInfo => [
            PoolDetailLocation.overview,
            if (pairInfo.type != PairType.legacy)
              PoolDetailLocation.addLiquidity,
          ],
      };

  void dispose() {
    locationNotifier.dispose();
    super.dispose();
  }

  OwnedPairInfo? get ownedPairInfo =>
      pairInfo is OwnedPairInfo ? pairInfo as OwnedPairInfo : null;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: locationNotifier,
      builder: (context, location, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (final location in locations)
                  SecondaryNomoButton(
                    height: 48,
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    onPressed: () {
                      locationNotifier.value = location;
                    },
                    text: location.title,
                    backgroundColor: Colors.transparent,
                    foregroundColor: location == locationNotifier.value
                        ? context.colors.primary
                        : context.colors.foreground1,
                  ),
              ].spacingH(12),
            ),
            24.vSpacing,
            AnimatedSwitcher(
              duration: Duration(milliseconds: 300),
              child: switch (location) {
                PoolDetailLocation.overview => PoolOverview(
                    pairInfo: widget.pairInfo,
                  ),
                PoolDetailLocation.addLiquidity => PoolAddLiquidity(
                    pairInfo: widget.pairInfo,
                    assetNotifier: context.watch<BalanceProvider>(),
                  ),
                PoolDetailLocation.removeLiquidity => PoolRemoveLiquidity(
                    pairInfo: ownedPairInfo!,
                  ),
              },
            )
          ],
        );
      },
    );
  }
}
