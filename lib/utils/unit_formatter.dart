class UnitFormatter {
  // Formats a quantity based on the base unit logic (Big Tank Strategy).
  // [quantity]: The raw amount stored in db (e.g. 1500 for 1.5kg).
  // [baseUnit]: 'g', 'ml', 'cm', or null for 'unit'.
  static String format(double quantity, String? baseUnit) {
    if (baseUnit == null || baseUnit == 'unit') {
      return "${quantity.toStringAsFixed(0)} Units";
    }

    if (baseUnit == 'g') {
      return _formatWeight(quantity);
    } else if (baseUnit == 'ml') {
      return _formatVolume(quantity);
    } else if (baseUnit == 'cm') {
      return _formatLength(quantity);
    }

    return "${quantity.toStringAsFixed(2)} $baseUnit";
  }

  static String _formatWeight(double grams) {
    if (grams >= 1000) {
      double kg = grams / 1000;
      double remainingGrams = grams % 1000;
      if (remainingGrams > 0) {
         return "${kg.floor()}kg ${remainingGrams.toStringAsFixed(0)}g";
      }
      return "${kg.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '')}kg";
    }
    return "${grams.toStringAsFixed(0)}g";
  }

  static String _formatVolume(double ml) {
    if (ml >= 1000) {
      double liters = ml / 1000;
      double remainingMl = ml % 1000;
      if (remainingMl > 0) {
        return "${liters.floor()}L ${remainingMl.toStringAsFixed(0)}ml";
      }
      return "${liters.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '')}L";
    }
    return "${ml.toStringAsFixed(0)}ml";
  }

  static String _formatLength(double cm) {
    if (cm >= 100) {
      double meters = cm / 100;
      double remainingCm = cm % 100;
      if (remainingCm > 0) {
        return "${meters.floor()}m ${remainingCm.toStringAsFixed(0)}cm";
      }
      return "${meters.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '')}m";
    }
    return "${cm.toStringAsFixed(0)}cm";
  }
}
