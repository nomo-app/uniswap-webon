// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routes.dart';

// **************************************************************************
// RouteGenerator
// **************************************************************************

class AppRouter extends NomoAppRouter {
  final Future<bool> Function()? shouldPop;
  final Future<bool> Function()? willPop;
  late final RouterConfig<Object> config;
  late final NomoRouterDelegate delegate;
  AppRouter({this.shouldPop, this.willPop})
      : super(
          {
            SwappingScreenRoute.path: ([a]) => SwappingScreenRoute(),
            SettingsDialogRoute.path: ([a]) => SettingsDialogRoute(),
            SelectAssetDialogRoute.path: ([a]) => SelectAssetDialogRoute(),
          },
          _routes.expanded.where((r) => r is! NestedNavigator).toList(),
          _routes.expanded.whereType<NestedNavigator>().toList(),
        ) {
    delegate = NomoRouterDelegate(appRouter: this);
    config = RouterConfig(
        routerDelegate: delegate,
        backButtonDispatcher:
            NomoBackButtonDispatcher(delegate, shouldPop, willPop),
        routeInformationParser: const NomoRouteInformationParser(),
        routeInformationProvider: PlatformRouteInformationProvider(
          initialRouteInformation: RouteInformation(
            uri:
                WidgetsBinding.instance.platformDispatcher.defaultRouteName.uri,
          ),
        ));
  }
}

class SwappingScreenArguments {
  const SwappingScreenArguments();
}

class SwappingScreenRoute extends AppRoute implements SwappingScreenArguments {
  SwappingScreenRoute()
      : super(
          name: '/',
          page: SwappingScreen(),
        );
  static String path = '/';
}

class SettingsDialogArguments {
  const SettingsDialogArguments();
}

class SettingsDialogRoute extends AppRoute implements SettingsDialogArguments {
  SettingsDialogRoute()
      : super(
          name: '/settings',
          page: SettingsDialog(),
        );
  static String path = '/settings';
}

class SelectAssetDialogArguments {
  const SelectAssetDialogArguments();
}

class SelectAssetDialogRoute extends AppRoute
    implements SelectAssetDialogArguments {
  SelectAssetDialogRoute()
      : super(
          name: '/selectAsset',
          page: SelectAssetDialog(),
        );
  static String path = '/selectAsset';
}
