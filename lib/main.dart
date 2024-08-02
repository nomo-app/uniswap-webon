import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:nomo_router/nomo_router.dart';
import 'package:nomo_ui_kit/app/nomo_app.dart';
import 'package:nomo_ui_kit/components/buttons/primary/nomo_primary_button.dart';
import 'package:nomo_ui_kit/components/text/nomo_text.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:webon_kit_dart/webon_kit_dart.dart';
import 'package:zeniq_swap_frontend/common/token_repository.dart';
import 'package:zeniq_swap_frontend/providers/asset_notifier.dart';
import 'package:zeniq_swap_frontend/providers/swap_provider.dart';
import 'package:zeniq_swap_frontend/routes.dart';
import 'package:zeniq_swap_frontend/theme.dart';

final appRouter = AppRouter();

void main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  final String address;
  final List<TokenEntity> assets = [];
  try {
    if (WebonKitDart.isFallBackMode()) {
      //   throw Exception('Fallback mode is active');
    }

    address = await WebonKitDart.getEvmAddress();

    try {
      assets.addAll(await WebonKitDart.getAllAssets().then(
        (assets) => assets.where((asset) {
          return asset.chainId == ZeniqSmartNetwork.chainId;
        }).map((asset) {
          if (asset.contractAddress != null) {
            return EthBasedTokenEntity(
              name: asset.name,
              symbol: asset.symbol,
              decimals: asset.decimals,
              contractAddress: asset.contractAddress!,
              chainID: asset.chainId!,
            );
          }

          return EvmEntity(
            name: asset.name,
            symbol: asset.symbol,
            decimals: asset.decimals,
            chainID: asset.chainId!,
          );
        }).toList(),
      ));
    } catch (e) {
      assets.addAll(await TokenRepository.fetchFixedTokens());
      assets.add(zeniqSmart);
      assets.add(avinocZSC); // For now
      assets.add(tupanToken);
    }
  } catch (e) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: NomoDefaultTextStyle(
          style: const TextStyle(color: Colors.white, fontSize: 32),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.warning,
                      size: 96.0,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 24.0),
                    const Text(
                      'Not inside the NomoApp. Please use zeniqswap.com for Swapping in the browser.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16.0),
                    const Text(
                      'Or download the Nomo App from the App Store or Google Play Store.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 64.0),
                    PrimaryNomoButton(
                      text: "Download Nomo App",
                      textStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                      ),
                      elevation: 10,
                      height: 64,
                      borderRadius: BorderRadius.circular(10),
                      padding: EdgeInsets.zero,
                      width: 320,
                      onPressed: () async {
                        await launchUrlString("https://nomo.app/install");
                      },
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  runApp(
    InheritedSwapProvider(
      swapProvider: SwapProvider(
        address,
        WebonKitDart.signTransaction,
      ),
      child: InheritedAssetProvider(
        notifier: AssetNotifier(
          address,
          assets,
        ),
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return NomoNavigator(
      delegate: appRouter.delegate,
      child: NomoApp(
        color: const Color(0xFF1A1A1A),
        routerConfig: appRouter.config,
        supportedLocales: const [Locale('en', 'US')],
        themeDelegate: AppThemeDelegate(),
      ),
    );
  }
}
