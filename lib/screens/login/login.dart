import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:location_ui/backend_config/config.dart';
import 'package:location_ui/screens/login/otp_verification.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:permission_handler/permission_handler.dart';

import 'package:sms_autofill/sms_autofill.dart'
    if (dart.library.io) 'package:sms_autofill/sms_autofill.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() {
    return _LoginScreenState();
  }
}

class _LoginScreenState extends State<LoginScreen> {
  String? _fullPhoneNumber;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      _requestSmsPermissions();
    }
  }


  Future<void> _sendOtp() async {
    if (_fullPhoneNumber == null || _fullPhoneNumber!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter your mobile number.')),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Sending OTP...')));

    try {
      final response = await http.post(
        Uri.parse(sendOtpUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'phoneNumber': _fullPhoneNumber,
        }), // Send the full international number
      );

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('OTP sent successfully!')));
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) =>
                      OtpVerificationScreen(phoneNumber: _fullPhoneNumber!),
            ),
          );
        }
      } else {
        if (mounted) {
          final errorBody = json.decode(response.body);
          print('OTP send error response: $errorBody'); // <-- Add this line

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to send OTP: ${errorBody['message'] ?? 'Unknown error'}',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Network error: $e')));
        print('Network error sending OTP: $e');
      }
    }
  }

  Future<void> _requestSmsPermissions() async {
  // Check current status of SMS permission
  var smsStatus = await Permission.sms.status;

  if (smsStatus.isGranted) {
    print("SMS permissions already granted.");
    return; // Already granted, no need to do anything
  }

  // If not granted, request it
  if (smsStatus.isDenied || smsStatus.isRestricted) {
    print("SMS permissions currently denied or restricted, requesting...");
    smsStatus = await Permission.sms.request();
  }

  // After requesting, check the final status
  if (smsStatus.isGranted) {
    print("SMS permissions granted after request.");
  } else if (smsStatus.isPermanentlyDenied) {
    print("SMS permissions permanently denied. Please open app settings.");
    // Prompt the user to open settings
    if (mounted) {
      showDialog(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('SMS Permission Required'),
          content: const Text('To auto-fill OTP, please enable SMS permissions in app settings.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Open Settings'),
              onPressed: () {
                openAppSettings(); // Opens app settings
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );
    }
  } else {
    // Other states like isDenied, restricted, or limited after request
    print("SMS permissions not granted after request.");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SMS permission not granted. Auto-fill will not work.')),
      );
    }
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login with Phone Number')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IntlPhoneField(
              decoration: InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
              initialCountryCode: 'IN', 
              onChanged: (phone) {
                 _fullPhoneNumber = phone.completeNumber;
                print('Full Phone Number: $_fullPhoneNumber');
              },
              onCountryChanged: (country) {
                print('Selected country dial code: ${country.dialCode}');
              },
              
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _sendOtp,
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text('Send OTP', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
