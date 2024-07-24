import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:telephony/telephony.dart';
import 'LoginPage.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Telephony telephony = Telephony.instance;
  late Timer _authorizationCheckTimer;
  String _smsStatus = '';

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _setupPeriodicAuthorizationCheck();
  }

  void _requestPermissions() async {
    bool? result = await telephony.requestPhoneAndSmsPermissions;
    if (result == null || !result) {
      print('SMS permission denied');
    }
  }

  void _setupPeriodicAuthorizationCheck() {
    _authorizationCheckTimer = Timer.periodic(Duration(minutes: 1), (timer) {
      _checkAuthorizationStatus();
    });
  }

  Future<void> _checkAuthorizationStatus() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String formattedPhoneNumber = user.phoneNumber?.replaceAll("+91", "").replaceAll(" ", "").replaceAll("-", "") ?? "";
      bool isAuthorized = false;

      QuerySnapshot<Map<String, dynamic>> querySnapshot = await FirebaseFirestore.instance.collection('authorized_numbers').get();
      for (QueryDocumentSnapshot<Map<String, dynamic>> doc in querySnapshot.docs) {
        if (doc.exists) {
          doc.data().forEach((key, value) {
            if (value.toString() == formattedPhoneNumber) {
              isAuthorized = true;
            }
          });
        }
      }

      if (!isAuthorized) {
        await _logout();
      }
    }
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  Future<void> _sendPanicSMS() async {
    bool isAuthorized = await _isUserAuthorized();
    if (!isAuthorized) {
      await _logout();
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> emergencyNumbers = prefs.getStringList('emergencyNumbers') ?? [];
    String securityPasscode = prefs.getString('securityPasscode') ?? "";

    if (emergencyNumbers.isEmpty || securityPasscode.isEmpty) {
      setState(() {
        _smsStatus = 'No saved details found. Cannot send SMS.';
      });
      return;
    }

    try {
      for (String number in emergencyNumbers) {
        await telephony.sendSms(to: number, message: "$securityPasscode" + "C");
      }
      setState(() {
        _smsStatus = 'Emergency SMS has been sent.';
      });
    } catch (error) {
      print("Failed to send SMS: $error");
      setState(() {
        _smsStatus = 'Failed to send SMS.';
      });
    }
  }

  Future<bool> _isUserAuthorized() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String formattedPhoneNumber = user.phoneNumber?.replaceAll("+91", "").replaceAll(" ", "").replaceAll("-", "") ?? "";
      bool isAuthorized = false;

      QuerySnapshot<Map<String, dynamic>> querySnapshot = await FirebaseFirestore.instance.collection('authorized_numbers').get();
      for (QueryDocumentSnapshot<Map<String, dynamic>> doc in querySnapshot.docs) {
        if (doc.exists) {
          doc.data().forEach((key, value) {
            if (value.toString() == formattedPhoneNumber) {
              isAuthorized = true;
            }
          });
        }
      }
      return isAuthorized;
    }
    return false;
  }

  @override
  void dispose() {
    _authorizationCheckTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvoked: (popInvoked) async => false, // Prevent back navigation
      child: Scaffold(
        appBar: AppBar(
          title: Text('Home Page'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: Icon(Icons.logout),
              onPressed: _logout,
            ),
            IconButton(
              icon: Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SettingsPage()),
                );
              },
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _sendPanicSMS,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red,
                    gradient: LinearGradient(
                      colors: [Colors.red, Colors.redAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        spreadRadius: 1,
                        blurRadius: 8,
                        offset: Offset(3, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'Panic',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
              ),
              if (_smsStatus.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _smsStatus,
                    style: TextStyle(
                      color: _smsStatus == 'Emergency SMS has been sent.' ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
