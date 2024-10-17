import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/providers/models/pair_info.dart';

class TokenEntity extends ERC20Entity {
  final List<PairType> pairTypes;
  final String? image;

  TokenEntity(
    ERC20Entity entity, {
    required this.pairTypes,
    required this.image,
  }) : super(
          chainID: entity.chainID,
          contractAddress: entity.contractAddress,
          decimals: entity.decimals,
          name: entity.name,
          symbol: entity.symbol,
        );

  @override
  int get hashCode => super.hashCode;

  @override
  Json toJson() {
    return {
      "chainID": chainID,
      "contractAddress": contractAddress,
      "decimals": decimals,
      "name": name,
      "symbol": symbol,
      "pairTypes": pairTypes.map((e) => e.toString()).toList(),
    };
  }

  factory TokenEntity.fromJson(Map<String, dynamic> json) {
    try {
      return TokenEntity(
        ERC20Entity.fromJson(
          json,
          allowDeletion: false,
          chainID: json["chainID"] as int,
        ),
        pairTypes: (json["pairTypes"] as List<dynamic>)
            .map((e) => PairType.fromString(e))
            .toList(),
        image: json["image"] as String?,
      );
    } catch (e) {
      print("token_entity: Error parsing token entity: $e");
      rethrow;
    }
  }
}
