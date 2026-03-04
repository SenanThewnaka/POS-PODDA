
import 'dart:math';

class BarcodeUtils {
  // Generates a store-unique barcode.
  // Format: 2 (Internal Prefix) + ShopHash (3 digits) + Random (8 digits)
  // Total length: 12 digits (compatible with EAN-13 generators if check digit added, but here just raw string)
  static String generateStoreBarcode(String? shopId) {
    // Default to '999' if no shopId provided (fallback)
    final safeShopId = shopId ?? "999";
    
    // Hash Shop ID to get a 3-digit store prefix
    // ABS hash code, padded to 3 digits, take last 3 or first 3.
    // We want it deterministic for a shop but unique across shops.
    final shopHash = safeShopId.hashCode.abs().toString().padRight(3, '0').substring(0, 3);
    
    // Random 8 digits using simplified timestamp + random
    // Using microseconds ensures better entropy than milliseconds if called rapidly
    final timestamp = DateTime.now().microsecondsSinceEpoch.toString();
    // take last 8 digits of timestamp. It's usually long enough. 
    // If timestamp is not random enough, we can add Random().
    
    // Better strategy for 8 digits:
    // 4 digits from Random + 4 digits from Timestamp tail
    final rng = Random();
    final rand4 = (rng.nextInt(9000) + 1000).toString(); // 1000-9999
    final time4 = timestamp.substring(timestamp.length - 4);
    
    return "2$shopHash$rand4$time4";
  }
}
