import 'package:flutter_test/flutter_test.dart';
import 'package:expensio/features/expense/presentation/screens/add_expense/amount_expression.dart';

void main() {
  group('evaluateAmountExpression', () {
    test('evaluates arithmetic expressions with decimals', () {
      final result = evaluateAmountExpression('120+45.5-10');

      expect(result.isValid, isTrue);
      expect(result.canEvaluate, isTrue);
      expect(result.canSubmit, isTrue);
      expect(result.amount, 155.5);
    });

    test('keeps preview amount for trailing operators', () {
      final result = evaluateAmountExpression('120+');

      expect(result.isValid, isFalse);
      expect(result.previewAmount, 120);
      expect(result.errorText, 'Complete the math expression.');
    });

    test('rejects non-positive totals', () {
      final result = evaluateAmountExpression('40-40');

      expect(result.isValid, isFalse);
      expect(result.amount, 0);
      expect(result.errorText, 'Amount must stay above zero.');
    });
  });

  group('normalizeAmountSeed', () {
    test('uses 0 for empty values', () {
      expect(normalizeAmountSeed(null), '0');
      expect(normalizeAmountSeed(0), '0');
    });

    test('formats whole and decimal numbers for editing', () {
      expect(normalizeAmountSeed(150), '150');
      expect(normalizeAmountSeed(150.5), '150.5');
    });
  });
}
