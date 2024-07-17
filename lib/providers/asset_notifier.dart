import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/common/async_value.dart';
import 'package:zeniq_swap_frontend/common/image_repository.dart';
import 'package:zeniq_swap_frontend/common/price_repository.dart';

const _fetchInterval = Duration(minutes: 1);

class AssetNotifier {
  final String address;
  final List<TokenEntity> tokens;
  final EvmRpcInterface rpc = EvmRpcInterface(ZeniqSmartNetwork);

  final ValueNotifier<Currency> currencyNotifier = ValueNotifier(Currency.usd);

  Currency get currency => currencyNotifier.value;

  final Map<TokenEntity, ValueNotifier<AsyncValue<Amount>>> _balances = {};
  final Map<TokenEntity, ValueNotifier<AsyncValue<PriceState>>> _prices = {};
  final Map<TokenEntity, ValueNotifier<AsyncValue<ImageEntity>>> _images = {};

  AssetNotifier(this.address, this.tokens) {
    for (final token in tokens) {
      _balances[token] = ValueNotifier(AsyncValue.loading());
      _prices[token] = ValueNotifier(AsyncValue.loading());
      _images[token] = ValueNotifier(AsyncValue.loading());
    }

    currencyNotifier.addListener(() {
      fetchAllPrices();
    });

    fetchAllBalances();
    fetchAllPrices();
    fetchAllImages();

    Timer.periodic(_fetchInterval, (_) {
      fetchAllBalances();
      fetchAllPrices();
      fetchAllImages();
    });
  }

  Future<void> fetchAllImages() async =>
      await Future.wait(tokens.map(fetchImageForToken));

  Future<void> fetchImageForToken(TokenEntity token) async {
    final currentImage = _images[token]!.value;

    if (currentImage.hasValue) return;

    try {
      final image = await ImageRepository.getImage(token);
      _images[token]!.value = AsyncValue.value(image);
    } catch (e) {
      _images[token]!.value = AsyncValue.error(e);
    }
  }

  Future<void> fetchAllBalances() async =>
      await Future.wait(tokens.map(fetchBalanceForToken));

  Future<void> fetchBalanceForToken(TokenEntity token) async {
    try {
      final balance = await (token.isERC20
          ? rpc.fetchTokenBalance(address, token.asEthBased!)
          : rpc.fetchBalance(address: address));

      _balances[token]!.value = AsyncValue.value(balance);
    } catch (e) {
      _balances[token]!.value = AsyncValue.error(e);
    }
  }

  Future<void> fetchAllPrices() async {
    final results =
        await PriceRepository.fetchAll(currency: currency, tokens: tokens);

    for (final token in tokens) {
      var priceEntity = results.firstWhereOrNull((pe) => pe.matchToken(token));

      if (priceEntity == null || priceEntity.isPending) {
        _prices[token]!.value = AsyncValue.error("Price not available");
        continue;
      }

      _prices[token]!.value = AsyncValue.value(
        PriceState(currency: currency, price: priceEntity.price),
      );
    }
  }

  ValueNotifier<AsyncValue<Amount>> notifierForToken(TokenEntity token) =>
      _balances[token]!;

  ValueNotifier<AsyncValue<PriceState>> priceNotifierForToken(
          TokenEntity token) =>
      _prices[token]!;

  ValueNotifier<AsyncValue<ImageEntity>>? imageNotifierForToken(
          TokenEntity token) =>
      _images[token];
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
    return notifier.tokens != oldWidget.notifier.tokens;
  }
}
