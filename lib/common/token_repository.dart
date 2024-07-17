import 'dart:async';
import 'dart:convert';

import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/common/http_client.dart';
import 'package:zeniq_swap_frontend/common/price_repository.dart';

abstract class TokenRepository {
  static const String endpoint = "https://webon.info/api/tokens";

  static Future<List<EthBasedTokenEntity>> fetchFixedTokens() async {
    final response = await HTTPService.client.get(
      Uri.parse(endpoint),
      headers: {"Content-Type": "application/json"},
    ).timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw TimeoutException("Timeout", REQUEST_TIMEOUT_LIMIT),
    );

    if (response.statusCode != 200) {
      throw Exception(
        "token_repository: Request returned status code ${response.statusCode}",
      );
    }
    final body = jsonDecode(response.body);

    if (body == null && body is! List<dynamic>) {
      throw Exception(
        "token_repository: Request returned null: $endpoint",
      );
    }

    return [
      for (Map<String, dynamic> jsonMap in body)
        () {
          if (jsonMap
              case {
                "name": String _,
                "symbol": String _,
                "decimals": int _,
                "contractAddress": String _,
                "chainId": int chainId,
                "is_nft": false,
                "type": "ZEN-20",
              }) {
            return EthBasedTokenEntity.fromJson(
              jsonMap,
              allowDeletion: true,
              chainID: chainId,
            );
          }
          return null;
        }.call()
    ].whereType<EthBasedTokenEntity>().toList();
  }
}
