// lib/services/auth_service.dart
import 'package:location_ui/backend_config/config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class AuthService {
  static const String _tokenKey = 'jwt_token';
  static const String baseTokenUrl = baseUrl;


  static Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    print('AuthService: Token set in SharedPreferences.'); // DEBUG PRINT
  }

  // Retrieve JWT token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    print('AuthService: Retrieved token from SharedPreferences: $token'); // DEBUG PRINT
    return token;
  }

  // Remove JWT token (logout)
  static Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
     print('AuthService: Token removed from SharedPreferences.'); 
  }

  // Validate token with backend
  static Future<bool> validateToken() async {
    final token = await getToken();
    if (token == null) {
       print('AuthService: No token found for validation.'); 
      return false; // No token found
    }

    try {
      final response = await http.post(
        Uri.parse(validateTokenUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // Token is valid
        return true;
      } else {
        // Token invalid or expired, remove it
        await removeToken();
        return false;
      }
    } catch (e) {
      print('Error validating token: $e');
      await removeToken(); // Remove token on network error or other issues
      return false;
    }
  }
}
