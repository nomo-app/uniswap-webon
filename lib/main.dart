import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:nomo_router/nomo_router.dart';
import 'package:nomo_router/router/entities/transitions.dart';
import 'package:nomo_ui_kit/app/nomo_app.dart';
import 'package:provider/provider.dart';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:webon_kit_dart/webon_kit_dart.dart';
import 'package:zeniq_swap_frontend/common/token_repository.dart';
import 'package:zeniq_swap_frontend/providers/balance_provider.dart';
import 'package:zeniq_swap_frontend/providers/models/currency.dart';
import 'package:zeniq_swap_frontend/providers/pool_provider.dart';
import 'package:zeniq_swap_frontend/providers/price_provider.dart';
import 'package:zeniq_swap_frontend/providers/swap_provider.dart';
import 'package:zeniq_swap_frontend/providers/token_provider.dart';
import 'package:zeniq_swap_frontend/routes.dart';
import 'package:zeniq_swap_frontend/theme.dart';

final $tokenNotifier = ValueNotifier(<ERC20Entity>{});
final $addressNotifier = ValueNotifier<String?>(null);
final $currencyNotifier = ValueNotifier(Currency.usd);
final $slippageNotifier = ValueNotifier(0.005);

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

  $currencyNotifier.value = WebLocalStorage.getItem('currency') == 'usd'
      ? Currency.usd
      : Currency.eur;

  $currencyNotifier.addListener(() {
    WebLocalStorage.setItem('currency', $currencyNotifier.value.toString());
  });

  final savedTokensJson =
      jsonDecode(WebLocalStorage.getItem('tokens') ?? '[]') as List<dynamic>;

  final savedTokens = [
    for (final tokenJson in savedTokensJson)
      ERC20Entity.fromJson(
        tokenJson,
        allowDeletion: true,
        chainID: tokenJson['chainID'] as int,
      ),
  ];

  $tokenNotifier.value = savedTokens.toSet();

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

  //$addressNotifier.value = arbitrumTestWallet;

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

  $tokenNotifier.value = {
    zeniqTokenWrapper,
    ...assetsWithLiquidity,
    ...$tokenNotifier.value
  };
}

Future<void> initMetamask() async {
  try {
    final fixedTokens = await TokenRepository.fetchFixedTokens();
    final tokens = await TokenRepository.fetchTokensWhereLiquidty(
      allTokens: fixedTokens,
      minZeniqInPool: 1,
    );

    $tokenNotifier.value = {
      zeniqTokenWrapper,
      ...tokens,
      ...$tokenNotifier.value
    };
  } catch (e) {
    $tokenNotifier.value = {
      zeniqTokenWrapper,
      tupanToken,
      iLoveSafirToken,
      avinocZSC,
      ...$tokenNotifier.value
    };
  }
}

Future<String> metamaskSigner(String rawTxSerialized) async {
  final rawTx = RawEVMTransactionType0.fromUnsignedHex(rawTxSerialized);

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
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TokenProvider>(
          create: (context) => TokenProvider(),
        ),
        Provider<BalanceProvider>(
          create: (context) => BalanceProvider(
            addressNotifier: $addressNotifier,
            tokenProvider: context.read<TokenProvider>(),
          ),
        ),
        Provider(
          create: (context) => PriceProvider(
            currencyNotifier: $currencyNotifier,
            tokenProvider: context.read<TokenProvider>(),
          ),
        ),
        Provider(
          create: (context) => PoolProvider(
            addressNotifier: $addressNotifier,
          ),
        ),
      ],
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
    );
  }
}
