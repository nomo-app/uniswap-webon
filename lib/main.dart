import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nomo_router/nomo_router.dart';
import 'package:nomo_router/router/entities/transitions.dart';
import 'package:nomo_ui_kit/app/nomo_app.dart';
import 'package:nomo_ui_kit/components/buttons/primary/nomo_primary_button.dart';
import 'package:nomo_ui_kit/components/card/nomo_card.dart';
import 'package:nomo_ui_kit/components/text/nomo_text.dart';
import 'package:nomo_ui_kit/theme/nomo_theme.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:webon_kit_dart/webon_kit_dart.dart';
import 'package:zeniq_swap_frontend/common/token_repository.dart';
import 'package:zeniq_swap_frontend/pages/background.dart';
import 'package:zeniq_swap_frontend/providers/asset_notifier.dart';
import 'package:zeniq_swap_frontend/providers/swap_provider.dart';
import 'package:zeniq_swap_frontend/routes.dart';
import 'package:zeniq_swap_frontend/theme.dart';

final appRouter = AppRouter();

final assetsNotifier = ValueNotifier(<ERC20Entity>[]);

const deeplink = 'https://nomo.app/webon/dex.zeniqswap.com';

void main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();

  final String address;

  try {
    if (WebonKitDart.isFallBackMode() && kDebugMode == false) {
      throw Exception('Fallback mode is active');
    }

    address = await WebonKitDart.getEvmAddress();
  } catch (e) {
    print(e);

    final textStyle = GoogleFonts.roboto(
      color: Colors.white,
      fontSize: 16,
    );

    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: NomoDefaultTextStyle(
          style: const TextStyle(color: Colors.white, fontSize: 32),
          child: Builder(builder: (context) {
            return Scaffold(
//backgroundColor: Colors.black.withOpacity(0.95),
              extendBodyBehindAppBar: true,
              body: Stack(
                children: [
                  AppBackground(),
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 32,
                        ),
                        child: NomoCard(
                          backgroundColor: Color(0xff1e2428).withOpacity(0.5),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 8,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/logo.png',
                                width: 28,
                                height: 28,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Dex',
                                style: GoogleFonts.dancingScript(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                        ),
                      ),
                      Spacer(),
                      Center(
                        child: NomoCard(
                          backgroundColor: Color(0xff1e2428).withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 48),
                          child: SizedBox(
                            width: 380,
                            child: Column(
                              children: [
                                Text(
                                  "Coming Soon",
                                  style: GoogleFonts.roboto().copyWith(
                                    fontSize: 36,
                                    // fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 32.0),
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    color: Colors.white,
                                  ),
                                  padding: EdgeInsets.all(16),
                                  width: 200,
                                  height: 200,
                                  child: GestureDetector(
                                    onTap: () async {
                                      await launchUrlString(
                                        'https://nomo.app/webon/dex.zeniqswap.com',
                                      );
                                    },
                                    child: BarcodeWidget(
                                      data: deeplink,
                                      color: Colors.black,
                                      barcode: Barcode.fromType(
                                        BarcodeType.QrCode,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32.0),
                                Text(
                                  'Not inside the NomoApp. Please use zeniqswap.com for Swapping in the browser.',
                                  textAlign: TextAlign.center,
                                  style: textStyle,
                                ),
                                const SizedBox(height: 16.0),
                                Text(
                                  'Or download the Nomo App from the App Store or Google Play Store.',
                                  textAlign: TextAlign.center,
                                  style: textStyle,
                                ),
                                const SizedBox(height: 32.0),
                                PrimaryNomoButton(
                                  text: "Download Nomo App",
                                  textStyle: GoogleFonts.roboto(
                                    color: Colors.white,
                                    fontSize: 22,
                                  ),
                                  elevation: 0,
                                  height: 64,
                                  backgroundColor: primaryColor,
                                  borderRadius: BorderRadius.circular(4),
                                  padding: EdgeInsets.zero,
                                  width: 320,
                                  onPressed: () async {
                                    await launchUrlString(deeplink);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Spacer(),
                    ],
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
    return;
  }

  fetchTokens();

  runApp(
    InheritedSwapProvider(
      swapProvider: SwapProvider(
        address,
        WebonKitDart.signTransaction,
      ),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return NomoNavigator(
      delegate: appRouter.delegate,
      defaultTransistion: PageFadeTransition(),
      child: NomoApp(
        color: const Color(0xFF1A1A1A),
        routerConfig: appRouter.config,
        supportedLocales: const [Locale('en', 'US')],
        themeDelegate: AppThemeDelegate(),
        appWrapper: (context, app) {
          return ValueListenableBuilder(
            valueListenable: assetsNotifier,
            builder: (context, assets, snapshot) {
              return InheritedAssetProvider(
                notifier: AssetNotifier(
                  InheritedSwapProvider.of(context).ownAddress,
                  assets,
                ),
                child: app,
              );
            },
          );
        },
      ),
    );
  }
}

Future<void> fetchTokens() async {
  final Set<ERC20Entity> assets = {zeniqTokenWrapper};
  try {
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

    assets.addAll(assetsWithLiquidity);
  } catch (e) {
    try {
      final fixedTokens = await TokenRepository.fetchFixedTokens();
      final tokens = await TokenRepository.fetchTokensWhereLiquidty(
        allTokens: fixedTokens,
        minZeniqInPool: 1,
      );

      assets.addAll(tokens);
    } catch (e) {
      assets.addAll([tupanToken, iLoveSafirToken, avinocZSC]);
    }
  }

  assetsNotifier.value = assets.toList();
}
