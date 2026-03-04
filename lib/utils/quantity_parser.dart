class QuantityParser {
  // Parses a natural language quantity string into the Base Unit amount.
  // [input]: "1kg 500g", "2.5 L", "5 feet".
  // [baseUnit]: 'g', 'ml', 'cm'.
  // Returns the total quantity in the base unit (e.g. 1500.0).
  static double parse(String input, String baseUnit) {
    if (input.isEmpty) return 0;
    
    String cleanInput = input.toLowerCase().replaceAll(',', ' ').replaceAll('  ', ' ');
    double total = 0;

    // RegEx patterns for different units
    
    // WEIGHT (Base: g)
    if (baseUnit == 'g') {
      total += _extractValue(cleanInput, RegExp(r'(\d+(\.\d+)?)\s*kg')) * 1000;
      total += _extractValue(cleanInput, RegExp(r'(\d+(\.\d+)?)\s*g\b')); // \b to avoid matching kg
    }
    
    // VOLUME (Base: ml)
    else if (baseUnit == 'ml') {
      total += _extractValue(cleanInput, RegExp(r'(\d+(\.\d+)?)\s*l\b')) * 1000; // L
      total += _extractValue(cleanInput, RegExp(r'(\d+(\.\d+)?)\s*liters?')) * 1000; 
      total += _extractValue(cleanInput, RegExp(r'(\d+(\.\d+)?)\s*ml'));
    }
    
    // LENGTH (Base: cm)
    else if (baseUnit == 'cm') {
      total += _extractValue(cleanInput, RegExp(r'(\d+(\.\d+)?)\s*m\b')) * 100; // Meters
      total += _extractValue(cleanInput, RegExp(r'(\d+(\.\d+)?)\s*meters?')) * 100; 
      total += _extractValue(cleanInput, RegExp(r'(\d+(\.\d+)?)\s*cm'));
      
      // Feet & Inches support (1 ft = 30.48 cm)
      total += _extractValue(cleanInput, RegExp(r'(\d+(\.\d+)?)\s*ft')) * 30.48;
      total += _extractValue(cleanInput, RegExp(r'(\d+(\.\d+)?)\s*feet')) * 30.48;
      total += _extractValue(cleanInput, RegExp(r'(\d+(\.\d+)?)\s*inch(es)?')) * 2.54;
    }

    // Fallback: If no units found, assume user typed raw number for base unit? 
    // Or maybe they typed "1.5" implying main unit (Kg/L/M)?
    // Let's assume if it's just a number, it's the MAIN UNIT (e.g. 1.5 -> 1.5kg -> 1500g)
    // ONLY if the regex didn't match anything.
    if (total == 0) {
      double? raw = double.tryParse(cleanInput.trim());
      if (raw != null) {
         if (baseUnit == 'g' || baseUnit == 'ml') return raw * 1000;
         if (baseUnit == 'cm') return raw * 100;
      }
    }

    return total;
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
