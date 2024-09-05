import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nomo_router/nomo_router.dart';
import 'package:nomo_router/router/entities/route.dart';
import 'package:route_gen/anotations.dart';
import 'package:zeniq_swap_frontend/main.dart';

part 'routes.g.dart';

@AppRoutes()
const _routes = [
  MenuPageRouteInfo(path: "/", page: HomeScreen, title: "Home"),
];
