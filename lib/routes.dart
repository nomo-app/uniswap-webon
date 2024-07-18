import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nomo_router/nomo_router.dart';
import 'package:nomo_router/router/entities/route.dart';
import 'package:nomo_router/router/entities/transitions.dart';
import 'package:route_gen/anotations.dart';
import 'package:zeniq_swap_frontend/pages/home.dart';
import 'package:zeniq_swap_frontend/widgets/select_asset_dialog.dart';
import 'package:zeniq_swap_frontend/widgets/settings_dialog.dart';

part 'routes.g.dart';

@AppRoutes()
const _routes = [
  MenuPageRouteInfo(path: "/", page: HomeScreen, title: "Home"),
  ModalRouteInfo(
    path: "/settings",
    page: SettingsDialog,
    transition: PageSharedAxisTransition(
      fillColor: Colors.black54,
      type: SharedAxisTransitionType.vertical,
    ),
  ),
  ModalRouteInfo(
    path: "/selectAssets",
    page: SelectAssetDialog,
    transition: PageSharedAxisTransition(
      fillColor: Colors.black54,
      type: SharedAxisTransitionType.vertical,
    ),
  ),
];
