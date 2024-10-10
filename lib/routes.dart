import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nomo_router/nomo_router.dart';
import 'package:nomo_router/router/entities/route.dart';
import 'package:nomo_ui_kit/entities/menu_item.dart';
import 'package:route_gen/anotations.dart';
import 'package:zeniq_swap_frontend/pages/home_page.dart';
import 'package:zeniq_swap_frontend/pages/pool_detail_page.dart';
import 'package:zeniq_swap_frontend/pages/pools_page.dart';
import 'package:zeniq_swap_frontend/pages/profile_page.dart';
import 'package:zeniq_swap_frontend/pages/swap_screen.dart';
import 'package:zeniq_swap_frontend/widgets/select_asset_dialog.dart';
import 'package:zeniq_swap_frontend/widgets/settings_dialog.dart';

part 'routes.g.dart';

final appRouter = AppRouter();

@AppRoutes()
const _routes = [
  NestedNavigator(
    wrapper: wrapper,
    key: ValueKey("/"),
    children: [
      MenuPageRouteInfo(
        path: "/",
        page: SwappingScreen,
        title: "Swap",
      ),
      MenuPageRouteInfo(
        path: "/pools",
        page: PoolsPage,
        title: "Pools",
      ),
      PageRouteInfo(
        path: "/profile",
        page: ProfilePage,
      ),
      PageRouteInfo(
        path: "/pool",
        page: PoolDetailPage,
      ),
    ],
  ),
  ModalRouteInfo(path: "/settings", page: SettingsDialog),
  ModalRouteInfo(path: "/selectAsset", page: SelectAssetDialog)
];

final menuItems = appRouter.routeInfos.toMenuRoutes.toMenuItems;

Widget wrapper(nav) => HomePage(nav: nav);

extension MenuUtilList on Iterable<MenuRouteInfoMixin> {
  List<NomoMenuItem<String>> get toMenuItems {
    return map((route) => route.toMenuItem).toList();
  }
}

extension MenuUtil on MenuRouteInfoMixin {
  NomoMenuItem<String> get toMenuItem {
    if (icon != null) {
      return NomoMenuIconItem(
        title: title,
        icon: icon!,
        key: path,
      );
    }
    if (imagePath != null) {
      return NomoMenuImageItem(
        title: title,
        imagePath: imagePath!,
        key: path,
      );
    }
    return NomoMenuTextItem(
      title: title,
      key: path,
    );
  }
}
