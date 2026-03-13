/// Utility functions for formatting scores and grades

/// Formats a score value to display decimals only when needed.
/// - 1.5 displays as "1.5"
/// - 3.0 displays as "3"
/// - 2.75 displays as "2.75"
String formatScore(num? score) {
  if (score == null) return '0';

  // Check if it's a whole number
  if (score == score.toInt()) {
    return score.toInt().toString();
  }

  // Otherwise, show with appropriate decimal places (max 2)
  final formatted = score.toStringAsFixed(2);
  // Remove trailing zeros after decimal point
  return formatted.replaceAll(RegExp(r'\.?0+$'), '');
}

/// Formats a score with max score (e.g., "1.5 / 10")
String formatScoreWithMax(num? score, num? maxScore) {
  return '${formatScore(score)} / ${formatScore(maxScore)}';
}
