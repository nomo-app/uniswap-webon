import 'dart:async';
import 'package:flutter/material.dart';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/common/async_value.dart';
import 'package:zeniq_swap_frontend/common/notifier.dart';
import 'package:zeniq_swap_frontend/providers/models/pair_info.dart';
import 'package:zeniq_swap_frontend/providers/models/token_entity.dart';
import 'package:zeniq_swap_frontend/providers/swap_provider.dart';
import 'package:zeniq_swap_frontend/providers/token_provider.dart';

const _fetchInterval = Duration(minutes: 1);

class BalanceProvider {
  final TokenProvider tokenProvider;
  final ValueNotifier<String?> addressNotifier;

  String? get address => addressNotifier.value;

  Set<TokenEntity> get tokens => tokenProvider.tokens;

  final Map<ERC20Entity, AsyncNotifier<Amount>> _balances = {};

  List<TokenEntity> get tokenWhereBalanceAndNotInPool => tokens
      .where(
        (token) =>
            (_balances[token]!.value.valueOrNull?.value ?? BigInt.zero) >
            BigInt.zero,
      )
      .where((token) => token.pairTypes.contains(PairType.v2) == false)
      .toList();

  BalanceProvider({
    required this.addressNotifier,
    required this.tokenProvider,
  }) {
    tokenProvider.notifier.addDiffListener(tokensChanged);

    Timer.periodic(
      _fetchInterval,
      (_) {
        fetchAllBalances(tokens);
      },
    );
  }

  void tokensChanged(Set<ERC20Entity>? old, Set<ERC20Entity> next) {
    final diff = next.difference(old ?? {});
    fetchAllBalances(diff);
  }

  void refreshForToken(ERC20Entity token) {
    fetchBalanceForToken(token);
  }

  Future<void> fetchAllBalances(Iterable<ERC20Entity> tokens) async =>
      await Future.wait(tokens.map(fetchBalanceForToken));

  Future<void> fetchBalanceForToken(ERC20Entity token) async {
    if (address == null) return;

    final notifier = balanceNotifierForToken(token);

    try {
      final balance = await rpc.fetchTokenBalance(address!, token);

      notifier.value = AsyncValue.value(balance);
    } catch (e) {
      notifier.value = AsyncValue.error(e);
    }
  }

  AsyncNotifier<Amount> balanceNotifierForToken(
    ERC20Entity token,
  ) {
    return _balances.putIfAbsent(
      token,
      () {
        return AsyncNotifier();
      },
    );
  }
}
