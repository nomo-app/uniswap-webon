import 'package:flutter_test/flutter_test.dart';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/providers/pool_provider.dart';

final rpc = EvmRpcInterface(
  type: ZeniqSmartNetwork,
  useQueuedManager: false,
  clients: [
    EvmRpcClient(zeniqSmartRPCEndpoint),
  ],
);

final factoryNew = UniswapV2Factory(
  rpc: rpc,
  contractAddress: "0x40a4E23Cc9E57161699Fd37c0A4d8bca383325f3",
);

final factoryOld = UniswapV2Factory(
  rpc: rpc,
  contractAddress: "0x7D0cbcE25EaaB8D5434a53fB3B42077034a9bB99",
);

void main() {
  test('Get All Pairs Length New', () async {
    final length =
        await factoryNew.allPairsLength().then((value) => value.toInt());

    final pairs = await Future.wait([
      for (int i = 0; i < length; i++)
        factoryNew
            .allPairs(i.toBigInt)
            .then(
              (contractAddress) => UniswapV2Pair(
                rpc: rpc,
                contractAddress: contractAddress,
              ),
            )
            .then(
              (pair) => PairInfo.fromPair(pair, allowEntering: true),
            ),
    ]);

    print(length);
    print(pairs);
  });

  test('Get All Pairs Length Old', () async {
    final length =
        await factoryOld.allPairsLength().then((value) => value.toInt());

    final pairs = await Future.wait([
      for (int i = 0; i < length; i++)
        factoryOld
            .allPairs(i.toBigInt)
            .then(
              (contractAddress) => UniswapV2Pair(
                rpc: rpc,
                contractAddress: contractAddress,
              ),
            )
            .then(
              (pair) => PairInfo.fromPair(pair, allowEntering: false),
            ),
    ]);

    print(length);
    print(pairs);
  });
}
