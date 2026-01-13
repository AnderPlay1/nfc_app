// Import necessary packages for the Flutter app.
// 'flutter/material.dart' provides the core Flutter framework for building UI.
// 'nfc_manager/nfc_manager.dart' is for handling NFC operations to read RFID tags.
// 'http/http.dart' is for making HTTP requests to the server (optional if not needed).
// 'nfc_manager_ndef/nfc_manager_ndef.dart' is for NDEF support.
// 'nfc_manager/src/nfc_manager_android/pigeon.g.dart' is for accessing TagPigeon on Android.
// 'dart:typed_data' for Uint8List.
// 'url_launcher/url_launcher.dart' for opening URLs in the browser.
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:http/http.dart' as http;
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';
import 'package:nfc_manager/src/nfc_manager_android/pigeon.g.dart';
import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart';

// The main function is the entry point of the Flutter application.
// It runs the MyApp widget as the root of the widget tree.
void main() {
  runApp(MyApp());
}

// MyApp is a stateless widget that serves as the root widget.
// It configures the MaterialApp, which is the top-level widget for Material Design apps.
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // MaterialApp sets up the app's theme, title, and home screen.
    return MaterialApp(
      title: 'RFID Reader',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

// MyHomePage is a stateful widget that manages the app's state.
// It handles NFC reading and HTTP requests.
class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

// _MyHomePageState is the private state class for MyHomePage.
// It contains the logic for NFC scanning and sending data.
class _MyHomePageState extends State<MyHomePage> {
  // Variable to store the read UID from the RFID tag.
  String _uid = '';
  // Variable to store status messages for the user.
  String _status = 'Приблизьте телефон к RFID карте';

  // initState is called when the widget is inserted into the tree.
  // Here, we check if NFC is available on the device.
  @override
  void initState() {
    super.initState();
    _checkNfcAvailability();
  }

  // Method to check if NFC is available and enabled.
  Future<void> _checkNfcAvailability() async {
    // Use NfcManager to check availability.
    bool isAvailable = await NfcManager.instance.isAvailable();
    // If not available, update the status message.
    if (!isAvailable) {
      setState(() {
        _status = 'NFC не доступен на этом устройстве';
      });
    }
  }

  // Method to start NFC scanning session.
  void _startNfcSession() {
    // Start a session with NfcManager.
    NfcManager.instance.startSession(
      pollingOptions: {...NfcPollingOption.values}, // Poll for all tag types.
      // onDiscovered callback is triggered when a tag is discovered.
      onDiscovered: (NfcTag tag) async {
        // Extract the NDEF if available.
        var ndef = Ndef.from(tag);
        // If NDEF is null, use TagPigeon to get id as UID.
        if (ndef == null) {
          // Cast tag.data to TagPigeon (Android-specific).
          final tagPigeon = tag.data as TagPigeon;
          // Get the id (UID) directly from TagPigeon.
          final Uint8List identifier = tagPigeon.id;
          // Convert identifier bytes to hex string for UID.
          String uid = identifier
              .map((e) => e.toRadixString(16).padLeft(2, '0'))
              .join(':')
              .toUpperCase();
          // Update state with the UID.
          setState(() {
            _uid = uid;
            _status = 'UID: $uid';
          });
          // Open the browser with the UID in the URL.
          await _openBrowserWithUid(uid);
        } else {
          // For NDEF tags, read the message (use cachedMessage if available, or read async).
          var message = ndef.cachedMessage ?? await ndef.read(); // Use var for type inference
          if (message != null && message.records.isNotEmpty) {
            // Extract payload from the first record (skip 3 bytes for text records if needed).
            String payload = String.fromCharCodes(message.records[0].payload.skip(3));
            // Update state with the payload as UID (simplified for RFID).
            setState(() {
              _uid = payload;
              _status = 'UID: $payload';
            });
            // Open the browser with the payload as UID.
            await _openBrowserWithUid(payload);
          } else {
            setState(() {
              _status = 'NDEF данные не найдены';
            });
          }
        }
        // Stop the NFC session after reading.
        NfcManager.instance.stopSession();
      },
    );
  }

  // Method to open the browser with the UID in the URL path.
  Future<void> _openBrowserWithUid(String uid) async {
    // Define the server URL with UID in the path.
    final String serverUrl = 'http://172.19.0.1:5000/receive_uid/$uid';
    final Uri url = Uri.parse(serverUrl);
    try {
      // Launch the URL in the browser.
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
        setState(() {
          _status += '\nБраузер открыт';
        });
      } else {
        setState(() {
          _status += '\nНе удалось открыть браузер';
        });
      }
    } catch (e) {
      // Handle any exceptions.
      setState(() {
        _status += '\nОшибка: $e';
      });
    }
  }

  // build method renders the UI.
  @override
  Widget build(BuildContext context) {
    // Scaffold provides the basic app structure with app bar and body.
    return Scaffold(
      appBar: AppBar(
        title: Text('RFID Reader'),
      ),
      body: Center(
        // Display the status and UID in the center.
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(_status),
            SizedBox(height: 20),
            // Button to start NFC scanning.
            ElevatedButton(
              onPressed: _startNfcSession,
              child: Text('Сканировать RFID'),
            ),
          ],
        ),
      ),
    );
  }
}