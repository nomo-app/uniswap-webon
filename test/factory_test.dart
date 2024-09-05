import 'package:flutter_test/flutter_test.dart';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/common/token_repository.dart';
import 'package:zeniq_swap_frontend/providers/swap_provider.dart';

void main() {
  test(
    'Fetch all Tokens which have enough Liquidity',
    () async {
      final fixedTokens = await TokenRepository.fetchFixedTokens();

      final tokens = await TokenRepository.fetchTokensWhereLiquidty(
        allTokens: fixedTokens,
        minZeniqInPool: 10000,
      );

      expect(tokens.length, greaterThanOrEqualTo(4));
      print(tokens);
    },
  );

  test('Test Price Impact Calculation', () async {
    const tokenA = wrappedZeniqSmart;
    const tokenB = avinocZSC;
    const tokenC = tupanToken;

    var priceImpact = await calculatePriceImpact(
      [tokenA, tokenB],
      Amount.convert(value: 10000, decimals: 18).value,
    );

    print("Price Impact: $priceImpact%");

    priceImpact = await calculatePriceImpact(
      [tokenB, tokenA],
      Amount.convert(value: 10000, decimals: 18).value,
    );

    print("Price Impact: $priceImpact%");

    priceImpact = await calculatePriceImpact(
      [tokenA, tokenC],
      Amount.convert(value: 10000, decimals: 18).value,
    );

    print("Price Impact: $priceImpact%");

    priceImpact = await calculatePriceImpact(
      [tokenC, tokenA],
      Amount.convert(value: 10000, decimals: 18).value,
    );

    print("Price Impact: $priceImpact%");

    priceImpact = await calculatePriceImpact(
      [tokenB, tokenA, tokenC],
      Amount.convert(value: 10000, decimals: 18).value,
    );

    print("Price Impact: $priceImpact%");

    priceImpact = await calculatePriceImpact(
      [tokenC, tokenA, tokenB],
      Amount.convert(value: 10000, decimals: 18).value,
    );

    print("Price Impact: $priceImpact%");
  });
}
