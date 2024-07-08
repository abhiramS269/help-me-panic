import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'HomePage.dart';

class LoginPage extends StatefulWidget {
  final String errorMessage;

  LoginPage({this.errorMessage = ''});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneNumberController = TextEditingController();
  late FirebaseAuth _auth;
  late FirebaseFirestore _firestore;
  String _authorizationStatus = '';
  String _userName = '';
  String _error = '';

  @override
  void initState() {
    super.initState();
    _auth = FirebaseAuth.instance;
    _firestore = FirebaseFirestore.instance;
    _requestPermissions();
    _checkIfUserIsLoggedIn();
  }

  void _requestPermissions() async {
    var status = await Permission.phone.status;
    if (!status.isGranted) {
      await Permission.phone.request();
    }
  }

  void _checkIfUserIsLoggedIn() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    if (isLoggedIn) {
      _checkAuthorizationStatus();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
      );
    }
  }

  Future<void> _checkAuthorizationStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? phoneNumber = prefs.getString('phoneNumber');

    if (phoneNumber != null) {
      bool isAuthorized = false;

      QuerySnapshot<Map<String, dynamic>> querySnapshot = await _firestore.collection('authorized_numbers').get();
      for (QueryDocumentSnapshot<Map<String, dynamic>> doc in querySnapshot.docs) {
        if (doc.exists) {
          doc.data().forEach((key, value) {
            if (value.toString() == phoneNumber) {
              isAuthorized = true;
            }
          });
        }
      }

      if (!isAuthorized) {
        await _logout();
      }
    } else {
      await _logout();
    }
  }

  Future<void> checkAuthorization(String phoneNumber) async {
    String formattedPhoneNumber = phoneNumber.replaceAll("+91", "").replaceAll(" ", "").replaceAll("-", "");

    try {
      QuerySnapshot<Map<String, dynamic>> querySnapshot = await _firestore.collection('authorized_numbers').get();
      bool isAuthorized = false;
      String userName = '';

      for (QueryDocumentSnapshot<Map<String, dynamic>> doc in querySnapshot.docs) {
        if (doc.exists) {
          doc.data().forEach((key, value) {
            String valueStr = value.toString();
            if (valueStr == formattedPhoneNumber) {
              isAuthorized = true;
              userName = key;
            }
          });
        }
      }

      if (isAuthorized) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('phoneNumber', formattedPhoneNumber);
        await prefs.setBool('isLoggedIn', true);

        setState(() {
          _authorizationStatus = 'Authorized';
          _userName = userName;
        });
        sendOtp(phoneNumber);
      } else {
        setState(() {
          _authorizationStatus = 'User not authorized';
          _userName = '';
        });
      }
    } catch (e) {
      setState(() {
        _authorizationStatus = 'Error occurred';
        _userName = '';
        _error = e.toString();
      });
      _showErrorDialog('Error: $e');
    }
  }

  void sendOtp(String phoneNumber) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          await _auth.signInWithCredential(credential);
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomePage()),
          );
        } catch (e) {
          setState(() {
            _error = e.toString();
          });
          _showErrorDialog('Failed to sign in: $e');
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() {
          _error = e.message ?? 'Unknown error';
        });
        _showVerificationFailedDialog(e.message);
      },
      codeSent: (String verificationId, int? resendToken) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpVerificationPage(verificationId: verificationId),
          ),
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
      timeout: Duration(seconds: 60),
    );
  }

  void _showVerificationFailedDialog(String? message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Verification Failed'),
          content: Text(message ?? 'Unknown error occurred.'),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('phoneNumber');
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (widget.errorMessage.isNotEmpty)
                Text(
                  widget.errorMessage,
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              if (_authorizationStatus.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: _authorizationStatus == 'Authorized' ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _authorizationStatus,
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      if (_userName.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Text(
                            _userName,
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      if (_authorizationStatus == 'User not authorized')
                        Icon(
                          Icons.close,
                          color: Colors.white,
                        ),
                    ],
                  ),
                ),
              if (_error.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Text(
                    _error,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              SizedBox(height: 20),
              InternationalPhoneNumberInput(
                onInputChanged: (PhoneNumber number) {
                  _phoneNumberController.text = number.phoneNumber ?? "";
                },
                selectorConfig: SelectorConfig(
                  selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
                ),
                ignoreBlank: false,
                autoValidateMode: AutovalidateMode.disabled,
                selectorTextStyle: TextStyle(color: Colors.black),
                initialValue: PhoneNumber(isoCode: 'IN'),
                formatInput: false,
                keyboardType: TextInputType.numberWithOptions(signed: true, decimal: true),
                inputBorder: OutlineInputBorder(),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => checkAuthorization(_phoneNumberController.text.trim()),
                child: Text('Verify Number'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class OtpVerificationPage extends StatefulWidget {
  final String verificationId;

  OtpVerificationPage({required this.verificationId});

  @override
  _OtpVerificationPageState createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final TextEditingController _otpController = TextEditingController();
  late FirebaseAuth _auth;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _auth = FirebaseAuth.instance;
  }

  void verifyOtp(String otp) async {
    PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: widget.verificationId,
      smsCode: otp,
    );
    try {
      await _auth.signInWithCredential(credential);
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
      _showErrorDialog('Failed to verify OTP: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('OTP Verification'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              TextField(
                controller: _otpController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Enter OTP',
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 20),
              if (_error.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Text(
                    _error,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => verifyOtp(_otpController.text.trim()),
                child: Text('Verify OTP'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}