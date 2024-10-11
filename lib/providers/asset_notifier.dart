import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/common/async_value.dart';
import 'package:zeniq_swap_frontend/common/http_client.dart';
import 'package:zeniq_swap_frontend/common/logger.dart';
import 'package:zeniq_swap_frontend/providers/models/currency.dart';
import 'package:zeniq_swap_frontend/providers/models/pair_info.dart';
import 'package:zeniq_swap_frontend/providers/models/price_state.dart';
import 'package:zeniq_swap_frontend/providers/pool_provider.dart';
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

  final ValueNotifier<Currency> currencyNotifier;

  Currency get currency => currencyNotifier.value;

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
    // fetchAllPrices(diff);

    lastTokens = tokens;
  }

  AssetNotifier(
    this.addressNotifier,
    this.tokenNotifier,
    this.currencyNotifier,
  ) {
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
    try {
      final response = await HTTPService.client.get(
        Uri.parse(
          "$backendUrl/prices/$currency",
        ),
        headers: {
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode != 200) {
        throw Exception("Failed to fetch prices");
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      final zeniqPrice = json["zeniqPrice"];

      final results = [
        for (final Map<String, dynamic> priceJson in json["tokenPrices"])
          (
            priceJson["token"] as String,
            PriceState(
              price: priceJson['prices'][PairType.v2.name] as double?,
              priceLegacy: priceJson['prices'][PairType.legacy.name] as double?,
              currency: currency,
            ),
          )
      ];

      for (final token in tokens) {
        final notifier = _prices.putIfAbsent(
          token,
          () => ValueNotifier(AsyncLoading()),
        );
        if (token == zeniqTokenWrapper) {
          notifier.value = AsyncValue.value(PriceState(
            currency: currency,
            price: zeniqPrice,
            priceLegacy: null,
          ));
          continue;
        }
        if (token == wrappedZeniqSmart) {
          notifier.value = AsyncValue.value(PriceState(
            currency: currency,
            price: null,
            priceLegacy: zeniqPrice,
          ));
          continue;
        }

        final priceState = results
            .singleWhereOrNull((r) => r.$1 == token.lowerCaseAddress)
            ?.$2;

        if (priceState == null) {
          notifier.value = AsyncValue.error("Price not available");
          continue;
        }

        notifier.value = AsyncValue.value(priceState);
      }
    } catch (e, s) {
      Logger.logError(e, s: s);
    }
  }

  ValueNotifier<AsyncValue<Amount>> balanceNotifierForToken(
    ERC20Entity token,
  ) {
    return _balances.putIfAbsent(
      token,
      () {
        addToken(token);
        return ValueNotifier(AsyncLoading());
      },
    );
  }

  ValueNotifier<AsyncValue<PriceState>> priceNotifierForToken(
    ERC20Entity token,
  ) {
    return _prices.putIfAbsent(
      token,
      () {
        addToken(token);
        return ValueNotifier(AsyncLoading());
      },
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
