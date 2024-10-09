import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/common/async_value.dart';
import 'package:zeniq_swap_frontend/common/logger.dart';
import 'package:zeniq_swap_frontend/common/price_repository.dart';
import 'package:zeniq_swap_frontend/providers/swap_provider.dart';

const _fetchInterval = Duration(minutes: 1);

class AssetNotifier {
  final ValueNotifier<String?> addressNotifier;

  String? get address => addressNotifier.value;
  final ValueNotifier<Set<ERC20Entity>> tokenNotifier;

  Set<ERC20Entity> get tokens => tokenNotifier.value;

  Set<ERC20Entity> lastTokens = {};

  final EvmRpcInterface rpc = EvmRpcInterface(
    type: ZeniqSmartNetwork,
    clients: [
      EvmRpcClient(zeniqSmartRPCEndpoint),
    ],
  );

  final ValueNotifier<Currency> currencyNotifier = ValueNotifier(Currency.usd);

  Currency get currency => currencyNotifier.value;

  List<PairInfo> tokenPairs = [];

  final Map<ERC20Entity, ValueNotifier<AsyncValue<Amount>>> _balances = {};
  final Map<ERC20Entity, ValueNotifier<AsyncValue<PriceState>>> _prices = {};

  void addToken(ERC20Entity token) {
    tokenNotifier.value = {...tokens, token};
  }

  void refresh() {
    fetchAllBalances(tokens);
    fetchAllPrices(tokens);
  }

  void tokensChanged() {
    final diff = tokens.difference(lastTokens);

    fetchAllBalances(diff);
    fetchAllPrices(diff);

    lastTokens = tokens;
  }

  AssetNotifier(this.addressNotifier, this.tokenNotifier) {
    tokensChanged();
    tokenNotifier.addListener(tokensChanged);

    addressNotifier.addListener(
      () {
        for (final token in tokens) {
          _balances[token]!.value = AsyncLoading();
        }
        fetchAllBalances(tokens);
      },
    );

    currencyNotifier.addListener(() {
      fetchAllPrices(tokens);
    });

    Timer.periodic(_fetchInterval, (_) {
      fetchAllBalances(tokens);
      fetchAllPrices(tokens);
    });
  }

  Future<void> fetchAllBalances(Iterable<ERC20Entity> tokens) async =>
      await Future.wait(tokens.map(fetchBalanceForToken));

  Future<void> fetchBalanceForToken(ERC20Entity token) async {
    if (address == null) return;

    final notifier = _balances.putIfAbsent(
      token,
      () => ValueNotifier(AsyncLoading()),
    );

    try {
      final balance = await rpc.fetchTokenBalance(address!, token);

      notifier.value = AsyncValue.value(balance);
    } catch (e) {
      notifier.value = AsyncValue.error(e);
    }
  }

  Future<void> fetchAllPrices(Set<ERC20Entity> tokens) async {
    final results =
        await PriceRepository.fetchAll(currency: currency, tokens: tokens);

    final noPriceTokens = tokens.where((token) {
      final priceEntity = results.singleWhereOrNull((pe) => pe.token == token);
      return priceEntity == null;
    }).toSet();

    final priceTokens = tokens.difference(noPriceTokens);

    calculatePricesForTokens(noPriceTokens.toList());

    for (final token in priceTokens) {
      var priceEntity = results.singleWhereOrNull((pe) => pe.token == token);

      final notifier = _prices.putIfAbsent(
        token,
        () => ValueNotifier(AsyncLoading()),
      );

      if (priceEntity == null || priceEntity.isPending) {
        notifier.value = AsyncValue.error("Price not available");
        continue;
      }

      notifier.value = AsyncValue.value(
        PriceState(currency: currency, price: priceEntity.price),
      );
    }
  }

  Future<void> calculatePricesForTokens(List<ERC20Entity> tokens) async {
    final zeniqPrice = await PriceRepository.fetchSingle(
      zeniqSmart,
      currency,
    );
    final futures = [
      for (final token in tokens)
        fetchPriceForTokenPair(
          token,
          zeniqPrice,
        ),
    ];

    final result = await Future.wait(futures);

    for (final (price, token) in result) {
      final notifier = _prices.putIfAbsent(
        token,
        () => ValueNotifier(AsyncLoading()),
      );

      if (price == null) {
        notifier.value = AsyncValue.error("Price not available");
        continue;
      }

      notifier.value = AsyncValue.value(price);
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
            tokenA: zeniqTokenWrapper.contractAddress,
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

  Future<void> fetchPriceForToken(ERC20Entity token) async {
    final notifier = _prices.putIfAbsent(
      token,
      () => ValueNotifier(AsyncLoading()),
    );
    try {
      final result = await PriceRepository.fetchSingle(token, currency);
      notifier.value = AsyncValue.value(
        PriceState(currency: currency, price: result),
      );
    } catch (e) {
      notifier.value = AsyncValue.error(e);
    }
  }

  ValueNotifier<AsyncValue<Amount>> balanceNotifierForToken(
    ERC20Entity token,
  ) {
    return _balances.putIfAbsent(
      token,
      () => ValueNotifier(AsyncLoading()),
    );
  }

  ValueNotifier<AsyncValue<PriceState>> priceNotifierForToken(
    ERC20Entity token,
  ) {
    return _prices.putIfAbsent(
      token,
      () => ValueNotifier(AsyncLoading()),
    );
  }
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
    return false;
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

    final token0IsZeniq = token0Contract == zeniqTokenWrapper.lowerCaseAddress;

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
