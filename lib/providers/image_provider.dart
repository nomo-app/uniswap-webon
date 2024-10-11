import 'package:flutter/widgets.dart';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/common/async_value.dart';
import 'package:zeniq_swap_frontend/common/image_repository.dart';
import 'package:zeniq_swap_frontend/providers/swap_provider.dart';

class TokenImageProvider {
  final Map<ERC20Entity, ValueNotifier<AsyncValue<ImageEntity>>> _images = {};
  final ValueNotifier<Set<ERC20Entity>> tokenNotifier;
  Set<ERC20Entity> lastTokens = {};
  Set<ERC20Entity> get tokens => tokenNotifier.value;

  TokenImageProvider(this.tokenNotifier) {
    tokensChanged();
    tokenNotifier.addListener(tokensChanged);
  }

  void tokensChanged() {
    // final diff = tokens.difference(lastTokens);

    // fetchAllImages(diff);

    // lastTokens = tokens;
  }

  Future<void> fetchAllImages(Iterable<ERC20Entity> tokens) async =>
      await Future.wait(tokens.map(fetchImageForToken));

  Future<void> fetchImageForToken(ERC20Entity token) async {
    final notifier = _images.putIfAbsent(
      token,
      () => ValueNotifier(AsyncLoading()),
    );

    try {
      final image = await ImageRepository.getImage(
        switch (token) {
          zeniqTokenWrapper => zeniqSmart,
          _ => token,
        },
      );

      notifier.value = AsyncValue.value(image);
    } catch (e) {
      notifier.value = AsyncValue.error(e);
    }
  }

  ValueNotifier<AsyncValue<ImageEntity>> imageNotifierForToken(
    ERC20Entity token,
  ) {
    return _images.putIfAbsent(
      token,
      () => ValueNotifier(AsyncLoading()),
    );
  }
}

class InheritedImageProvider extends InheritedWidget {
  final TokenImageProvider provider;

  const InheritedImageProvider({
    required this.provider,
    required super.child,
  });

  static TokenImageProvider of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<InheritedImageProvider>()!
        .provider;

    return provider;
  }

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) {
    return false;
  }
}
