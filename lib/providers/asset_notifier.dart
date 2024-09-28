import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/common/async_value.dart';
import 'package:zeniq_swap_frontend/common/image_repository.dart';
import 'package:zeniq_swap_frontend/common/logger.dart';
import 'package:zeniq_swap_frontend/common/price_repository.dart';
import 'package:zeniq_swap_frontend/providers/swap_provider.dart';

const _fetchInterval = Duration(minutes: 1);

class AssetNotifier {
  final String address;
  final List<CoinEntity> tokens;
  final EvmRpcInterface rpc = EvmRpcInterface(
    type: ZeniqSmartNetwork,
    clients: [
      EvmRpcClient(zeniqSmartRPCEndpoint),
    ],
  );

  final ValueNotifier<Currency> currencyNotifier = ValueNotifier(Currency.usd);

  Currency get currency => currencyNotifier.value;

  List<PairInfo> tokenPairs = [];

  final Map<CoinEntity, ValueNotifier<AsyncValue<Amount>>> _balances = {};
  final Map<CoinEntity, ValueNotifier<AsyncValue<PriceState>>> _prices = {};
  final Map<CoinEntity, ValueNotifier<AsyncValue<ImageEntity>>> _images = {};

  void addPreviewToken(CoinEntity token) {
    _balances[token] = ValueNotifier(AsyncValue.loading());
    _prices[token] = ValueNotifier(AsyncValue.loading());
    _images[token] = ValueNotifier(AsyncValue.loading());

    fetchBalanceForToken(token);
    fetchImageForToken(token);
  }

  void addToken(CoinEntity token) {
    tokens.add(token);

    fetchBalanceForToken(token);
    fetchImageForToken(token);
    fetchPriceForToken(token);
  }

  AssetNotifier(this.address, this.tokens) {
    for (final token in tokens) {
      _balances[token] = ValueNotifier(AsyncValue.loading());
      _prices[token] = ValueNotifier(AsyncValue.loading());
      _images[token] = ValueNotifier(AsyncValue.loading());
    }

    currencyNotifier.addListener(() {
      fetchAllPrices();
    });

    fetchAllBalances();
    fetchAllPrices();
    fetchAllImages();

    Timer.periodic(_fetchInterval, (_) {
      fetchAllBalances();
      fetchAllPrices();
      fetchAllImages();
    });
  }

  Future<void> fetchAllImages() async =>
      await Future.wait(tokens.map(fetchImageForToken));

  Future<void> fetchImageForToken(CoinEntity token) async {
    final currentImage = _images[token]!.value;

    if (currentImage.hasValue) return;

    try {
      final image = await ImageRepository.getImage(token);
      _images[token]!.value = AsyncValue.value(image);
    } catch (e) {
      _images[token]!.value = AsyncValue.error(e);
    }
  }

  Future<void> fetchAllBalances() async =>
      await Future.wait(tokens.map(fetchBalanceForToken));

  Future<void> fetchBalanceForToken(CoinEntity token) async {
    try {
      final balance = await (token.isERC20
          ? rpc.fetchTokenBalance(address, token.asEthBased!)
          : rpc.fetchBalance(address: address));

      _balances[token]!.value = AsyncValue.value(balance);
    } catch (e) {
      _balances[token]!.value = AsyncValue.error(e);
    }
  }

  Future<void> fetchAllPrices() async {
    final results =
        await PriceRepository.fetchAll(currency: currency, tokens: tokens);

    final noPriceTokens = tokens.where((token) {
      final priceEntity = results.singleWhereOrNull((pe) => pe.token == token);
      return priceEntity == null;
    }).toSet();

    final priceTokens = tokens.toSet().difference(noPriceTokens);

    calculatePricesForTokens(noPriceTokens.toList());

    for (final token in priceTokens) {
      var priceEntity = results.singleWhereOrNull((pe) => pe.token == token);

      if (priceEntity == null || priceEntity.isPending) {
        _prices[token]!.value = AsyncValue.error("Price not available");
        continue;
      }

      _prices[token]!.value = AsyncValue.value(
        PriceState(currency: currency, price: priceEntity.price),
      );
    }
  }

  Future<void> calculatePricesForTokens(List<CoinEntity> tokens) async {
    final zeniqPrice = await PriceRepository.fetchSingle(
      zeniqSmart,
      currency,
    );
    final futures = [
      for (final token in tokens)
        fetchPriceForTokenPair(
          token as ERC20Entity,
          zeniqPrice,
        ),
    ];

    final result = await Future.wait(futures);

    for (final (price, token) in result) {
      if (price == null) {
        _prices[token]!.value = AsyncValue.error("Price not available");
        continue;
      }

      _prices[token]!.value = AsyncValue.value(price);
    }
  }

  Future<(PriceState?, ERC20Entity)> fetchPriceForTokenPair(
    ERC20Entity token,
    double zeniqPrice,
  ) async {
    var pair =
        tokenPairs.singleWhereOrNull((element) => element.token == token);
    if (pair == null) {
      pair = await zfactory
          .getPair(
            tokenA: wrappedZeniqSmart.contractAddress,
            tokenB: token.contractAddress,
          )
          .then(
            (value) => PairInfo(
              token: token,
              pair: UniswapV2Pair(contractAddress: value, rpc: rpc),
            ),
          );

      tokenPairs.add(pair!);
    }
    try {
      final price = await pair.fetchPrice(currency, zeniqPrice);
      return (price, token);
    } catch (e) {
      return (null, token);
    }
  }

  Future<void> fetchPriceForToken(CoinEntity token) async {
    try {
      final result = await PriceRepository.fetchSingle(token, currency);
      _prices[token]!.value = AsyncValue.value(
        PriceState(currency: currency, price: result),
      );
    } catch (e) {
      _prices[token]!.value = AsyncValue.error(e);
    }
  }

  ValueNotifier<AsyncValue<Amount>>? notifierForToken(CoinEntity token) =>
      _balances[token];

  ValueNotifier<AsyncValue<PriceState>>? priceNotifierForToken(
          CoinEntity token) =>
      _prices[token];

  ValueNotifier<AsyncValue<ImageEntity>>? imageNotifierForToken(
          CoinEntity token) =>
      _images[token];
}

class InheritedAssetProvider extends InheritedWidget {
  final AssetNotifier notifier;

  const InheritedAssetProvider({
    Key? key,
    required this.notifier,
    required Widget child,
  }) : super(key: key, child: child);

  static AssetNotifier of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<InheritedAssetProvider>();
    if (provider == null) {
      throw FlutterError('InheritedBalanceProvider not found in context');
    }
    return provider.notifier;
  }

  @override
  bool updateShouldNotify(InheritedAssetProvider oldWidget) {
    return notifier.tokens != oldWidget.notifier.tokens;
  }
}

class PairInfo extends UniswapV2Pair {
  final CoinEntity token;

  PairInfo({
    required this.token,
    required UniswapV2Pair pair,
  }) : super(
          contractAddress: pair.contractAddress,
          rpc: pair.rpc,
        );

  Future<PriceState> fetchPrice(Currency currency, double? zeniqPrice) async {
    zeniqPrice ??= await PriceRepository.fetchSingle(
      zeniqSmart,
      currency,
    );
    final reserves = await getReserves();
    final token0Contract = await token0();

    final token0IsZeniq = token0Contract == wrappedZeniqSmart.lowerCaseAddress;

    var (zeniqReserves, tokenReserves) =
        token0IsZeniq ? (reserves.$1, reserves.$2) : (reserves.$2, reserves.$1);

    final decimalDiff = 18 - token.decimals;
    if (decimalDiff > 0) {
      tokenReserves = tokenReserves * BigInt.from(10).pow(decimalDiff);
    }

    final zeniqRatio = zeniqReserves / tokenReserves;

    Logger.log(
      "Ratio for ${token.name} is $zeniqRatio",
    );
    final price = zeniqPrice * zeniqRatio.toDouble();

    Logger.log(
      "Price for ${token.name} is $price",
    );

    return PriceState(
      currency: currency,
      price: price,
    );
  }
}
