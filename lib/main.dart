import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:nomo_router/nomo_router.dart';
import 'package:nomo_router/router/entities/transitions.dart';
import 'package:nomo_ui_kit/app/nomo_app.dart';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:webon_kit_dart/webon_kit_dart.dart';
import 'package:zeniq_swap_frontend/common/token_repository.dart';
import 'package:zeniq_swap_frontend/providers/asset_notifier.dart';
import 'package:zeniq_swap_frontend/providers/image_provider.dart';
import 'package:zeniq_swap_frontend/providers/swap_provider.dart';
import 'package:zeniq_swap_frontend/routes.dart';
import 'package:zeniq_swap_frontend/theme.dart';

final appRouter = AppRouter();

final $tokenNotifier = ValueNotifier(<ERC20Entity>{});
final $addressNotifier = ValueNotifier<String?>(null);
late final MetamaskConnection? $metamask;

const deeplink = 'https://nomo.app/webon/dex.zeniqswap.com';

void main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();

  final inNomo = WebonKitDart.isFallBackMode() == false;

  // MetamaskBridge.ethereumAddToken(
  //   (
  //     address: "0xF1cA9cb74685755965c7458528A36934Df52A3EF",
  //     symbol: "AVINOC",
  //     decimals: 18,
  //     image: "https://price.zeniq.services/images/868.png",
  //   ),
  // );

  init(inNomo);

  runApp(MyApp());
}

Future<void> init(bool inNomo) {
  return Future.delayed(
    Duration(seconds: 5),
    () {
      inNomo ? initNomo() : initMetamask();
    },
  );
}

Future<void> initNomo() async {
  $addressNotifier.value = await WebonKitDart.getEvmAddress();
  final allAppAssets = await WebonKitDart.getAllAssets().then(
    (assets) => assets
        .where((asset) {
          return asset.chainId == ZeniqSmartNetwork.chainId;
        })
        .map((asset) {
          if (asset.contractAddress != null) {
            return ERC20Entity(
              name: asset.name,
              symbol: asset.symbol,
              decimals: asset.decimals,
              contractAddress: asset.contractAddress!,
              chainID: asset.chainId!,
            );
          }

          return null;
        })
        .whereType<ERC20Entity>()
        .toList(),
  );

  final assetsWithLiquidity = await TokenRepository.fetchTokensWhereLiquidty(
    allTokens: allAppAssets,
    minZeniqInPool: 1,
  );

  $tokenNotifier.value = {zeniqTokenWrapper, ...assetsWithLiquidity};
}

Future<void> initMetamask() async {
  $metamask = MetamaskConnection();

  await $metamask!.initFuture;

  $addressNotifier.value = $metamask!.currentAccount;

  try {
    final fixedTokens = await TokenRepository.fetchFixedTokens();
    final tokens = await TokenRepository.fetchTokensWhereLiquidty(
      allTokens: fixedTokens,
      minZeniqInPool: 1,
    );

    $tokenNotifier.value = {zeniqTokenWrapper, ...tokens};
  } catch (e) {
    $tokenNotifier.value = {
      zeniqTokenWrapper,
      tupanToken,
      iLoveSafirToken,
      avinocZSC
    };
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return InheritedImageProvider(
      provider: TokenImageProvider($tokenNotifier),
      child: NomoNavigator(
        delegate: appRouter.delegate,
        defaultTransistion: PageFadeTransition(),
        child: NomoApp(
          color: const Color(0xFF1A1A1A),
          routerConfig: appRouter.config,
          supportedLocales: const [Locale('en', 'US')],
          themeDelegate: AppThemeDelegate(),
          appWrapper: (context, app) {
            return ValueListenableBuilder(
              valueListenable: $addressNotifier,
              builder: (context, address, child) {
                return InheritedSwapProvider(
                  swapProvider: SwapProvider(
                    address,
                    WebonKitDart.signTransaction,
                  ),
                  child: InheritedAssetProvider(
                    notifier: AssetNotifier(address, $tokenNotifier),
                    child: app,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
