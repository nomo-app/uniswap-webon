import 'dart:convert';

import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/common/http_client.dart';
import 'package:zeniq_swap_frontend/common/notifier.dart';
import 'package:zeniq_swap_frontend/providers/models/pair_info.dart';
import 'package:zeniq_swap_frontend/providers/models/token_entity.dart';
import 'package:zeniq_swap_frontend/providers/pool_provider.dart';

class TokenProvider {
  final ValueDiffNotifier<Set<TokenEntity>> notifier;

  final Map<ERC20Entity, AsyncNotifier<String>> _images = {};

  Set<TokenEntity> get tokens => notifier.value;

  final Set<TokenEntity> initialTokens;

  Set<TokenEntity> getTokensForPairType(PairType pairType) {
    return tokens.where((token) {
      return token.pairTypes.contains(pairType);
    }).toSet();
  }

  TokenProvider(this.initialTokens) : notifier = ValueDiffNotifier({}) {
    fetchAllTokens();
  }

  void addToken(ERC20Entity token) {
    notifier.value = {
      ...tokens,
      TokenEntity(
        token,
        image: null,
        pairTypes: [],
      ),
    };
  }

  AsyncNotifier<String> imageNotifierForToken(
    ERC20Entity token,
  ) {
    return _images.putIfAbsent(token, () {
      return AsyncNotifier();
    });
  }

  void fetchAllTokens() async {
    try {
      final response = await HTTPService.client.get(
        Uri.parse("$backendUrl/tokens"),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode != 200) {
        throw Exception(
          "token_provider: Request returned status code ${response.statusCode}",
        );
      }

      final body = jsonDecode(response.body) as List<dynamic>;

      final tokens = <TokenEntity>{};

      for (final token in body) {
        final tokenEntity = TokenEntity.fromJson(token);
        final notifier = imageNotifierForToken(tokenEntity);
        if (tokenEntity.image != null) {
          notifier.setValue(tokenEntity.image!);
        } else {
          notifier.setError("No image found for token");
        }

        tokens.add(tokenEntity);
      }

      notifier.value = {
        ...tokens,
        ...initialTokens,
      };
    } catch (e, s) {
      print("token_provider: Error fetching tokens: $e");
      print(s);
      notifier.value = {};
    }
  }
}
