import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Handles the in-app rating prompt logic
// Asks after 10th sale, max once every 90 days
class RatingService {
  static const _saleCountKey = 'completed_sale_count';
  static const _lastPromptKey = 'last_rating_prompt_ms';
  static const _hasReviewedKey = 'has_been_prompted_for_review';

  static final InAppReview _review = InAppReview.instance;

  // Call this every time a sale completes
  static Future<void> onSaleCompleted() async {
    final prefs = await SharedPreferences.getInstance();

    // Don't bug them again if they already got the prompt
    if (prefs.getBool(_hasReviewedKey) == true) return;

    final count = (prefs.getInt(_saleCountKey) ?? 0) + 1;
    await prefs.setInt(_saleCountKey, count);

    // Only trigger on exactly the 10th sale
    if (count != 10) return;

    // Check cooldown (90 days)
    final lastPrompt = prefs.getInt(_lastPromptKey) ?? 0;
    final daysSince = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(lastPrompt))
        .inDays;

    if (lastPrompt != 0 && daysSince < 90) return;

    if (await _review.isAvailable()) {
      await _review.requestReview();
      await prefs.setInt(_lastPromptKey, DateTime.now().millisecondsSinceEpoch);
      await prefs.setBool(_hasReviewedKey, true);
    }
  }

  // For testing - resets the counter
  static Future<void> debugReset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_saleCountKey);
    await prefs.remove(_lastPromptKey);
    await prefs.remove(_hasReviewedKey);
  }
}
