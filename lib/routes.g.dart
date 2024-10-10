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
            PoolsPageRoute.path: ([a]) => PoolsPageRoute(),
            ProfilePageRoute.path: ([a]) => ProfilePageRoute(),
            PoolDetailPageRoute.path: ([a]) {
              final typedArgs = a as PoolDetailPageArguments?;
              return PoolDetailPageRoute(
                address: typedArgs?.address,
              );
            },
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

class PoolsPageArguments {
  const PoolsPageArguments();
}

class PoolsPageRoute extends AppRoute implements PoolsPageArguments {
  PoolsPageRoute()
      : super(
          name: '/pools',
          page: PoolsPage(),
        );
  static String path = '/pools';
}

class ProfilePageArguments {
  const ProfilePageArguments();
}

class ProfilePageRoute extends AppRoute implements ProfilePageArguments {
  ProfilePageRoute()
      : super(
          name: '/profile',
          page: ProfilePage(),
        );
  static String path = '/profile';
}

class PoolDetailPageArguments {
  final String? address;
  const PoolDetailPageArguments({
    this.address,
  });
}

class PoolDetailPageRoute extends AppRoute implements PoolDetailPageArguments {
  @override
  final String? address;
  PoolDetailPageRoute({
    this.address,
  }) : super(
          name: '/pool',
          page: PoolDetailPage(
            address: address,
          ),
        );
  static String path = '/pool';
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
