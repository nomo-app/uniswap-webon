import 'package:flutter_test/flutter_test.dart';
import 'package:zeniq_swap_frontend/common/token_repository.dart';

void main() {
  test(
    "Fetch Fixed Tokens",
    () async {
      final fixedTokens = await TokenRepository.fetchFixedTokens();

      expect(fixedTokens, isNotEmpty);
    },
  );
}
