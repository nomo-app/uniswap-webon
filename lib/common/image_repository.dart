import 'dart:async';
import 'dart:convert';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/common/http_client.dart';
import 'package:zeniq_swap_frontend/common/logger.dart';
import 'package:zeniq_swap_frontend/common/price_repository.dart';

class ImageEntity {
  final String thumb;
  final String small;
  final String large;
  final bool isPending;

  const ImageEntity({
    required this.thumb,
    required this.small,
    required this.large,
    this.isPending = false,
  });

  factory ImageEntity.fromJson(Map<String, dynamic> json) => ImageEntity(
        thumb: json['thumb'] as String,
        small: json['small'] as String,
        large: json['large'] as String,
        isPending: json['isPending'] as bool? ?? false,
      );
}

abstract class ImageRepository {
  static Future<ImageEntity> getImage(TokenEntity token) async {
    final endpoint =
        '$PRICE_ENDPOINT/info/image/${token is EthBasedTokenEntity ? '${token.contractAddress}/${chaindIdMap[token.chainID]}' : PriceRepository.getAssetName(token)}';
    try {
      final result = await (_getImage(endpoint).timeout(REQUEST_TIMEOUT_LIMIT));
      return result;
    } catch (e, s) {
      Logger.logError(
        e,
        hint: "Failed to fetch image from $endpoint",
        s: s,
      );
      rethrow;
    }
  }

  static Future<ImageEntity> _getImage(String endpoint) async {
    Logger.logFetch(
      "Fetch Image from $endpoint",
      "PriceService Image",
    );

    final uri = Uri.parse(endpoint);

    final response = await HTTPService.client.get(
      uri,
      headers: {"Content-Type": "application/json"},
    ).timeout(
      REQUEST_TIMEOUT_LIMIT,
      onTimeout: () => throw TimeoutException("Timeout", REQUEST_TIMEOUT_LIMIT),
    );

    if (response.statusCode != 200) {
      throw Exception(
        "image_repository: Request returned status code ${response.statusCode}",
      );
    }
    final body = jsonDecode(response.body);

    if (body == null && body is! Json) {
      throw Exception(
        "image_repository: Request returned null: $endpoint",
      );
    }

    final image = ImageEntity.fromJson(body);

    if (image.isPending) throw Exception("Image is pending");

    return image;
  }
}
