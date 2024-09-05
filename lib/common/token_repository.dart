import 'dart:async';
import 'dart:convert';

import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/common/http_client.dart';
import 'package:zeniq_swap_frontend/common/price_repository.dart';
import 'package:zeniq_swap_frontend/providers/swap_provider.dart';

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
                "chainId": String chainId,
                "is_nft": false,
                "type": "ZEN-20",
              }) {
            final chainId_i = int.tryParse(chainId);
            if (chainId_i == null) {
              return null;
            }
            return EthBasedTokenEntity.fromJson(
              jsonMap,
              allowDeletion: true,
              chainID: chainId_i,
            );
          }
          return null;
        }.call()
    ].whereType<EthBasedTokenEntity>().toList();
  }

  static Future<List<EthBasedTokenEntity>> fetchTokensWhereLiquidty({
    required List<EthBasedTokenEntity> allTokens,
    required double minZeniqInPool,
  }) async {
    final allPairs = [
      for (final token in allTokens)
        await factory
            .getPair(
              tokenA: wrappedZeniqSmart.contractAddress,
              tokenB: token.contractAddress,
            )
            .then(
              (value) => UniswapV2Pair(
                rpc: factory.rpc,
                contractAddress: value,
                tokenA: wrappedZeniqSmart,
                tokenB: token,
              ),
            )
    ];

    final tokensWithLiquidity = <EthBasedTokenEntity>[];
    for (final pair in allPairs) {
      if (pair.contractAddress ==
          "0x0000000000000000000000000000000000000000") {
        continue;
      }
      final token0 = await pair.token0();
      final token1 = await pair.token1();
      final reserves = await pair.getReserves();

      final token0IsZeniq = token0.toLowerCase() ==
          wrappedZeniqSmart.contractAddress.toLowerCase();

      final nonZeniqToken = allTokens.singleWhere(
        (token) =>
            token.contractAddress.toLowerCase() ==
            (token0IsZeniq ? token1 : token0).toLowerCase(),
      );

      final wZeniqReserves = token0IsZeniq ? reserves.$1 : reserves.$2;

      final reservesAmount = Amount(
        value: wZeniqReserves,
        decimals: wrappedZeniqSmart.decimals,
      );

      if (reservesAmount.displayDouble > minZeniqInPool) {
        tokensWithLiquidity.add(nonZeniqToken);
      }
    }

    return tokensWithLiquidity.toList();
  }
}
