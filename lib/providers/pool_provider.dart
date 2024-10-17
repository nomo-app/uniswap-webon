import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/common/async_value.dart';
import 'package:zeniq_swap_frontend/common/notifier.dart';
import 'package:zeniq_swap_frontend/providers/models/pair_info.dart';
import 'package:zeniq_swap_frontend/providers/swap_provider.dart';
import 'package:http/http.dart' as http;

const backendUrl = "";

final factoryNew = UniswapV2Factory(
  rpc: rpc,
  contractAddress: "0x40a4E23Cc9E57161699Fd37c0A4d8bca383325f3",
);

final factoryOld = UniswapV2Factory(
  rpc: rpc,
  contractAddress: "0x7D0cbcE25EaaB8D5434a53fB3B42077034a9bB99",
);

class PoolProvider {
  final ValueNotifier<String?> addressNotifier;

  String? get address => addressNotifier.value;

  final AsyncNotifier<List<PairInfoEntity>> allPairsNotifier = AsyncNotifier();

  Completer<List<PairInfoEntity>> _allPairsCompleter = Completer();

  Future<List<PairInfoEntity>> get allPairsFuture => _allPairsCompleter.future;

  final Map<String, AsyncNotifier<PairInfoEntity>> pairNotifiers = {};

  AsyncNotifier<PairInfoEntity> getPairNotifier(String address) {
    final notifier = pairNotifiers.putIfAbsent(
      address,
      () {
        return allPairsNotifier.value.when(
          loading: () => AsyncNotifier(),
          error: (error) => AsyncNotifier(),
          data: (allPairs) {
            final pair = allPairs.singleWhereOrNull(
              (pair) => pair.pair.contractAddress == address,
            );

            if (pair == null) {
              return AsyncNotifier();
            }

            return AsyncNotifier(pair);
          },
        );
      },
    );

    return notifier;
  }

  void addPair(PairInfoEntity newPair) {
    allPairsNotifier.setValue([
      ...?allPairsNotifier.value.valueOrNull,
      newPair,
    ]);
  }

  void updatePair(String address, PairInfoEntity updatedPair) {
    getPairNotifier(address).setValue(updatedPair);

    allPairsNotifier.setValue(
      [
        ...?allPairsNotifier.value.valueOrNull?.map(
          (pair) {
            if (pair.pair.contractAddress == address) {
              return updatedPair;
            }

            return pair;
          },
        ).toList(),
      ],
    );
  }

  PoolProvider({
    required this.addressNotifier,
  }) {
    fetchAllRemote().then((_) {
      fetchMyPairs();
    });

    addressNotifier.addListener(() {
      fetchMyPairs();
    });
  }

  Future<void> fetchMyPairs() async {
    if (address == null) return;

    final allPairs = await allPairsFuture.then(
      (value) => value.whereType<PairInfo>(),
    );

    final ownedPairs = await Future.wait(
      [
        for (final pair in allPairs)
          pair.erc20Contract.getBalance(address!).then(
            (balance) {
              if (balance == BigInt.zero) return null;
              return OwnedPairInfo.fromPairInfo(
                pairTokenAmount: balance,
                pairInfo: pair,
              );
            },
          ).then(
            (ownedPairInfo) {
              if (ownedPairInfo == null) return null;
              getPairNotifier(ownedPairInfo.pair.contractAddress)
                  .setValue(ownedPairInfo);
              return ownedPairInfo;
            },
          ),
      ],
    ).then(
      (value) => value.whereType<OwnedPairInfo>(),
    );

    allPairsNotifier.setValue(
      allPairs.map(
        (pair) {
          final ownedPair = ownedPairs.singleWhereOrNull(
            (ownedPair) =>
                ownedPair.pair.contractAddress == pair.pair.contractAddress,
          );

          if (ownedPair != null) {
            return ownedPair;
          }

          return pair;
        },
      ).toList(),
    );
  }

  Future<void> fetchAllRemote() async {
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
          PairInfoEntity.fromJson(pairJson as Map<String, dynamic>)
      ];

      allPairsNotifier.value = AsyncValue.value(pairs);

      _allPairsCompleter.complete(pairs);
    } catch (e, s) {
      print(e);
      print(s);
      allPairsNotifier.value = AsyncValue.error(e);
    }
  }
}
