import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:smart_card_app_driver/models/driver.dart';
import 'package:smart_card_app_driver/services/auth_service.dart';
import 'package:smart_card_app_driver/services/bluetooth_service.dart';
import 'package:smart_card_app_driver/services/live_location_service.dart'; 
import 'package:smart_card_app_driver/wrapper.dart';
import 'firebase_options.dart';
import 'dart:developer' as developer;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    developer.log('Firebase initialized successfully', name: 'main');
    
    // Create service instances first
    final bluetoothService = BluetoothService();
    final liveLocationService = LiveLocationService();
    
    // Connect LiveLocationService to BluetoothService
    bluetoothService.setLiveLocationService(liveLocationService);
    
    // Initialize bluetooth service
    await bluetoothService.initialize();
    
    developer.log('Services initialized and connected', name: 'main');
    
    runApp(MyApp(
      bluetoothService: bluetoothService,
      liveLocationService: liveLocationService,
    ));
  } catch (e, stackTrace) {
    developer.log('Initialization failed: $e',
        name: 'main', error: e, stackTrace: stackTrace);
    runApp(ErrorApp(message: 'Failed to initialize app: $e'));
  }
}

class MyApp extends StatelessWidget {
  final BluetoothService bluetoothService;
  final LiveLocationService liveLocationService;
  
  const MyApp({
    super.key, 
    required this.bluetoothService, 
    required this.liveLocationService
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        StreamProvider<Driver?>.value(
          initialData: null,
          value: AuthenticationService().driver,
        ),
        // Use the pre-connected instances instead of creating new ones
        ChangeNotifierProvider<BluetoothService>.value(
          value: bluetoothService,
        ),
        ChangeNotifierProvider<LiveLocationService>.value(
          value: liveLocationService,
        ),
        // Add other providers as needed
      ],
      child: MaterialApp(
        home: const Wrapper(),
        debugShowCheckedModeBanner: true,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
      ),
    );
  }
}

class ErrorApp extends StatelessWidget {
  final String message;

  const ErrorApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ErrorScreen(message: message),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ErrorScreen extends StatelessWidget {
  final String message;

  const ErrorScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Text(
          message,
          style: const TextStyle(color: Colors.red, fontSize: 18),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}