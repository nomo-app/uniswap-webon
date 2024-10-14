import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/common/async_value.dart';
import 'package:zeniq_swap_frontend/providers/models/pair_info.dart';
import 'package:zeniq_swap_frontend/providers/swap_provider.dart';
import 'package:http/http.dart' as http;

const backendUrl = "http://127.0.0.1:3001";
// "https://zeniqswap-backend-v7s4few-dev2-nomo.globeapp.dev/";

final factoryNew = UniswapV2Factory(
  rpc: rpc,
  contractAddress: "0x40a4E23Cc9E57161699Fd37c0A4d8bca383325f3",
);

final factoryOld = UniswapV2Factory(
  rpc: rpc,
  contractAddress: "0x7D0cbcE25EaaB8D5434a53fB3B42077034a9bB99",
);

class PoolProvider {
  final ValueNotifier<AsyncValue<List<PairInfo>>> allPairsNotifier =
      ValueNotifier(AsyncValue.loading());

  final Map<String, ValueNotifier<AsyncValue<PairInfo>>> pairNotifiers = {};

  ValueNotifier<AsyncValue<PairInfo>> getPairNotifier(String address) {
    final notifier = pairNotifiers.putIfAbsent(
      address,
      () {
        return allPairsNotifier.value.when(
          loading: () => ValueNotifier(AsyncValue.loading()),
          error: (error) => ValueNotifier(AsyncValue.loading()),
          data: (allPairs) {
            final pair = allPairs.singleWhereOrNull(
              (pair) => pair.pair.contractAddress == address,
            );

            if (pair == null) {
              return ValueNotifier(AsyncValue.loading());
            }

            return ValueNotifier(AsyncValue.value(pair));
          },
        );
      },
    );

    return notifier;
  }

  PoolProvider() {
    fetchAllRemote();
  }

  void fetchAllRemote() async {
    try {
      final response = await http.get(
        Uri.parse("$backendUrl/pairs"),
        headers: {
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode != 200) {
        throw Exception("Failed to fetch pairs");
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      final pairs = [
        for (final pairJson in json["pairs"])
          PairInfo.fromJson(pairJson as Map<String, dynamic>)
      ];

      allPairsNotifier.value = AsyncValue.value(pairs);
    } catch (e, s) {
      print(e);
      print(s);
      allPairsNotifier.value = AsyncValue.error(e);
    }
  }
}
