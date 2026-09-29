class QuantityParser {
  // Parses a natural language quantity string into the Base Unit amount.
  // [input]: "1kg 500g", "2.5 L", "500g", "5 feet".
  // [baseUnit]: 'g', 'kg', 'ml', 'l', 'cm', 'm', 'unit'.
  // Returns the total quantity in the product's base unit.
  static double parse(String input, String? baseUnit) {
    if (input.isEmpty) return 0;
    
    final String cleanInput = input.toLowerCase().replaceAll(',', ' ').replaceAll('  ', ' ');
    final String normalizedUnit = (baseUnit ?? 'g').trim().toLowerCase();

    // WEIGHT (Base: g or kg)
    if (normalizedUnit == 'g' || normalizedUnit == 'kg') {
      double grams = 0;
      grams += _extractValue(cleanInput, RegExp(r'(\d+(\.\d+)?)\s*kg')) * 1000;
      grams += _extractValue(cleanInput, RegExp(r'(\d+(\.\d+)?)\s*g\b')); // \b to avoid matching kg

      if (grams > 0) {
        return normalizedUnit == 'kg' ? grams / 1000.0 : grams;
      }

      // Fallback: raw numeric input (e.g. "1.5" or "500")
      final double? raw = double.tryParse(cleanInput.trim());
      if (raw != null) {
        if (normalizedUnit == 'g') {
          // If base is grams, assume small values (< 20) are typed in kg (e.g., 1.5 -> 1500g)
          return raw < 20 ? raw * 1000.0 : raw;
        } else {
          // If base is kg, assume large values (>= 50) were typed in grams (e.g., 500 -> 0.5kg)
          return raw >= 50 ? raw / 1000.0 : raw;
        }
      }
    }
    
    // VOLUME (Base: ml or l)
    else if (normalizedUnit == 'ml' || normalizedUnit == 'l') {
      double ml = 0;
      ml += _extractValue(cleanInput, RegExp(r'(\d+(\.\d+)?)\s*l\b')) * 1000; // L
      ml += _extractValue(cleanInput, RegExp(r'(\d+(\.\d+)?)\s*liters?')) * 1000; 
      ml += _extractValue(cleanInput, RegExp(r'(\d+(\.\d+)?)\s*ml'));

      if (ml > 0) {
        return normalizedUnit == 'l' ? ml / 1000.0 : ml;
      }

      final double? raw = double.tryParse(cleanInput.trim());
      if (raw != null) {
        if (normalizedUnit == 'ml') {
          return raw < 20 ? raw * 1000.0 : raw;
        } else {
          return raw >= 50 ? raw / 1000.0 : raw;
        }
      }
    }
    
    // LENGTH (Base: cm or m)
    else if (normalizedUnit == 'cm' || normalizedUnit == 'm') {
      double cm = 0;
      cm += _extractValue(cleanInput, RegExp(r'(\d+(\.\d+)?)\s*m\b')) * 100; // Meters
      cm += _extractValue(cleanInput, RegExp(r'(\d+(\.\d+)?)\s*meters?')) * 100; 
      cm += _extractValue(cleanInput, RegExp(r'(\d+(\.\d+)?)\s*cm'));
      
      // Feet & Inches support (1 ft = 30.48 cm)
      cm += _extractValue(cleanInput, RegExp(r'(\d+(\.\d+)?)\s*ft')) * 30.48;
      cm += _extractValue(cleanInput, RegExp(r'(\d+(\.\d+)?)\s*feet')) * 30.48;
      cm += _extractValue(cleanInput, RegExp(r'(\d+(\.\d+)?)\s*inch(es)?')) * 2.54;

      if (cm > 0) {
        return normalizedUnit == 'm' ? cm / 100.0 : cm;
      }

      final double? raw = double.tryParse(cleanInput.trim());
      if (raw != null) {
        if (normalizedUnit == 'cm') {
          return raw < 10 ? raw * 100.0 : raw;
        } else {
          return raw;
        }
      }
    }

    // Generic fallback for pure numbers
    final double? raw = double.tryParse(cleanInput.trim());
    if (raw != null) {
      if (normalizedUnit == 'g' || normalizedUnit == 'ml') return raw * 1000.0;
      if (normalizedUnit == 'cm') return raw * 100.0;
      return raw;
    }

    return 0.0;
  }

  static double _extractValue(String input, RegExp patterns) {
    double sum = 0;
    Iterable<RegExpMatch> matches = patterns.allMatches(input);
    for (var match in matches) {
      if (match.group(1) != null) {
        sum += double.parse(match.group(1)!);
      }
    }
    return sum;
  }
}
