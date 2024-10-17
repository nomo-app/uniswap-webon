// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routes.dart';

// **************************************************************************
// RouteGenerator
// **************************************************************************

class AppRouter extends NomoAppRouter {
  final List<NavigatorObserver> navigatorObservers;
  final Map<Key, List<NavigatorObserver>> nestedNavigatorObservers;

  /// Can only be accessed after [_configCompleter] is completed
  late final RouterConfig<Object> config;

  /// Can only be accessed after [_configCompleter] is completed
  late final NomoRouterDelegate delegate;

  final Completer<RouterConfig<Object>> _configCompleter = Completer();

  Future<RouterConfig<Object>> get configFuture => _configCompleter.future;

  void init({
    Widget? inital,
    Uri? initialUri,
    RouteInformationProvider? routeInformationProvider,
    Future<bool> Function()? shouldPop,
    Future<bool> Function()? willPop,
  }) {
    delegate = NomoRouterDelegate(
      appRouter: this,
      initial: inital,
      nestedObservers: nestedNavigatorObservers,
      observers: navigatorObservers,
    );
    config = RouterConfig(
      routerDelegate: delegate,
      backButtonDispatcher:
          NomoBackButtonDispatcher(delegate, shouldPop, willPop),
      routeInformationParser: NomoRouteInformationParser(),
      routeInformationProvider: routeInformationProvider ??
          PlatformRouteInformationProvider(
            initialRouteInformation: RouteInformation(
              uri: initialUri ??
                  WidgetsBinding
                      .instance.platformDispatcher.defaultRouteName.uri,
            ),
          ),
    );
    _configCompleter.complete(config);
  }

  AppRouter({
    bool delayInit = false,
    this.navigatorObservers = const [],
    this.nestedNavigatorObservers = const {},
    Widget? inital,
    Future<bool> Function()? shouldPop,
    Future<bool> Function()? willPop,
  }) : super(
          {
            SwappingScreenRoute.path: ([a]) => SwappingScreenRoute(),
            PoolsPageRoute.path: ([a]) => PoolsPageRoute(),
            ProfilePageRoute.path: ([a]) => ProfilePageRoute(),
            CreatePairPageRoute.path: ([a]) {
              final typedArgs = a as CreatePairPageArguments?;
              return CreatePairPageRoute(
                token: typedArgs?.token,
              );
            },
            PoolDetailPageRoute.path: ([a]) {
              final typedArgs = a as PoolDetailPageArguments?;
              return PoolDetailPageRoute(
                address: typedArgs?.address,
              );
            },
            SettingsDialogRoute.path: ([a]) => SettingsDialogRoute(),
            SelectAssetDialogRoute.path: ([a]) {
              final typedArgs = a as SelectAssetDialogArguments?;
              return SelectAssetDialogRoute(
                forSwap: typedArgs?.forSwap ?? true,
              );
            },
          },
          _routes.expanded.where((r) => r is! NestedNavigator).toList(),
          _routes.expanded.whereType<NestedNavigator>().toList(),
        ) {
    if (!delayInit) {
      init(
        inital: inital,
        shouldPop: shouldPop,
        willPop: willPop,
      );
    } else {
      assert(
        inital == null && willPop == null && shouldPop == null,
        "Provide inital, shouldPop, willPop in the init method.",
      );
    }
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

class CreatePairPageArguments {
  final TokenEntity? token;
  const CreatePairPageArguments({
    this.token,
  });
}

class CreatePairPageRoute extends AppRoute implements CreatePairPageArguments {
  @override
  final TokenEntity? token;
  CreatePairPageRoute({
    this.token,
  }) : super(
          name: '/createPool',
          page: CreatePairPage(
            token: token,
          ),
        );
  static String path = '/createPool';
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
  final bool forSwap;
  const SelectAssetDialogArguments({
    required this.forSwap,
  });
}

class SelectAssetDialogRoute extends AppRoute
    implements SelectAssetDialogArguments {
  @override
  final bool forSwap;
  SelectAssetDialogRoute({
    this.forSwap = true,
  }) : super(
          name: '/selectAsset',
          page: SelectAssetDialog(
            forSwap: forSwap,
          ),
        );
  static String path = '/selectAsset';
}
