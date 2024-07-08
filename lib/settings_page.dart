import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _securityPasscodeController = TextEditingController();
  List<TextEditingController> _phoneControllers = [];
  int _numberOfFields = 1;

  @override
  void initState() {
    super.initState();
    _initializePhoneControllers();
  }

  void _initializePhoneControllers() {
    _phoneControllers = List.generate(_numberOfFields, (index) => TextEditingController());
  }

  Future<void> _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> phoneNumbers = _phoneControllers.map((controller) => controller.text).toList();

    await prefs.setString('securityPasscode', _securityPasscodeController.text);
    await prefs.setStringList('emergencyNumbers', phoneNumbers);

    // Clear the input fields after saving
    _securityPasscodeController.clear();
    _phoneControllers.forEach((controller) => controller.clear());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Settings saved successfully.')),
    );
  }

  void _updateNumberOfFields(int count) {
    setState(() {
      _numberOfFields = count;
      _initializePhoneControllers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Set Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButton<int>(
              value: _numberOfFields,
              items: List.generate(10, (index) => index + 1)
                  .map((number) => DropdownMenuItem<int>(
                value: number,
                child: Text('$number phone number(s)'),
              ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  _updateNumberOfFields(value);
                }
              },
            ),
            Column(
              children: List.generate(_numberOfFields, (index) {
                return TextField(
                  controller: _phoneControllers[index],
                  decoration: InputDecoration(labelText: 'Phone Number ${index + 1}'),
                  keyboardType: TextInputType.phone,
                );
              }),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _securityPasscodeController,
              decoration: InputDecoration(labelText: 'Security Passcode'),
              keyboardType: TextInputType.number,
              maxLength: 3,
              obscureText: true, // Make the passcode field obscured
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveSettings,
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}