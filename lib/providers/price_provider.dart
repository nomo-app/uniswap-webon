import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/common/async_value.dart';
import 'package:zeniq_swap_frontend/common/http_client.dart';
import 'package:zeniq_swap_frontend/common/logger.dart';
import 'package:zeniq_swap_frontend/common/notifier.dart';
import 'package:zeniq_swap_frontend/providers/models/currency.dart';
import 'package:zeniq_swap_frontend/providers/models/pair_info.dart';
import 'package:zeniq_swap_frontend/providers/models/price_state.dart';
import 'package:zeniq_swap_frontend/providers/pool_provider.dart';
import 'package:zeniq_swap_frontend/providers/swap_provider.dart';
import 'package:zeniq_swap_frontend/providers/token_provider.dart';

class PriceProvider {
  final TokenProvider tokenProvider;
  final ValueNotifier<Currency> currencyNotifier;

  Currency get currency => currencyNotifier.value;
  Set<ERC20Entity> get tokens => tokenProvider.tokens;

  PriceProvider({
    required this.currencyNotifier,
    required this.tokenProvider,
  }) {
    currencyNotifier.addListener(() {
      fetchAllPrices(tokens);
    });

    tokenProvider.notifier.addListener(() {
      fetchAllPrices(tokens);
    });

    Timer.periodic(Duration(minutes: 1), (_) {
      fetchAllPrices(tokens);
    });
  }

  final Map<ERC20Entity, AsyncNotifier<PriceState>> _prices = {};

  void refreshToken(ERC20Entity token) {
    // TODO: Refresh token price
  }

  void addToken(PairInfoEntity pairInfo) {
    final zeniqPrice =
        priceNotifierForToken(zeniqTokenWrapper).value.valueOrNull?.price;
    if (zeniqPrice == null) return;

    final tokenPrice = pairInfo.zeniqRatio * zeniqPrice;

    priceNotifierForToken(pairInfo.token).setValue(
      PriceState(
        price: tokenPrice,
        currency: currency,
        priceLegacy: null,
      ),
    );
  }

  AsyncNotifier<PriceState> priceNotifierForToken(
    ERC20Entity token,
  ) {
    return _prices.putIfAbsent(
      token,
      () {
        return AsyncNotifier(null);
      },
    );
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
        final notifier = priceNotifierForToken(token);
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
}
