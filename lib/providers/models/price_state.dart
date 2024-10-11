import 'package:zeniq_swap_frontend/providers/models/currency.dart';
import 'package:zeniq_swap_frontend/providers/models/pair_info.dart';

class PriceState {
  final double? priceLegacy;
  final double? price;

  double getPriceForType(PairType type) => switch (type) {
        PairType.legacy => priceLegacy!,
        PairType.v2 => price!,
      };

  final Currency currency;

  const PriceState({
    required this.price,
    required this.currency,
    required this.priceLegacy,
  }) : assert(price != null || priceLegacy != null);
}
