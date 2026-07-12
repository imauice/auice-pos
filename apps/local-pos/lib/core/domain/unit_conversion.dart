class UnitConversion {
  static int toBaseMinor({
    required int quantityMinor,
    required int quantityScale,
    required int conversionNumerator,
    required int conversionDenominator,
    required int baseQuantityScale,
  }) {
    if (quantityMinor <= 0 ||
        quantityScale <= 0 ||
        conversionNumerator <= 0 ||
        conversionDenominator <= 0 ||
        baseQuantityScale <= 0) {
      throw ArgumentError(
        'Quantity and conversion values must be positive integers',
      );
    }
    final dividend = quantityMinor * conversionNumerator * baseQuantityScale;
    final divisor = quantityScale * conversionDenominator;
    if (dividend % divisor != 0) {
      throw StateError(
        'Conversion result cannot be represented exactly at the configured scale',
      );
    }
    return dividend ~/ divisor;
  }

  static int signedForMovement(String type, int absoluteBaseMinor) {
    if (absoluteBaseMinor <= 0) throw ArgumentError.value(absoluteBaseMinor);
    const negative = {'sale', 'adjustment_out', 'transfer_out', 'waste'};
    const positive = {
      'opening',
      'purchase',
      'sale_void',
      'return',
      'adjustment_in',
      'transfer_in',
    };
    if (negative.contains(type)) return -absoluteBaseMinor;
    if (positive.contains(type)) return absoluteBaseMinor;
    throw ArgumentError.value(type, 'type', 'Unknown movement type');
  }
}
