
import 'dart:convert';
import 'package:http/http.dart' as http;

class VerificationService {
  // Your Function URL
  static const String _apiUrl = "https://us-central1-synthora-web.cloudfunctions.net/sendVerificationCode";

  /// Sends a verification code to the specified email.
  /// Returns [true] if successful, [false] otherwise.
  static Future<bool> sendCode(String email, String code) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "email": email,
          "code": code,
        }),
      );

      if (response.statusCode == 200) {
        print("✅ Code sent successfully!");
        return true;
      } else {
        print("❌ Failed to send code: ${response.body}");
        return false;
      }
    } catch (e) {
      print("💥 Error: $e");
      return false;
    }
  }
}
