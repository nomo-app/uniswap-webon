import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nomo_router/nomo_router.dart';
import 'package:nomo_router/router/entities/route.dart';
import 'package:route_gen/anotations.dart';
import 'package:zeniq_swap_frontend/pages/swap_screen.dart';
import 'package:zeniq_swap_frontend/widgets/select_asset_dialog.dart';
import 'package:zeniq_swap_frontend/widgets/settings_dialog.dart';

part 'routes.g.dart';

@AppRoutes()
const _routes = [
  MenuPageRouteInfo(path: "/", page: SwappingScreen, title: "Home"),
  ModalRouteInfo(path: "/settings", page: SettingsDialog),
  ModalRouteInfo(path: "/selectAsset", page: SelectAssetDialog)
];
