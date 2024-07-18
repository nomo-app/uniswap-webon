// ignore_for_file: avoid_print

import 'dart:typed_data';

import 'package:dotenv/dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/providers/swap_provider.dart';

void main() {
  final seed = loadFromEnv("REJECT_SEED");
  final pk = derivePrivateKeyETH(seed);
  final swapProvider = SwapProvider(
    rejectEVM,
    (tx) async {
      return InternalEVMTransaction.signTransaction(
        RawEVMTransaction.fromHex(tx),
        pk,
      ).serializedTransactionHex;
    },
  );

  test('Get Swapinfo Zeniq / Token', () async {
    swapProvider.setFromToken(zeniqSmart);
    expect(swapProvider.fromToken.value, zeniqSmart);

    swapProvider.setToToken(avinocZSC);
    expect(swapProvider.toToken.value, avinocZSC);

    swapProvider.fromAmountString.value = "1";
    expect(
      swapProvider.fromAmount.value,
      Amount.convert(value: 1, decimals: 18),
    );

    expect(swapProvider.swapType, SwapType.ExactZeniqForToken);

    // await swapProvider.swapInfoCompleter?.future;

    expect(swapProvider.swapType, SwapType.ExactZeniqForToken);

    expect(swapProvider.swapInfo.value.runtimeType, FromSwapInfo);

    print(swapProvider.swapInfo.value);

    swapProvider.toAmountString.value = "1";
    expect(
      swapProvider.toAmount.value,
      Amount.convert(value: 1, decimals: 18),
    );

    expect(swapProvider.swapType, SwapType.ZeniqForExactToken);

    //   await swapProvider.swapInfoCompleter?.future;

    expect(swapProvider.swapType, SwapType.ZeniqForExactToken);

    expect(swapProvider.swapInfo.value.runtimeType, ToSwapInfo);

    print(swapProvider.swapInfo.value);
  });

  test('Get Swapinfo Token / Zeniq', () async {
    swapProvider.setFromToken(avinocZSC);
    expect(swapProvider.fromToken.value, avinocZSC);

    swapProvider.setToToken(zeniqSmart);
    expect(swapProvider.toToken.value, zeniqSmart);

    swapProvider.fromAmountString.value = "1";
    expect(
      swapProvider.fromAmount.value,
      Amount.convert(value: 1, decimals: 18),
    );

    expect(swapProvider.swapType, SwapType.ExactTokenForZeniq);

    //   await swapProvider.swapInfoCompleter?.future;

    expect(swapProvider.swapType, SwapType.ExactTokenForZeniq);

    expect(swapProvider.swapInfo.value.runtimeType, FromSwapInfo);

    print(swapProvider.swapInfo.value);

    swapProvider.toAmountString.value = "1";
    expect(
      swapProvider.toAmount.value,
      Amount.convert(value: 1, decimals: 18),
    );

    expect(swapProvider.swapType, SwapType.TokenForExactZeniq);

    //    await swapProvider.swapInfoCompleter?.future;

    expect(swapProvider.swapType, SwapType.TokenForExactZeniq);

    expect(swapProvider.swapInfo.value.runtimeType, ToSwapInfo);

    print(swapProvider.swapInfo.value);
  });

  test('Get Swapinfo Token / Token', () async {
    swapProvider.setFromToken(avinocZSC);
    expect(swapProvider.fromToken.value, avinocZSC);

    swapProvider.setToToken(iLoveSafirToken);
    expect(swapProvider.toToken.value, iLoveSafirToken);

    swapProvider.fromAmountString.value = "1";
    expect(
      swapProvider.fromAmount.value,
      Amount.convert(value: 1, decimals: 18),
    );

    expect(swapProvider.swapType, SwapType.ExactTokenForToken);

    //    await swapProvider.swapInfoCompleter?.future;

    expect(swapProvider.swapType, SwapType.ExactTokenForToken);

    expect(swapProvider.swapInfo.value.runtimeType, FromSwapInfo);

    print(swapProvider.swapInfo.value);

    swapProvider.toAmountString.value = "1";
    expect(
      swapProvider.toAmount.value,
      Amount.convert(value: 1, decimals: 18),
    );

    expect(swapProvider.swapType, SwapType.TokenForExactToken);

    //    await swapProvider.swapInfoCompleter?.future;

    expect(swapProvider.swapType, SwapType.TokenForExactToken);

    expect(swapProvider.swapInfo.value.runtimeType, ToSwapInfo);

    print(swapProvider.swapInfo.value);
  });

  test(
    "Swap Zeniq Token to Avinoc (SwapExactZeniqForToken)",
    () async {
      swapProvider.setFromToken(zeniqSmart);
      expect(swapProvider.fromToken.value, zeniqSmart);

      swapProvider.setToToken(avinocZSC);
      expect(swapProvider.toToken.value, avinocZSC);

      swapProvider.fromAmountString.value = "1";
      expect(
        swapProvider.fromAmount.value,
        Amount.convert(value: 1, decimals: 18),
      );

      expect(swapProvider.swapType, SwapType.ExactZeniqForToken);
      //    await swapProvider.swapInfoCompleter?.future;

      expect(swapProvider.toAmount.value, isNotNull);

      final hash = await swapProvider.swap();

      print(hash);

      expect(swapProvider.swapState.value, SwapState.Swapped);
    },
  );

  test(
    "Swap Avinoc Token to Zeniq Token (SwapExactTokenForZeniq)",
    () async {
      swapProvider.setFromToken(avinocZSC);
      expect(swapProvider.fromToken.value, avinocZSC);

      swapProvider.setToToken(zeniqSmart);
      expect(swapProvider.toToken.value, zeniqSmart);

      swapProvider.fromAmountString.value = "1";
      expect(
        swapProvider.fromAmount.value,
        Amount.convert(value: 1, decimals: 18),
      );

      expect(swapProvider.swapType, SwapType.ExactTokenForZeniq);
      //    await swapProvider.swapInfoCompleter?.future;

      expect(swapProvider.toAmount.value, isNotNull);

      final hash = await swapProvider.swap();

      print(hash);

      expect(swapProvider.swapState.value, SwapState.Swapped);
    },
  );

  test(
    "Swap Avinoc Token to Safir Token (SwapExactTokenForToken)",
    () async {
      swapProvider.setFromToken(avinocZSC);
      expect(swapProvider.fromToken.value, avinocZSC);

      swapProvider.setToToken(iLoveSafirToken);
      expect(swapProvider.toToken.value, iLoveSafirToken);

      swapProvider.fromAmountString.value = "1";
      expect(
        swapProvider.fromAmount.value,
        Amount.convert(value: 1, decimals: 18),
      );

      expect(swapProvider.swapType, SwapType.ExactTokenForToken);
      //   await swapProvider.swapInfoCompleter?.future;

      expect(swapProvider.toAmount.value, isNotNull);

      final hash = await swapProvider.swap();

      print(hash);

      expect(swapProvider.swapState.value, SwapState.Swapped);
    },
  );

  test(
    "Swap Avinoc Token to Zeniq Token (SwapTokenForExactZeniq)",
    () async {
      swapProvider.setFromToken(avinocZSC);
      expect(swapProvider.fromToken.value, avinocZSC);

      swapProvider.setToToken(zeniqSmart);
      expect(swapProvider.toToken.value, zeniqSmart);

      swapProvider.toAmountString.value = "1";
      expect(
        swapProvider.toAmount.value,
        Amount.convert(value: 1, decimals: 18),
      );

      expect(swapProvider.swapType, SwapType.TokenForExactZeniq);
      //    await swapProvider.swapInfoCompleter?.future;

      expect(swapProvider.fromAmount.value, isNotNull);

      final hash = await swapProvider.swap();

      print(hash);

      expect(swapProvider.swapState.value, SwapState.Swapped);
    },
  );

  test(
    "Swap Zeniq Token to Avinoc Token (SwapEthForExactToken)",
    () async {
      swapProvider.setFromToken(zeniqSmart);
      expect(swapProvider.fromToken.value, zeniqSmart);

      swapProvider.setToToken(avinocZSC);
      expect(swapProvider.toToken.value, avinocZSC);

      swapProvider.toAmountString.value = "1";
      expect(
        swapProvider.toAmount.value,
        Amount.convert(value: 1, decimals: 18),
      );

      expect(swapProvider.swapType, SwapType.ZeniqForExactToken);
      //   await swapProvider.swapInfoCompleter?.future;

      expect(swapProvider.fromAmount.value, isNotNull);

      final hash = await swapProvider.swap();

      print(hash);

      expect(swapProvider.swapState.value, SwapState.Swapped);
    },
  );

  test(
    "Swap Safir Token to Avinoc Token (SwapTokenForExactToken)",
    () async {
      swapProvider.setFromToken(iLoveSafirToken);
      expect(swapProvider.fromToken.value, iLoveSafirToken);

      swapProvider.setToToken(avinocZSC);
      expect(swapProvider.toToken.value, avinocZSC);

      swapProvider.toAmountString.value = "1";
      expect(
        swapProvider.toAmount.value,
        Amount.convert(value: 1, decimals: 18),
      );

      expect(swapProvider.swapType, SwapType.TokenForExactToken);
      //    await swapProvider.swapInfoCompleter?.future;

      expect(swapProvider.fromAmount.value, isNotNull);

      final hash = await swapProvider.swap();

      print(hash);

      expect(swapProvider.swapState.value, SwapState.Swapped);
    },
  );
}

Uint8List loadFromEnv(String envName) {
  final env = DotEnv(includePlatformEnvironment: true)..load();
  final seedString = env[envName]!.split(",");
  final intList = seedString.map(int.parse).toList();
  return Uint8List.fromList(intList);
}
