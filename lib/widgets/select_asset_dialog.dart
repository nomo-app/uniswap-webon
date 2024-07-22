import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
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
import 'package:zeniq_swap_frontend/pages/home.dart';
import 'package:zeniq_swap_frontend/providers/asset_notifier.dart';
import 'package:zeniq_swap_frontend/providers/swap_provider.dart';

class SelectAssetDialog extends StatefulWidget {
  const SelectAssetDialog({super.key});

  @override
  State<SelectAssetDialog> createState() => _SelectAssetDialogState();
}

class _SelectAssetDialogState extends State<SelectAssetDialog> {
  late final ValueNotifier<String> searchNotifier = ValueNotifier('');
  late final ValueNotifier<EthBasedTokenEntity?> customTokenNotifier =
      ValueNotifier(null);

  late ValueNotifier<List<TokenEntity>> filteredAssetsNotifer;
  late AssetNotifier assetNotifier;

  @override
  void didChangeDependencies() {
    assetNotifier = InheritedAssetProvider.of(context);
    filteredAssetsNotifer = ValueNotifier(assetNotifier.tokens);
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
        return token is EthBasedTokenEntity &&
            token.contractAddress.toLowerCase() == searchText;
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

    final customToken = EthBasedTokenEntity(
      name: tokenInfo.name,
      symbol: tokenInfo.symbol,
      decimals: tokenInfo.decimals,
      contractAddress: tokenInfo.contractAddress,
      chainID: rpc.type.chainId,
    );

    assetNotifier.addPreviewToken(customToken);
    customTokenNotifier.value = customToken;
  }

  void onSearchInputChanged() {
    final searchText = searchNotifier.value.trim().toLowerCase();

    if (searchText.isEmpty) {
      filteredAssetsNotifer.value = assetNotifier.tokens;
      return;
    }

    final filteredAssets = assetNotifier.tokens.where(
      (asset) {
        final name = asset.name.toLowerCase().contains(searchText);
        final symbol = asset.symbol.toLowerCase().contains(searchText);
        final address = asset is EthBasedTokenEntity
            ? asset.contractAddress.toLowerCase().contains(searchText)
            : false;

        return name || symbol || address;
      },
    ).toList();

    filteredAssetsNotifer.value = filteredAssets;
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
        titleStyle: context.typography.h2,
        leading: NomoText(
          "Select Asset",
          style: context.typography.h2,
        ),
        backgroundColor: context.colors.background3,
        content: SingleChildScrollView(
          child: Column(
            children: [
              NomoInput(
                titleStyle: context.typography.h2,
                placeHolder: "Search name or paste address",
                placeHolderStyle: context.typography.b3,
                height: 64,
                valueNotifier: searchNotifier,
                maxLines: 1,
                scrollable: true,
                keyboardType: TextInputType.text,
                style: context.typography.b3,
              ),
              32.vSpacing,
              const Row(
                children: [
                  NomoText("Name"),
                  Spacer(),
                  SecondaryNomoButton(
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
                    itemBuilder: (context, index) {
                      if (customToken != null) {
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
                                children: [
                                  12.hSpacing,
                                  AssetPicture(
                                    token: customToken,
                                    size: 32,
                                  ),
                                  12.hSpacing,
                                  Column(
                                    children: [
                                      NomoText(
                                        customToken.name,
                                        style: context.typography.h1,
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  PrimaryNomoButton(
                                    height: 42,
                                    width: 42,
                                    padding: EdgeInsets.zero,
                                    icon: Icons.add,
                                    shape: BoxShape.circle,
                                    onPressed: () {
                                      assetNotifier.addToken(customToken);
                                      customTokenNotifier.value = null;
                                      searchNotifier.value = '';
                                    },
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
                          balanceNotifer.notifierForToken(asset);
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
                                NomoText(
                                  asset.name,
                                  style: context.typography.h1,
                                ),
                                const Spacer(),
                                ValueListenableBuilder(
                                  valueListenable: balanceListenable,
                                  builder: (context, value, child) {
                                    return value.when(
                                      data: (value) {
                                        return NomoText(
                                          value.displayDouble
                                              .toStringAsPrecision(5),
                                          style: context.typography.b2,
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
      ),
    );
  }
}
