class UnitConversion {
  static int toBaseMinor({
    required int quantityMinor,
    required int numerator,
    required int denominator,
  }) {
    if (quantityMinor <= 0 || numerator <= 0 || denominator <= 0) {
      throw ArgumentError(
        'Quantity and conversion values must be positive integers',
      );
    }
    final multiplied = quantityMinor * numerator;
    if (multiplied % denominator != 0) {
      throw StateError(
        'Conversion result cannot be represented exactly at the configured scale',
      );
    }
    return multiplied ~/ denominator;
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
