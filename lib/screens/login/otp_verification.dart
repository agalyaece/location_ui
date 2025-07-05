import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:location_ui/backend_config/config.dart';
import 'package:location_ui/screens/home/home.dart';
import 'package:location_ui/services/auth_service.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:sms_autofill/sms_autofill.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
   const OtpVerificationScreen({super.key, required this.phoneNumber});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen>
    with CodeAutoFill {
  final TextEditingController _otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      listenForCode();
    }
  }

  @override
  void codeUpdated() {
    if (Platform.isAndroid && mounted && code != null) {
      setState(() {
        _otpController.text = code!;
      });
    }
  }

  @override
  void dispose() {
    if (Platform.isAndroid) {
      cancel();
    }
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please enter the OTP.')));
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Verifying OTP...')));

    try {
      final response = await http.post(
        Uri.parse(verifyOtpUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phoneNumber': widget.phoneNumber, 'otp': otp}),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          final responseBody = json.decode(response.body);
          final token = responseBody['token']; 
          print('Received token after OTP verification: $token'); // Debug print

          if (token != null) {
            await AuthService.setToken(token); // <--- SAVE THE TOKEN HERE!
            print('Token successfully saved by AuthService from OTP verification.'); // Debug print
          } else {
            print('Warning: Token was null after OTP verification, not saved.');
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('OTP Verified! Welcome.')));
          print('User data: ${responseBody['user']}');
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (ctx) => HomeScreen()));
        }
      } else {
        if (mounted) {
          final errorBody = json.decode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'OTP Verification Failed: ${errorBody['message'] ?? 'Unknown error'}',
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
        print('Network error verifying OTP: $e');
      }
    }
  }

  Future<void> _resendOtp() async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Resending OTP...')));
    try {
      final response = await http.post(
        Uri.parse(resendOtpUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phoneNumber': widget.phoneNumber}),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('OTP resent!')));
        }
      } else {
        if (mounted) {
          final errorBody = json.decode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to resend OTP: ${errorBody['message'] ?? 'Unknown error'}',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network error resending OTP: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Verify OTP')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Enter OTP sent to ${widget.phoneNumber}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'OTP',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.vpn_key),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _verifyOtp,
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text('Verify OTP', style: TextStyle(fontSize: 18)),
            ),
            SizedBox(height: 10),
            TextButton(onPressed: _resendOtp, child: Text('Resend OTP')),
          ],
        ),
      ),
    );
  }
}
