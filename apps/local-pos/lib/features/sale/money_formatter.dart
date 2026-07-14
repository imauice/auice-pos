class MoneyFormatter {
  static String formatMinor(int minor) {
    final negative = minor < 0;
    final absolute = negative ? -minor : minor;
    final whole = absolute ~/ 100;
    final fraction = (absolute % 100).toString().padLeft(2, '0');
    return '${negative ? '-' : ''}$whole.$fraction';
  }
}

String money(int minor) => MoneyFormatter.formatMinor(minor);
