import 'package:flutter_test/flutter_test.dart';
import 'package:walletkit_dart/walletkit_dart.dart';

void main() {
  final rpc = EvmRpcInterface(ZeniqSmartNetwork);
  final factory = UniswapV2Factory(
    rpc: rpc,
    contractAddress: "0x7D0cbcE25EaaB8D5434a53fB3B42077034a9bB99",
  );

  test('Test UniswapV2Factory', () async {
    const tokenA = wrappedZeniqSmart;
    const tokenB = avinocZSC;
    //const tokenC = tupanToken;

    final pairABAddress = await factory.getPair(
      tokenA: tokenA.contractAddress,
      tokenB: tokenB.contractAddress,
    );

    final pairAB = UniswapV2Pair(
      rpc: rpc,
      contractAddress: pairABAddress,
      token0: tokenA,
      token1: tokenB,
    );

    final priceImpact = await calculatePriceImpactAndSlippage(
      pairAB,
      Amount.convert(value: 10000000, decimals: 18).value,
    );
    print("Price Impact: $priceImpact%");
  });
}

Future<double> calculatePriceImpactAndSlippage(
  UniswapV2Pair pairAB,
  BigInt amountInWrappedZeniq,
) async {
  final reserves = await pairAB.getReserves();

  final reserve1 = reserves.$1.value;
  final reserve2 = reserves.$2.value;

  // Initial price of tokenA in terms of tokenB
  final initialPrice = reserve2 / reserve1;

  // Apply swap fee plus slippage tolerance (0.3 + 0.5)
  final amountInWithFee =
      (amountInWrappedZeniq * BigInt.from(997)) ~/ BigInt.from(1000);

  // Calculate new reserves
  final newReserve1 = reserve1 + amountInWrappedZeniq;

  final amountOut = (amountInWithFee * reserve2) ~/
      (reserve1 * BigInt.from(1000) + amountInWithFee);

  final newReserve2 = reserve2 - amountOut;

  // Calculate new price
  final newPrice = newReserve2 / newReserve1;

  // Compute price impact
  final priceImpact = ((initialPrice - newPrice) / initialPrice) * 100;

  return priceImpact.toDouble();
}
