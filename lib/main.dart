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

const ChainInfo zeniqSmartChainInfo = (
  chainId: 383414847825,
  chainName: 'Zeniq',
  blockExplorerUrls: [
    "https://zeniqscan.com/",
  ],
  nativeCurrency: (
    decimals: 18,
    name: 'Zeniq',
    symbol: 'ZENIQ',
  ),
  rpcUrls: [
    "https://smart.zeniq.network:9545",
  ],
  iconUrls: [],
);

late final MetamaskConnection? $metamask;
late final bool $inNomo;
late final bool $inMetamask;

const deeplink = 'https://nomo.app/webon/dex.zeniqswap.com';

void main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();

  $inNomo = WebonKitDart.isFallBackMode() == false;
  $inMetamask = !$inNomo;

  if ($inNomo) {
    $addressNotifier.value = await WebonKitDart.getEvmAddress();
    initNomo();
  } else {
    $metamask = MetamaskConnection(
      accoutNotifier: $addressNotifier,
      defaultChain: zeniqSmartChainInfo,
    );
    await $metamask!.initFuture;
    initMetamask();
  }

  runApp(MyApp());
}

Future<void> initNomo() async {
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
  const MyApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return InheritedImageProvider(
      provider: TokenImageProvider($tokenNotifier),
      child: InheritedSwapProvider(
        swapProvider: SwapProvider(
          $addressNotifier,
          $inNomo
              ? WebonKitDart.signTransaction
              : (rawTxSerialized) async {
                  final rawTx =
                      RawEVMTransactionType0.fromUnsignedHex(rawTxSerialized);

                  return MetamaskConnection.ethereumSendTransaction(
                    {
                      "from": $addressNotifier.value!,
                      "to": rawTx.to,
                      "value": rawTx.value.toHexWithPrefix,
                      "data": rawTx.data.toHex,
                      "gas": rawTx.gasLimit.toHexWithPrefix,
                      "gasPrice": rawTx.gasPrice.toHexWithPrefix,
                    },
                  );
                },
          needToBroadcast: $inNomo,
        ),
        child: InheritedAssetProvider(
          notifier: AssetNotifier($addressNotifier, $tokenNotifier),
          child: NomoNavigator(
            delegate: appRouter.delegate,
            defaultTransistion: PageFadeTransition(),
            child: NomoApp(
              color: const Color(0xFF1A1A1A),
              routerConfig: appRouter.config,
              supportedLocales: const [Locale('en', 'US')],
              themeDelegate: AppThemeDelegate(),
            ),
          ),
        ),
      ),
    );
  }
}
