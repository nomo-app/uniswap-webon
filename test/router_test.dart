import 'package:flutter_test/flutter_test.dart';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/providers/swap_provider.dart';

void main() {
  final rpc = EvmRpcInterface(
    type: ZeniqSmartNetwork,
    clients: [
      EvmRpcClient(zeniqSmartRPCEndpoint),
    ],
  );
  final zeniqSwapRouter = UniswapV2Router(
    rpc: rpc,
    contractAddress: "0x7963c1bd24E4511A0b14bf148F93e2556AFe3C27",
  );

  test('Get Amounts Out', () async {
    final result = await zeniqSwapRouter.getAmountsOut(
      amountIn: Amount.convert(value: 1, decimals: 18).value,
      path: [
        zeniqTokenWrapper.contractAddress,
        avinocZSC.contractAddress,
      ],
    );

    expect(result, isNotEmpty);
    expect(result.length, 2);
    print(result);
  });

  test(
    "Get Amounts In",
    () async {
      final result = await zeniqSwapRouter.getAmountsIn(
        amountOut: Amount.convert(value: 1, decimals: 18).value,
        path: [
          zeniqTokenWrapper.contractAddress,
          avinocZSC.contractAddress,
        ],
      );
      expect(result, isNotEmpty);
      expect(result.length, 2);
      print(result);
    },
  );
}
