import 'package:location_ui/services/auth_service.dart';

// const baseUrl = "http://192.168.1.2:3000/";
const baseUrl= "https://location-ws-1.onrender.com/";

const sendOtpUrl = "${AuthService.baseTokenUrl}login/auth/send-otp";
const verifyOtpUrl = "${AuthService.baseTokenUrl}login/auth/verify-otp";
const resendOtpUrl = "${AuthService.baseTokenUrl}login/auth/resend-otp";
const validateTokenUrl = "${AuthService.baseTokenUrl}login/auth/validate-token";

const trackUrl = "${AuthService.baseTokenUrl}location/track";

String getDailyLocationSummaryURl(DateTime date) {
  // Format date for the backend query parameter (YYYY-MM-DD)
  final formattedDate =
      "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  return "${AuthService.baseTokenUrl}location/daily-summary/$formattedDate";
}
