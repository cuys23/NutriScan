import 'package:flutter_test/flutter_test.dart';
import 'package:nutriscan/services/ai/ai_response_utils.dart';

void main() {
  group('AiResponseUtils.stripReasoning', () {
    test('leaves clean content untouched', () {
      expect(
        AiResponseUtils.stripReasoning('Try adding more protein at breakfast.'),
        'Try adding more protein at breakfast.',
      );
    });

    test('strips a leaked <think> block and trims the remainder', () {
      const leaked =
          '<think>1. Analyze user input...\n2. Identify key issues...</think>'
          '\n\nTry adding more protein at breakfast.';
      expect(
        AiResponseUtils.stripReasoning(leaked),
        'Try adding more protein at breakfast.',
      );
    });

    test('is case-insensitive and handles a think block mid-string', () {
      const leaked = 'Before <THINK>internal notes</THINK> after.';
      expect(AiResponseUtils.stripReasoning(leaked), 'Before  after.');
    });
  });
}
