import 'dart:math';

extension FormatExtension on double {
  String toMaxPrecisionWithoutScientificNotation(int maxPrecision) {
    final double value = this;
    final exact = value.toExactString();
    final zeroCount = _countZeroDigits(exact);
    final nonZeroCount = value >= 1 ? (log(value) / log(10)).ceil() : 1;
    final maxLen = maxPrecision + zeroCount + nonZeroCount;
    if (maxLen < exact.length) {
      return exact.substring(0, maxLen);
    } else {
      return exact;
    }
  }

  double toMaxPrecision(int maxPrecision) {
    return double.parse(toMaxPrecisionWithoutScientificNotation(maxPrecision));
  }

  int _countZeroDigits(String str) {
    int zeroCount = 0;

    if (str.replaceAll("-", "").indexOf('.') > 1) {
      str = str.substring(str.indexOf('.') + 1, str.length);
    }

    for (int i = 0; i < str.length; i++) {
      if (str[i] != "0" && str[i] != "-" && str[i] != "." && str[i] != ",") {
        break;
      }
      zeroCount++;
    }
    return zeroCount;
  }

  String toExactString() {
    // https://stackoverflow.com/questions/62989638/convert-long-double-to-string-without-scientific-notation-dart
    double value = this;
    var sign = "";
    if (value < 0) {
      value = -value;
      sign = "-";
    }
    var string = value.toString();
    var e = string.lastIndexOf('e');
    if (e < 0) return "$sign$string";
    var hasComma = string.indexOf('.') == 1;
    var offset = int.parse(
      string.substring(e + (string.startsWith('-', e + 1) ? 1 : 2)),
    );
    var digits = string.substring(0, 1);

    if (hasComma) {
      digits += string.substring(2, e);
    }

    if (offset < 0) {
      return "${sign}0.${"0" * ~offset}$digits";
    }
    if (offset > 0) {
      if (offset >= digits.length) {
        return sign + digits.padRight(offset + 1, "0");
      }
      return "$sign${digits.substring(0, offset + 1)}"
          ".${digits.substring(offset + 1)}";
    }
    return digits;
  }
}
