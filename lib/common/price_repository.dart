import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/common/http_client.dart';
import 'package:zeniq_swap_frontend/common/logger.dart';
import 'package:zeniq_swap_frontend/providers/swap_provider.dart';

const REQUEST_TIMEOUT_LIMIT = Duration(seconds: 10);
const PRICE_ENDPOINT = "https://price.zeniq.services/v2";

const chaindIdMap = {
  1: "ethereum",
  383414847825: "zeniq-smart-chain",
};

enum Currency {
  usd("US Dollar", "\$"),
  eur("Euro", "€");
  // gbp,
  // chf;

  final String displayName;
  final String symbol;

  const Currency(this.displayName, this.symbol);

  @override
  String toString() => name;
}

class PriceState {
  final double price;
  final Currency currency;

  const PriceState({
    required this.price,
    required this.currency,
  });
}

class PriceEntity {
  final String symbol;
  final CoinEntity token;
  final double price;
  final bool isPending;
  final String currency;

  const PriceEntity({
    required this.token,
    required this.symbol,
    required this.price,
    required this.isPending,
    required this.currency,
  });

  factory PriceEntity.fromJson(Map<String, dynamic> json, CoinEntity token) =>
      PriceEntity(
        symbol: json['symbol'] as String,
        price: (json['price'] as num).toDouble(),
        currency: json['fiat'] as String,
        isPending: json['isPending'] as bool,
        token: token,
      );
}

abstract class PriceRepository {
  ///
  /// All Prices
  ///
  static Future<List<PriceEntity>> fetchAll({
    required Currency currency,
    required Iterable<CoinEntity> tokens,
  }) async {
    if (tokens.length <= 20) {
      return _fetchAllCatchEmpty(currency: currency, tokens: tokens);
    }

    final results = await Future.wait([
      for (var i = 0; i < tokens.length; i += 20)
        _fetchAllCatchEmpty(
          currency: currency,
          tokens: tokens.skip(i).take(20),
        ),
    ]);

    final result = results.reduce((value, element) => [...value, ...element]);

    return result;
  }

  static Future<List<PriceEntity>> _fetchAllCatchEmpty({
    required Currency currency,
    required Iterable<CoinEntity> tokens,
  }) async {
    final List<PriceEntity> prices = [];
    try {
      final priceEntities = await _fetchAll(
        currency: currency,
        tokens: tokens,
      );

      prices.addAll(priceEntities);
    } catch (e) {
      Logger.log("Price Fetch Error: $e", "PriceFetch");
    }
    return prices;
  }

  static Future<List<PriceEntity>> _fetchAll({
    required Currency currency,
    required Iterable<CoinEntity> tokens,
  }) async {
    final uri = Uri.parse('$PRICE_ENDPOINT/currentpricelist');

    Logger.logFetch(
      "Fetch Price for [Assets=$tokens] in [Currency=$currency] from [Uri=$uri]",
      "PriceFetch",
    );

    final _body = jsonEncode(
      [
        for (final token in tokens) _getTokenRequestBody(token, currency),
      ],
    );

    final response = await http
        .post(
          uri,
          headers: {"Content-Type": "application/json"},
          body: _body,
        )
        .timeout(
          REQUEST_TIMEOUT_LIMIT,
          onTimeout: () =>
              throw TimeoutException("Timeout", REQUEST_TIMEOUT_LIMIT),
        );

    if (response.statusCode != 200) {
      throw Exception(
        "price_repository: $uri returned status code ${response.statusCode}",
      );
    }
    final body = jsonDecode(response.body);

    if (body == null || body is! List) {
      throw Exception(
        "price_repository: $uri returned null ($tokens $currency)",
      );
    }

    return [
      for (int i = 0; i < body.length; i++)
        if (body[i] != null) PriceEntity.fromJson(body[i], tokens[i]),
    ];
  }

  ///
  /// Single
  ///
  static Future<double> fetchSingle(
    CoinEntity token,
    Currency currency,
  ) async {
    if (token == avinocZSC) {
      token = avinocETH; // workaround for a price-service bug
    }
    final endpoint = token is ERC20Entity
        ? "$PRICE_ENDPOINT/currentprice/${token.contractAddress}/${currency.name}/${chaindIdMap[token.chainID]!}"
        : "$PRICE_ENDPOINT/currentprice/${token.name}/${currency.name}";

    try {
      final price = await (_fetchSingle(
        endpoint: endpoint,
        currency: currency.name,
        token: token,
      ).timeout(REQUEST_TIMEOUT_LIMIT));

      return price;
    } catch (e) {
      rethrow;
    }
  }

  static Future<double> _fetchSingle({
    required String endpoint,
    required String currency,
    required CoinEntity token,
  }) async {
    final uri = Uri.parse(endpoint);

    Logger.logFetch(
      "Fetch Price from $endpoint",
      "PriceFetch",
    );

    final response = await HTTPService.client.get(
      uri,
      headers: {"Content-Type": "application/json"},
    ).timeout(
      REQUEST_TIMEOUT_LIMIT,
      onTimeout: () => throw TimeoutException("Timeout", REQUEST_TIMEOUT_LIMIT),
    );

    if (response.statusCode != 200) {
      throw Exception(
        "price_repository: $endpoint returned status code ${response.statusCode}",
      );
    }
    final body = jsonDecode(response.body);

    if (body == null) {
      throw Exception(
        "price_repository: $endpoint returned null",
      );
    }

    final priceEntity = PriceEntity.fromJson(body, token);
    Logger.log("Price Entity pending: ${priceEntity.isPending}", "PriceFetch");
    if (priceEntity.isPending) {
      throw Exception(
        "price_repository: $endpoint returned pending",
      );
    }

    return priceEntity.price;
  }

  ///
  /// Util
  ///

  static List<String> _getTokenRequestBody(
    CoinEntity token,
    final Currency currency,
  ) {
    if (token is ERC20Entity && token != zeniqTokenWrapper) {
      return [
        token.contractAddress,
        currency.name,
        chaindIdMap[token.chainID]!,
      ];
    }

    return [
      token.name,
      currency.name,
    ];
  }
}

extension TokenName on CoinEntity {
  String get name {
    if (this == zeniqCoin || this == zeniqSmart || this == zeniqTokenWrapper) {
      return zeniqCoin.name.toLowerCase();
    } else {
      return symbol.toLowerCase();
    }
  }
}
