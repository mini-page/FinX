class AmountExpressionResult {
  const AmountExpressionResult({
    required this.amount,
    required this.previewAmount,
    required this.isValid,
    required this.hasOperator,
    required this.isComplete,
    required this.displayExpression,
    this.errorText,
  });

  final double amount;
  final double previewAmount;
  final bool isValid;
  final bool hasOperator;
  final bool isComplete;
  final String displayExpression;
  final String? errorText;

  bool get canEvaluate => isValid && isComplete && hasOperator;

  bool get canSubmit => isValid && isComplete && amount > 0;
}

AmountExpressionResult evaluateAmountExpression(String expression) {
  // Extract only the math expression part from the unified query
  final tokens = expression.trim().split(RegExp(r'\s+'));
  final mathTokens = <String>[];
  for (int i = 0; i < tokens.length; i++) {
    final token = tokens[i];
    if (token.isEmpty) continue;
    if (token.startsWith('@') ||
        token.startsWith('/') ||
        token.startsWith('#') ||
        (token.startsWith('+') && !RegExp(r'^\d').hasMatch(token.substring(1))) ||
        token.startsWith('!')) {
      continue;
    }
    // If it is a math token or at the start
    final isMath = RegExp(r'^[\d\.\+\-\*\/x]+$').hasMatch(token);
    if (i == 0 || isMath) {
      mathTokens.add(token);
    } else {
      break;
    }
  }
  final source = mathTokens.join('');

  if (source.isEmpty) {
    return const AmountExpressionResult(
      amount: 0,
      previewAmount: 0,
      isValid: false,
      hasOperator: false,
      isComplete: false,
      displayExpression: '0',
      errorText: 'Enter an amount.',
    );
  }

  final buffer = StringBuffer();
  double runningTotal = 0;
  String currentNumber = '';
  String? pendingOperator;
  bool hasOperator = false;

  bool commitCurrentNumber() {
    if (currentNumber.isEmpty || currentNumber == '.') {
      return false;
    }
    final parsed = double.tryParse(currentNumber);
    if (parsed == null) {
      return false;
    }
    if (pendingOperator == null) {
      runningTotal = parsed;
    } else if (pendingOperator == '+') {
      runningTotal += parsed;
    } else if (pendingOperator == '-') {
      runningTotal -= parsed;
    } else if (pendingOperator == '*' || pendingOperator == 'x') {
      runningTotal *= parsed;
    } else if (pendingOperator == '/') {
      if (parsed == 0) {
        return false;
      }
      runningTotal /= parsed;
    }
    currentNumber = '';
    return true;
  }

  for (var index = 0; index < source.length; index++) {
    final char = source[index];
    final isDigit = char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57;
    if (isDigit) {
      currentNumber += char;
      buffer.write(char);
      continue;
    }

    if (char == '.') {
      if (currentNumber.contains('.')) {
        return AmountExpressionResult(
          amount: 0,
          previewAmount: runningTotal,
          isValid: false,
          hasOperator: hasOperator,
          isComplete: false,
          displayExpression: _formatExpressionForDisplay(source),
          errorText: 'Each number can only have one decimal point.',
        );
      }
      currentNumber = currentNumber.isEmpty ? '0.' : '$currentNumber.';
      buffer.write(char);
      continue;
    }

    if (char == '+' || char == '-' || char == '*' || char == '/' || char == 'x') {
      if (!commitCurrentNumber()) {
        return AmountExpressionResult(
          amount: 0,
          previewAmount: runningTotal,
          isValid: false,
          hasOperator: hasOperator,
          isComplete: false,
          displayExpression: _formatExpressionForDisplay(source),
          errorText: 'Fix the math expression before continuing.',
        );
      }
      pendingOperator = char;
      hasOperator = true;
      buffer.write(' $char ');
      continue;
    }

    return AmountExpressionResult(
      amount: 0,
      previewAmount: runningTotal,
      isValid: false,
      hasOperator: hasOperator,
      isComplete: false,
      displayExpression: _formatExpressionForDisplay(source),
      errorText: 'Only numbers, ".", "+", "-", "*", and "/" are allowed.',
    );
  }

  if (pendingOperator != null && currentNumber.isEmpty) {
    return AmountExpressionResult(
      amount: runningTotal,
      previewAmount: runningTotal,
      isValid: false,
      hasOperator: hasOperator,
      isComplete: false,
      displayExpression: _formatExpressionForDisplay(source),
      errorText: 'Complete the math expression.',
    );
  }

  if (!commitCurrentNumber()) {
    return AmountExpressionResult(
      amount: 0,
      previewAmount: runningTotal,
      isValid: false,
      hasOperator: hasOperator,
      isComplete: false,
      displayExpression: _formatExpressionForDisplay(source),
      errorText: 'Fix the math expression before continuing.',
    );
  }

  if (runningTotal <= 0) {
    return AmountExpressionResult(
      amount: runningTotal,
      previewAmount: runningTotal,
      isValid: false,
      hasOperator: hasOperator,
      isComplete: true,
      displayExpression: _formatExpressionForDisplay(source),
      errorText: 'Amount must stay above zero.',
    );
  }

  return AmountExpressionResult(
    amount: runningTotal,
    previewAmount: runningTotal,
    isValid: true,
    hasOperator: hasOperator,
    isComplete: true,
    displayExpression: buffer.isEmpty ? '0' : buffer.toString(),
  );
}

String normalizeAmountSeed(double? amount) {
  if (amount == null || amount <= 0) {
    return '0';
  }
  return formatAmountExpressionValue(amount);
}

String formatAmountExpressionValue(double amount) {
  if (amount.truncateToDouble() == amount) {
    return amount.toStringAsFixed(0);
  }
  return amount.toString();
}

String _formatExpressionForDisplay(String expression) {
  return expression
      .replaceAll('+', ' + ')
      .replaceAll('-', ' - ')
      .replaceAll('*', ' * ')
      .replaceAll('/', ' / ')
      .replaceAll('x', ' x ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
