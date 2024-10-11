import 'package:collection/collection.dart';

enum Currency {
  usd('US Dollar', '\$'),
  eur('Euro', '€');
  // gbp,
  // chf;

  final String displayName;
  final String symbol;

  const Currency(this.displayName, this.symbol);

  @override
  String toString() => name;

  static Currency? fromString(String cur) =>
      Currency.values.singleWhereOrNull((element) => element.name == cur);
}
