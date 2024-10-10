import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nomo_ui_kit/components/buttons/primary/nomo_primary_button.dart';
import 'package:nomo_ui_kit/components/buttons/secondary/nomo_secondary_button.dart';
import 'package:nomo_ui_kit/components/dialog/nomo_dialog.dart';
import 'package:nomo_ui_kit/components/divider/nomo_divider.dart';
import 'package:nomo_ui_kit/components/input/textInput/nomo_input.dart';
import 'package:nomo_ui_kit/components/loading/shimmer/loading_shimmer.dart';
import 'package:nomo_ui_kit/components/loading/shimmer/shimmer.dart';
import 'package:nomo_ui_kit/components/text/nomo_text.dart';
import 'package:nomo_ui_kit/theme/nomo_theme.dart';
import 'package:nomo_ui_kit/utils/layout_extensions.dart';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:webon_kit_dart/webon_kit_dart.dart';
import 'package:zeniq_swap_frontend/pages/swap_screen.dart';
import 'package:zeniq_swap_frontend/providers/asset_notifier.dart';
import 'package:zeniq_swap_frontend/providers/image_provider.dart';
import 'package:zeniq_swap_frontend/providers/swap_provider.dart';
import 'package:zeniq_swap_frontend/theme.dart';
import 'package:zeniq_swap_frontend/widgets/asset_picture.dart';

class SelectAssetDialog extends StatefulWidget {
  const SelectAssetDialog({super.key});

  @override
  State<SelectAssetDialog> createState() => _SelectAssetDialogState();
}

class _SelectAssetDialogState extends State<SelectAssetDialog> {
  late final ValueNotifier<String> searchNotifier = ValueNotifier('');
  late final ValueNotifier<ERC20Entity?> customTokenNotifier =
      ValueNotifier(null);

  late ValueNotifier<List<ERC20Entity>> filteredAssetsNotifer;
  late AssetNotifier assetNotifier;
  late TokenImageProvider imageProvider;

  @override
  void didChangeDependencies() {
    assetNotifier = InheritedAssetProvider.of(context);
    imageProvider = InheritedImageProvider.of(context);
    assetNotifier.tokenNotifier.addListener(
      () {
        filteredAssetsNotifer.value = assetNotifier.tokens.toList();
        onSearchInputChanged();
      },
    );
    filteredAssetsNotifer = ValueNotifier(assetNotifier.tokens.toList());
    super.didChangeDependencies();
  }

  @override
  void initState() {
    searchNotifier.addListener(onSearchInputChanged);
    searchNotifier.addListener(checkForCustomToken);

    super.initState();
  }

  @override
  void dispose() {
    searchNotifier.removeListener(onSearchInputChanged);
    searchNotifier.removeListener(checkForCustomToken);
    searchNotifier.dispose();
    filteredAssetsNotifer.dispose();
    super.dispose();
  }

  void checkForCustomToken() async {
    final searchText = searchNotifier.value.trim().toLowerCase();

    if (searchText.isEmpty) {
      customTokenNotifier.value = null;
      return;
    }

    final error = validateEVMAddress(address: searchText);

    if (error != null) {
      customTokenNotifier.value = null;
      return;
    }

    final existsAlready = assetNotifier.tokens.any(
      (token) {
        return token.contractAddress.toLowerCase() == searchText;
      },
    );

    if (existsAlready) {
      customTokenNotifier.value = null;
      return;
    }

    final tokenInfo = await getTokenInfo(contractAddress: searchText, rpc: rpc);

    if (tokenInfo == null) {
      customTokenNotifier.value = null;
      return;
    }

    final customToken = ERC20Entity(
      name: tokenInfo.name,
      symbol: tokenInfo.symbol,
      decimals: tokenInfo.decimals,
      contractAddress: tokenInfo.contractAddress,
      chainID: rpc.type.chainId,
    );

    assetNotifier.fetchBalanceForToken(customToken);
    imageProvider.fetchImageForToken(customToken);
    customTokenNotifier.value = customToken;
  }

  void onSearchInputChanged() {
    final searchText = searchNotifier.value.trim().toLowerCase();

    if (searchText.isEmpty) {
      filteredAssetsNotifer.value = assetNotifier.tokens.toList();
      return;
    }

    final filteredAssets = assetNotifier.tokens.where(
      (asset) {
        final name = asset.name.toLowerCase().contains(searchText);
        final symbol = asset.symbol.toLowerCase().contains(searchText);
        final address =
            asset.contractAddress.toLowerCase().contains(searchText);

        return name || symbol || address;
      },
    ).toList();

    filteredAssetsNotifer.value = filteredAssets;
  }

  void addToken(ERC20Entity customToken) {
    final savedTokensJson =
        jsonDecode(WebLocalStorage.getItem('tokens') ?? '[]') as List<dynamic>;

    savedTokensJson.add(customToken.toJson());

    WebLocalStorage.setItem('tokens', jsonEncode(savedTokensJson));

    assetNotifier.addToken(customToken);
    customTokenNotifier.value = null;
    searchNotifier.value = '';
  }

  @override
  Widget build(BuildContext context) {
    final balanceNotifer = InheritedAssetProvider.of(context);
    return Shimmer(
      child: NomoDialog(
        scrollabe: true,
        padding: const EdgeInsets.all(24),
        maxWidth: 480,
        widthRatio: 0.9,
        borderRadius: BorderRadius.circular(16),
        elevation: 0.0.ifElse(context.isDark, other: 1),
        border: Border.all(
          color: Colors.white24,
          strokeAlign: BorderSide.strokeAlignInside,
          width: 1,
        ).ifElseNull(context.isDark),
        titleStyle: context.typography.h2,
        leading: NomoText(
          "Select Asset",
          style: context.typography.h1,
        ),
        backgroundColor: context.colors.background3,
        content: Column(
          children: [
            8.vSpacing,
            NomoInput(
              titleStyle: context.typography.h2,
              placeHolder: "Search name or paste address",
              placeHolderStyle: context.typography.b2,
              height: 64,
              valueNotifier: searchNotifier,
              maxLines: 1,
              scrollable: true,
              keyboardType: TextInputType.text,
              style: context.typography.b2,
            ),
            32.vSpacing,
            Row(
              children: [
                NomoText(
                  "Name",
                  style: context.typography.b1,
                ),
                const Spacer(),
                const SecondaryNomoButton(
                  icon: Icons.sort,
                  backgroundColor: Colors.transparent,
                  border: Border.fromBorderSide(BorderSide.none),
                )
              ],
            ),
            const NomoDivider(),
            ListenableBuilder(
              listenable: Listenable.merge([
                filteredAssetsNotifer,
                customTokenNotifier,
              ]),
              builder: (context, child) {
                final assets = filteredAssetsNotifer.value;
                final customToken = customTokenNotifier.value;

                final length = customToken == null ? assets.length : 1;

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: length,
                  primary: false,
                  itemBuilder: (context, index) {
                    if (customToken != null) {
                      final balanceListenable =
                          balanceNotifer.balanceNotifierForToken(customToken);
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).pop(customToken);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            height: 56,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                12.hSpacing,
                                AssetPicture(
                                  token: customToken,
                                  size: 32,
                                ),
                                12.hSpacing,
                                Expanded(
                                  child: NomoText(
                                    customToken.name,
                                    style: context.typography.b2,
                                    maxLines: 1,
                                    fit: true,
                                  ),
                                ),
                                12.hSpacing,
                                ListenableBuilder(
                                  listenable: Listenable.merge([
                                    balanceListenable,
                                    assetNotifier.addressNotifier,
                                  ]),
                                  builder: (context, child) {
                                    final value = balanceListenable.value;
                                    final hasAddress =
                                        assetNotifier.addressNotifier.value !=
                                            null;
                                    if (!hasAddress) {
                                      return SizedBox.shrink();
                                    }
                                    return value.when(
                                      data: (value) {
                                        return NomoText(
                                          value.displayDouble
                                              .toStringAsPrecision(5),
                                          style: context.typography.b1,
                                        );
                                      },
                                      error: (error) => NomoText(
                                        "Error",
                                        style: context.typography.h1,
                                      ),
                                      loading: () => ShimmerLoading(
                                        isLoading: true,
                                        child: Container(
                                          width: 64,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            color: context.colors.background2,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                12.hSpacing,
                                PrimaryNomoButton(
                                  height: 42,
                                  width: 42,
                                  padding: EdgeInsets.zero,
                                  icon: Icons.add,
                                  shape: BoxShape.circle,
                                  onPressed: () => addToken(customToken),
                                ),
                                12.hSpacing,
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    final asset = assets[index];
                    final balanceListenable =
                        balanceNotifer.balanceNotifierForToken(asset);
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).pop(asset);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          height: 56,
                          child: Row(
                            children: [
                              12.hSpacing,
                              AssetPicture(
                                token: asset,
                                size: 32,
                              ),
                              12.hSpacing,
                              Expanded(
                                child: NomoText(
                                  asset.name,
                                  style: context.typography.b2,
                                  maxLines: 1,
                                  fit: true,
                                ),
                              ),
                              12.hSpacing,
                              ListenableBuilder(
                                listenable: Listenable.merge([
                                  balanceListenable,
                                  assetNotifier.addressNotifier,
                                ]),
                                builder: (context, child) {
                                  final value = balanceListenable.value;
                                  final hasAddress =
                                      assetNotifier.addressNotifier.value !=
                                          null;
                                  if (!hasAddress) {
                                    return SizedBox.shrink();
                                  }
                                  return value.when(
                                    data: (value) {
                                      return NomoText(
                                        value.displayDouble
                                            .toStringAsPrecision(5),
                                        style: context.typography.b1,
                                      );
                                    },
                                    error: (error) => NomoText(
                                      "Error",
                                      style: context.typography.h1,
                                    ),
                                    loading: () => ShimmerLoading(
                                      isLoading: true,
                                      child: Container(
                                        width: 64,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          color: context.colors.background2,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              12.hSpacing,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            )
          ],
        ),
      ),
    );
  }
}
