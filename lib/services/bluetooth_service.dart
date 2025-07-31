// ignore_for_file: avoid_print, unused_import, constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import 'live_location_service.dart';

// Default company ID for all transactions
const String DEFAULT_COMPANY_ID = "COMP001";

class BluetoothService extends ChangeNotifier {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  BluetoothConnection? connection;
  List<BluetoothDevice> devices = [];
  bool isConnecting = false;
  String? connectedAddress;
  String messageBuffer = '';
  bool disconnectingInProgress = false;

  // Reference to LiveLocationService
  LiveLocationService? _liveLocationService;

  // Cache for route costs to avoid repeated Firestore queries
  final Map<String, double> _routeCostCache = {};
  
  // Your OpenRouteService API key
  final String _openRouteServiceApiKey = 'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImRhMmI5ODFkNWM3MzliYTQ0Mjk1MDJjZDRiMDA5MjMzN2I0MzBjYWU2OGUyMjU1YjBiOTVmNmNlIiwiaCI6Im11cm11cjY0In0=';
  
  // Cache to store journey start times for elapsed time calculation
  final Map<String, DateTime> _journeyStartTimes = {};

  final Map<String, String> uidToPassengerId = {
    "F1DAC11E": "9NIS7WkbExQU08oHCOqnn77yBrq1",
    "B2E34D05": "J6FtCixQENNrOuLZNKHcNRaZsWH2",
    // ... add more mappings
  };

  final List<ReceivedKeyRecord> _receivedKeyRecords = [];
  List<ReceivedKeyRecord> get receivedKeyRecords => List.unmodifiable(_receivedKeyRecords);

  final List<void Function(String uid, String key)> _keyCallbacks = [];

  // Track last processed tap for each passenger ID to prevent duplicate handling
  final Map<String, DateTime> _lastTagProcessTimes = {};
  // Track the IDs of journeys being created to prevent race conditions
  final Set<String> _processingPassengerIds = {};
  
  // Minimum time between tag processing for the same passenger (in seconds)
  final int _minTimeBetweenTaps = 3;

  Timer? _overdueTimer;

  // Default cost per km if route cost is not available
  static const double _defaultCostPerKm = 0.5;

  // Set the LiveLocationService reference
  void setLiveLocationService(LiveLocationService service) {
    _liveLocationService = service;
    print("LiveLocationService connected to BluetoothService");
    
    // Debug connection information
    final routeId = service.selectedRouteId;
    final isSharing = service.isSharing;
    print("LiveLocationService connection status:");
    print("- Selected Route ID: ${routeId ?? 'Not selected'}");
    print("- Is Sharing: $isSharing");
    
    notifyListeners();
  }

  // Fetch the cost per kilometer for a specific route from Firestore
  Future<double> getRoutePerKmCost(String routeId) async {
    try {
      // Check cache first
      if (_routeCostCache.containsKey(routeId)) {
        return _routeCostCache[routeId]!;
      }
      
      // Get the route document from Firestore
      final routeDoc = await FirebaseFirestore.instance
          .collection('routes')
          .doc(routeId)
          .get();
      
      // If document exists and contains costPerKm field
      if (routeDoc.exists && routeDoc.data()!.containsKey('costPerKm')) {
        final costPerKm = routeDoc.data()?['costPerKm'];
        
        // Convert to double (handle different numeric formats)
        double parsedCost;
        if (costPerKm is double) {
          parsedCost = costPerKm;
        } else if (costPerKm is int) {
          parsedCost = costPerKm.toDouble();
        } else if (costPerKm is String) {
          parsedCost = double.tryParse(costPerKm) ?? _defaultCostPerKm;
        } else {
          throw FormatException("Invalid costPerKm format");
        }
        
        // Cache the result and return
        _routeCostCache[routeId] = parsedCost;
        print("Retrieved costPerKm for route $routeId: $parsedCost");
        return parsedCost;
      } else {
        print("No costPerKm found for route $routeId, using default: $_defaultCostPerKm");
        return _defaultCostPerKm;
      }
    } catch (e, stack) {
      print("Error fetching route cost for $routeId: $e\n$stack");
      return _defaultCostPerKm;
    }
  }

  // Process payment for journey - FIXED to handle reads before writes
  Future<Map<String, dynamic>> processPaymentForJourney(
    String journeyId, 
    String passengerId, 
    double amount
  ) async {
    try {
      final db = FirebaseFirestore.instance;
      
      // Create a transaction to update multiple documents atomically
      final result = await db.runTransaction<Map<String, dynamic>>(
        (transaction) async {
          // 1. Read all documents we'll need to modify FIRST
          
          // Read the passenger document
          final passengerDocRef = db.collection('passengers').doc(passengerId);
          final passengerDoc = await transaction.get(passengerDocRef);
          
          if (!passengerDoc.exists) {
            return {
              'success': false,
              'message': 'Passenger record not found',
              'transactionId': null
            };
          }
          
          // Read the company document - must do this BEFORE any writes
          final companyDocRef = db.collection('buscompanies').doc(DEFAULT_COMPANY_ID);
          final companyDoc = await transaction.get(companyDocRef);
          
          // Read the journey document - must do this BEFORE any writes
          final journeyDocRef = db.collection('journeys').doc(journeyId);
          final journeyDoc = await transaction.get(journeyDocRef);
          
          if (!journeyDoc.exists) {
            return {
              'success': false,
              'message': 'Journey record not found',
              'transactionId': null
            };
          }
          
          // Now that all reads are done, proceed with data processing and writes
          
          // Extract wallet balance (handle different data types)
          double currentBalance = 0.0;
          final walletData = passengerDoc.data()?['walletBalance'];
          
          if (walletData is double) {
            currentBalance = walletData;
          } else if (walletData is int) {
            currentBalance = walletData.toDouble();
          } else if (walletData is String) {
            currentBalance = double.tryParse(walletData) ?? 0.0;
          }
          
          print('Current wallet balance for passenger $passengerId: $currentBalance');
          
          // Check if there's enough balance
          if (currentBalance < amount) {
            // Update journey with insufficient funds status - since we already read the document
            transaction.update(journeyDocRef, {
              'paymentStatus': 'failed',
              'paymentError': 'Insufficient balance'
            });
            
            return {
              'success': false,
              'message': 'Insufficient balance',
              'transactionId': null
            };
          }
          
          // Create transaction reference - BEFORE we write to it
          final transactionRef = db.collection('transactions').doc();
          
          // 2. Now perform all writes
          
          // Update passenger's wallet balance
          final newBalance = currentBalance - amount;
          transaction.update(passengerDocRef, {
            'walletBalance': newBalance
          });
          
          print('Updated wallet balance for passenger $passengerId: $newBalance');
          
          // Update or create company balance
          if (companyDoc.exists) {
            // Extract company balance (handle different data types)
            double companyBalance = 0.0;
            final balanceData = companyDoc.data()?['balance'];
            
            if (balanceData is double) {
              companyBalance = balanceData;
            } else if (balanceData is int) {
              companyBalance = balanceData.toDouble();
            } else if (balanceData is String) {
              companyBalance = double.tryParse(balanceData) ?? 0.0;
            }
            
            // Update company balance
            final newCompanyBalance = companyBalance + amount;
            transaction.update(companyDocRef, {
              'balance': newCompanyBalance
            });
            
            print('Updated balance for company $DEFAULT_COMPANY_ID: $newCompanyBalance (+$amount)');
          } else {
            // Create company record if it doesn't exist
            transaction.set(companyDocRef, {
              'balance': amount,
              'companyId': DEFAULT_COMPANY_ID,
              'name': 'Default Bus Company',
              'createdAt': FieldValue.serverTimestamp(),
            });
            print('Created company record with initial balance: $amount');
          }
          
          // Create transaction record with type and description
          transaction.set(transactionRef, {
            'passengerId': passengerId,
            'companyId': DEFAULT_COMPANY_ID,
            'amount': amount,
            'journeyId': journeyId,
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'completed',
            'type': 'debit',  // Added transaction type
            'description': 'Journey Cost'  // Added transaction description
          });
          
          print('Created transaction record: ${transactionRef.id}');
          
          // Update journey with transaction reference
          transaction.update(journeyDocRef, {
            'transactionId': transactionRef.id,
            'paymentStatus': 'paid',
            'paymentTimestamp': FieldValue.serverTimestamp()
          });
          
          return {
            'success': true,
            'message': 'Payment processed successfully',
            'transactionId': transactionRef.id,
            'newBalance': newBalance
          };
        },
        maxAttempts: 3,
      );
      
      return result;
    } catch (e, stack) {
      print('Error processing payment: $e\n$stack');
      // If there's an error, try to update the journey with the error information
      try {
        await FirebaseFirestore.instance
            .collection('journeys')
            .doc(journeyId)
            .update({
              'paymentStatus': 'error',
              'paymentError': e.toString()
            });
      } catch (_) {
        // Ignore errors when updating payment status
      }
      
      return {
        'success': false,
        'message': 'Payment processing error: $e',
        'transactionId': null
      };
    }
  }

  // Calculate road distance using OpenRouteService API
  Future<double> calculateRoadDistanceInKm(GeoPoint? startLocation, GeoPoint? endLocation) async {
    if (startLocation == null || endLocation == null) {
      return 0.0; // Return zero if locations are null - no additional distance added here
    }
    
    try {
      // OpenRouteService API endpoint for directions
      final baseUrl = 'https://api.openrouteservice.org/v2/directions/driving-car';
      
      // Prepare coordinates in the format [longitude, latitude]
      final coordinates = [
        [startLocation.longitude, startLocation.latitude],
        [endLocation.longitude, endLocation.latitude]
      ];
      
      // Create request body
      final body = jsonEncode({
        'coordinates': coordinates,
        'instructions': false,
        'format': 'json',
        'units': 'km'
      });
      
      print('Requesting road distance from OpenRouteService');
      
      // Make the HTTP POST request
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json, application/geo+json, application/gpx+xml',
          'Authorization': _openRouteServiceApiKey
        },
        body: body,
      );
      
      if (response.statusCode == 200) {
        // Parse the JSON response
        final data = json.decode(response.body);
        
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          // Extract the distance in kilometers (ORS returns it in meters by default)
          final distanceInMeters = data['routes'][0]['summary']['distance'];
          
          // Convert to kilometers and round to 2 decimal places
          final distanceInKm = double.parse((distanceInMeters / 1000).toStringAsFixed(2));
          
          print('Road distance from OpenRouteService: $distanceInKm km');
          return distanceInKm;
        } else {
          print('Invalid or empty routes in response: ${response.body}');
        }
      } else {
        print('Failed to get road distance. Status code: ${response.statusCode}');
        print('Response: ${response.body}');
      }
      
      // If API call fails, fall back to direct distance with route factor
      print('Falling back to direct distance with route factor');
      return estimateRoadDistanceInKm(startLocation, endLocation);
    } catch (e, stack) {
      print('Error calculating road distance: $e\n$stack');
      // Fall back to direct distance on error
      return estimateRoadDistanceInKm(startLocation, endLocation);
    }
  }

  // Direct distance calculation
  double calculateDirectDistanceInKm(GeoPoint? startLocation, GeoPoint? endLocation) {
    if (startLocation == null || endLocation == null) {
      return 0.0; // Return zero if locations are null
    }
    
    try {
      final distanceInMeters = Geolocator.distanceBetween(
        startLocation.latitude,
        startLocation.longitude,
        endLocation.latitude,
        endLocation.longitude
      );
      
      // Convert to kilometers and round to 2 decimal places
      return double.parse((distanceInMeters / 1000).toStringAsFixed(2));
    } catch (e) {
      print('Error calculating direct distance: $e');
      return 0.0;
    }
  }

  // Estimate road distance by applying a route factor to direct distance
  double estimateRoadDistanceInKm(GeoPoint? startLocation, GeoPoint? endLocation) {
    if (startLocation == null || endLocation == null) {
      return 0.0; // Return zero if locations are null
    }
    
    // Calculate direct distance
    double directDistance = 0.0;
    try {
      final distanceInMeters = Geolocator.distanceBetween(
        startLocation.latitude,
        startLocation.longitude,
        endLocation.latitude,
        endLocation.longitude
      );
      directDistance = distanceInMeters / 1000;
    } catch (e) {
      print('Error calculating direct distance in estimate: $e');
      directDistance = 0.0;
    }
    
    // Apply a route factor (typically between 1.2 and 1.4 for urban areas)
    const routeFactor = 1.3;
    final estimatedRoadDistance = directDistance * routeFactor;
    
    // Round to 2 decimal places
    return double.parse(estimatedRoadDistance.toStringAsFixed(2));
  }

  // Calculate the elapsed time between journey start and end in seconds
  int calculateElapsedTimeInSeconds(String passengerId, DateTime endTime) {
    if (!_journeyStartTimes.containsKey(passengerId)) {
      print("No start time found for passenger $passengerId, using default of 0 seconds");
      return 0; // No start time recorded
    }
    
    final startTime = _journeyStartTimes[passengerId]!;
    final elapsedSeconds = endTime.difference(startTime).inSeconds;
    
    // Ensure we don't have negative elapsed time due to clock issues
    return elapsedSeconds < 0 ? 0 : elapsedSeconds;
  }

  // Initialization
  Future<void> initialize() async {
    try {
      final permissions = [
        Permission.bluetooth,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.location,
      ];
      await permissions.request();
      final bondedDevices = await FlutterBluetoothSerial.instance.getBondedDevices();
      devices = bondedDevices;
      notifyListeners();
    } catch (e, stack) {
      print('Error initializing Bluetooth: $e\n$stack');
    }
    startOverdueJourneyChecker();
  }

  // Connect to a Bluetooth device
 Future<bool> connect(BluetoothDevice device) async {
    if (isConnecting) return false;
    isConnecting = true;
    messageBuffer = '';
    notifyListeners();
    try {
      await safeDisconnect();
      connection = await BluetoothConnection.toAddress(device.address);
      connectedAddress = device.address;
      isConnecting = false;
      notifyListeners();
      connection!.input?.listen(
        (Uint8List data) {
          messageBuffer += utf8.decode(data, allowMalformed: true);
          if (messageBuffer.contains('\n')) {
            final lines = messageBuffer.split('\n');
            for (int i = 0; i < lines.length - 1; i++) {
              if (lines[i].isNotEmpty) {
                _notifyKeyCallbacks(lines[i]);
              }
            }
            messageBuffer = lines.last;
          }
          if (messageBuffer.length > 100) {
            _notifyKeyCallbacks(messageBuffer);
            messageBuffer = '';
          }
          if (messageBuffer.length >= 8 && messageBuffer.length <= 16) {
            final cleanBuffer = messageBuffer.replaceAll(RegExp(r'[^A-Fa-f0-9]'), '');
            if (cleanBuffer.length == 8) {
              _notifyKeyCallbacks(messageBuffer);
              messageBuffer = '';
            }
          }
        },
        onDone: _handleConnectionLost,
        onError: (error) => _handleConnectionLost(),
      );
      return true;
    } catch (e, stack) {
      print('Error connecting to device: $e\n$stack');
      isConnecting = false;
      notifyListeners();
      return false;
    }
  }

  // Disconnect safely from the Bluetooth device
  Future<void> safeDisconnect() async {
    try {
      if (disconnectingInProgress) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      if (connection != null) {
        disconnectingInProgress = true;
        notifyListeners();
        await connection!.close();
        connection = null;
        connectedAddress = null;
        disconnectingInProgress = false;
        notifyListeners();
      }
    } catch (e, stack) {
      print('Error in safe disconnect: $e\n$stack');
      disconnectingInProgress = false;
      notifyListeners();
    }
  }

  // Force disconnect
  Future<bool> disconnect() async {
    try {
      disconnectingInProgress = true;
      notifyListeners();
      if (connection != null) {
        await connection!.close();
        connection = null;
        connectedAddress = null;
        disconnectingInProgress = false;
        notifyListeners();
        return true;
      }
      disconnectingInProgress = false;
      notifyListeners();
      return false;
    } catch (e, stack) {
      print('Error disconnecting: $e\n$stack');
      disconnectingInProgress = false;
      notifyListeners();
      return false;
    }
  }

  // Handler for lost connection
  void _handleConnectionLost() {
    if (connection != null) {
      connection = null;
      connectedAddress = null;
      notifyListeners();
    }
  }

  // Refresh paired Bluetooth devices
  Future<void> refreshDevices() async {
    try {
      final bondedDevices = await FlutterBluetoothSerial.instance.getBondedDevices();
      devices = bondedDevices;
      notifyListeners();
    } catch (e, stack) {
      print('Error refreshing devices: $e\n$stack');
    }
  }

  // Get currently connected device
  BluetoothDevice? getConnectedDevice() {
    if (connectedAddress != null && devices.isNotEmpty) {
      try {
        return devices.firstWhere(
          (d) => d.address == connectedAddress,
          orElse: () => BluetoothDevice(address: connectedAddress!),
        );
      } catch (e) {
        return BluetoothDevice(address: connectedAddress!);
      }
    }
    return null;
  }

  // Key Callback registration
  void registerKeyCallback(void Function(String uid, String key) callback) {
    if (!_keyCallbacks.contains(callback)) {
      _keyCallbacks.add(callback);
    }
  }

  void unregisterKeyCallback(void Function(String uid, String key) callback) {
    _keyCallbacks.remove(callback);
  }

  // Add received key record
  void addReceivedKeyRecord(String uid, String key) {
    _receivedKeyRecords.add(ReceivedKeyRecord(uid: uid, key: key, timestamp: DateTime.now()));
    notifyListeners();
  }

  void clearReceivedKeyRecords() {
    _receivedKeyRecords.clear();
    notifyListeners();
  }

  // Get current location
  Future<GeoPoint?> _getCurrentLocation() async {
    try {
      // First try to get location from LiveLocationService if available
      if (_liveLocationService != null && _liveLocationService!.currentLocation != null) {
        final locData = _liveLocationService!.currentLocation!;
        return GeoPoint(locData.latitude ?? 0.0, locData.longitude ?? 0.0);
      }
      
      // Fallback to Geolocator
      final position = await Geolocator.getCurrentPosition();
      return GeoPoint(position.latitude, position.longitude);
    } catch (e, stack) {
      print('Error getting location: $e\n$stack');
      return null;
    }
  }

  // Process payment after journey completion
  Future<void> _processPaymentAfterJourneyCompletion(
    String journeyId, 
    String passengerId, 
    double amount
  ) async {
    try {
      print("Processing payment of $amount for journey $journeyId, passenger $passengerId");
      
      // Process the payment
      final result = await processPaymentForJourney(journeyId, passengerId, amount);
      
      // Log the result
      if (result['success']) {
        print("Payment processed successfully.");
        print("Transaction ID: ${result['transactionId']}");
        print("New wallet balance: ${result['newBalance']}");
      } else {
        print("Payment failed: ${result['message']}");
      }
    } catch (e, stack) {
      print("Error in payment after journey completion: $e\n$stack");
      
      // Update journey record with failed payment status if not already updated in the transaction
      try {
        await FirebaseFirestore.instance
            .collection('journeys')
            .doc(journeyId)
            .update({
              'paymentStatus': 'error',
              'paymentError': e.toString()
            });
      } catch (updateError) {
        print("Failed to update journey with payment error: $updateError");
      }
    }
  }

  // Called when a UID is received - UPDATED to check Bluetooth connection and live sharing
  void _notifyKeyCallbacks(String uid) async {
    final cleanUID = uid.replaceAll(RegExp(r'[^A-Fa-f0-9]'), '').toUpperCase();
    final passengerId = uidToPassengerId[cleanUID] ?? "Unknown Key";
    
    // Notify all callbacks regardless of passenger ID
    for (final callback in _keyCallbacks) {
      callback(cleanUID, passengerId);
    }
    
    // Add to received key records
    addReceivedKeyRecord(cleanUID, passengerId);

    // Only process known passengers
    if (passengerId == "Unknown Key") {
      print("Unknown passenger UID: $cleanUID (no journey created/updated)");
      return;
    }
    
    // CHECK 1: Verify Bluetooth connection
    if (connection == null || connectedAddress == null) {
      print("ERROR: Bluetooth connection not established. Cannot process journey.");
      return;
    }

    // CHECK 2: Verify live sharing is active
    if (_liveLocationService == null || !_liveLocationService!.isSharing) {
      print("ERROR: Live location sharing is not active. Cannot process journey.");
      return;
    }

    // CHECK 3: Verify route is selected
    String? routeId = _liveLocationService?.selectedRouteId;
    if (routeId == null || routeId.isEmpty) {
      print("ERROR: No route selected. Cannot process journey.");
      return;
    }
    
    // Check if this passenger ID is currently being processed
    if (_processingPassengerIds.contains(passengerId)) {
      print("Already processing a journey for passengerId: $passengerId - skipping");
      return;
    }
    
    // Check if this tag was processed recently to prevent rapid duplicate taps
    final now = DateTime.now();
    if (_lastTagProcessTimes.containsKey(passengerId)) {
      final lastProcessTime = _lastTagProcessTimes[passengerId]!;
      final differenceInSeconds = now.difference(lastProcessTime).inSeconds;
      
      if (differenceInSeconds < _minTimeBetweenTaps) {
        print("Ignoring tap for passengerId: $passengerId - too soon after previous tap ($differenceInSeconds sec)");
        return;
      }
    }
    
    // Set processing flag and update last process time
    _processingPassengerIds.add(passengerId);
    _lastTagProcessTimes[passengerId] = now;
    
    try {
      print("Processing tag for passengerId: $passengerId");
      print("Using selected routeId: $routeId");

      // Use a transaction to ensure data consistency
      String? journeyIdToProcess;
      double? costToProcess;
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Query for incomplete journeys
        final querySnapshot = await FirebaseFirestore.instance
            .collection('journeys')
            .where('passengerId', isEqualTo: passengerId)
            .where('endTimestamp', isNull: true)
            .limit(1)
            .get();
        
        if (querySnapshot.docs.isNotEmpty) {
          // Update the existing journey - this is the second tap
          final doc = querySnapshot.docs.first;
          final journeyId = doc.id;
          journeyIdToProcess = journeyId; // Store for later processing
          
          final currentData = doc.data();
          print("Updating journey $journeyId with end timestamp");
          
          // Get current location for end point
          final currentLocation = await _getCurrentLocation();
          
          // Get the route ID from the existing journey
          final journeyRouteId = currentData['routeId'] as String? ?? 'default_route';
          
          // Fetch the cost per km for this route
          final costPerKm = await getRoutePerKmCost(journeyRouteId);
          
          // Get start location from the journey
          final startLocation = currentData['startLocation'] as GeoPoint?;
          final startTimestamp = currentData['startTimestamp'] as Timestamp?;
          
          // NEW CODE: Calculate elapsed time since journey start
          int elapsedSeconds = 0;
          if (startTimestamp != null) {
            elapsedSeconds = now.difference(startTimestamp.toDate()).inSeconds;
            // Ensure elapsed time is positive
            elapsedSeconds = elapsedSeconds < 0 ? 0 : elapsedSeconds;
            print("Calculated elapsed time: $elapsedSeconds seconds");
          }
          
          // Calculate road distance between start and end locations
          double distance = 0.0;
          if (currentLocation != null && startLocation != null) {
            // Use OpenRouteService API for road distance
            distance = await calculateRoadDistanceInKm(startLocation, currentLocation);
            print("Calculated road distance: $distance km");
            
            // NEW CODE: Add elapsed seconds to the distance
            double totalDistance = distance + elapsedSeconds;
            print("Adding elapsed time ($elapsedSeconds seconds) to distance: $totalDistance km");
            distance = totalDistance;
          } else {
            // If locations are missing, just use the elapsed time as distance
            distance = elapsedSeconds.toDouble();
            print("No valid locations, using elapsed time as distance: $distance km");
          }
          
          // Calculate total cost using the route's costPerKm
          final totalCost = double.parse((distance * costPerKm).toStringAsFixed(2));
          costToProcess = totalCost; // Store for later processing
          
          // Prepare journey update data
          final updateData = {
            'endLocation': currentLocation,
            'endTimestamp': FieldValue.serverTimestamp(),
            'distance': distance,
            'totalCost': totalCost,
            'costPerKm': costPerKm, // Store the used costPerKm for reference
            'elapsedSeconds': elapsedSeconds, // Store elapsed seconds for reference
            'calculationMethod': 'distance_plus_elapsed_time', // Document the calculation method
            'paymentStatus': 'pending', // Set initial payment status
          };
          
          transaction.update(doc.reference, updateData);
          
          print("Transaction prepared: Update journey $journeyId with end timestamp and calculations");
          print("Distance calculation: $distance km (including $elapsedSeconds seconds elapsed time)");
          print("Cost per km: $costPerKm, Total cost: $totalCost");
          
          // Clean up the start time after journey completion
          _journeyStartTimes.remove(passengerId);
          
        } else {
          // Create a new journey with all required fields - this is the first tap
          final currentLocation = await _getCurrentLocation();
          
          // Store the start time for later elapsed time calculation
          _journeyStartTimes[passengerId] = now;
          print("Recorded journey start time for passenger $passengerId: $now");
          
          // New journeys start with zero distance and cost
          final journeyData = {
            'passengerId': passengerId,
            'startLocation': currentLocation,
            'startTimestamp': FieldValue.serverTimestamp(),
            'endLocation': null,
            'endTimestamp': null,
            'routeId': routeId,
            'distance': 0.0,  // Initial distance is zero
            'totalCost': 0.0, // Initial cost is zero
            'costPerKm': 0.0, // Will be set when journey completes
            'elapsedSeconds': 0, // Will be calculated when journey completes
            'calculationMethod': 'distance_plus_elapsed_time', // Document the calculation method
            'paymentStatus': 'not_applicable', // No payment needed for journey start
          };
          
          final newJourneyRef = FirebaseFirestore.instance.collection('journeys').doc();
          transaction.set(newJourneyRef, journeyData);
          
          print("Transaction prepared: Create new journey ${newJourneyRef.id} for passengerId: $passengerId with routeId: $routeId");
        }
      });
      
      print("Journey processing completed successfully for passengerId: $passengerId");
      
      // Process the payment after the journey transaction is complete
      if (journeyIdToProcess != null && costToProcess != null && costToProcess! > 0) {
        await _processPaymentAfterJourneyCompletion(
          journeyIdToProcess!, 
          passengerId, 
          costToProcess!
        );
      }
      
    } catch (e, stack) {
      print("Error handling journey for $passengerId: $e\n$stack");
    } finally {
      // Always clean up the processing flag
      _processingPassengerIds.remove(passengerId);
    }
  }

  // Overdue journey checker
  Future<void> _processOverdueJourneys() async {
    try {
      // Find journeys that have been open for more than 12 hours
      final cutoffTime = Timestamp.fromDate(
          DateTime.now().subtract(const Duration(hours: 12)));
          
      final querySnapshot = await FirebaseFirestore.instance
          .collection('journeys')
          .where('startTimestamp', isLessThan: cutoffTime)
          .where('endTimestamp', isNull: true)
          .get();
          
      for (final doc in querySnapshot.docs) {
        await doc.reference.update({
          'endTimestamp': FieldValue.serverTimestamp(),
          'notes': 'Auto-closed due to overdue journey',
        });
        print("Auto-closed overdue journey: ${doc.id}");
      }
    } catch (e, stack) {
      print('Error processing overdue journeys: $e\n$stack');
    }
  }

  void startOverdueJourneyChecker() {
    _overdueTimer?.cancel();
    _overdueTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _processOverdueJourneys();
    });
  }

  void stopOverdueJourneyChecker() {
    _overdueTimer?.cancel();
    _overdueTimer = null;
  }
  
  // Debug method to check live location service status
  Map<String, dynamic> debugLiveLocationStatus() {
    if (_liveLocationService == null) {
      return {
        'connected': false,
        'message': 'LiveLocationService not connected',
      };
    }
    
    return {
      'connected': true,
      'isSharing': _liveLocationService!.isSharing,
      'selectedRouteId': _liveLocationService!.selectedRouteId,
      'selectedRouteName': _liveLocationService!.selectedRouteName,
      'hasCurrentLocation': _liveLocationService!.currentLocation != null,
    };
  }
  
  // Check if system is ready for scanning
  bool isReadyForScanning() {
    // Check Bluetooth connection
    final isBluetoothConnected = connection != null && connectedAddress != null;
    
    // Check live location service
    final isLiveLocationActive = _liveLocationService != null && _liveLocationService!.isSharing;
    
    // Check route selection
    final isRouteSelected = _liveLocationService?.selectedRouteId != null && 
                          _liveLocationService!.selectedRouteId!.isNotEmpty;
    
    return isBluetoothConnected && isLiveLocationActive && isRouteSelected;
  }
  
  // Debug method for distance calculation
  Future<Map<String, dynamic>> debugDistanceCalculation(GeoPoint start, GeoPoint end) async {
    try {
      final directDistance = calculateDirectDistanceInKm(start, end);
      final estimatedDistance = estimateRoadDistanceInKm(start, end);
      final roadDistance = await calculateRoadDistanceInKm(start, end);
      
      // Simulate different elapsed times
      final simulatedElapsedTimes = [5, 30, 60, 300]; // 5 sec, 30 sec, 1 min, 5 min
      final distancesWithTime = <Map<String, dynamic>>[];
      
      for (final seconds in simulatedElapsedTimes) {
        distancesWithTime.add({
          'elapsedSeconds': seconds,
          'totalDistance': roadDistance + seconds,
          'explanation': 'Road distance ($roadDistance km) + Elapsed time ($seconds seconds) = ${roadDistance + seconds} km'
        });
      }
      
      return {
        'success': true,
        'directDistance': directDistance,
        'estimatedDistance': estimatedDistance,
        'roadDistance': roadDistance,
        'newCalculationMethod': 'distance_plus_elapsed_time',
        'simulatedDistancesWithTime': distancesWithTime,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // Clear the route cost cache if needed
  void clearRouteCostCache() {
    _routeCostCache.clear();
  }
}

class ReceivedKeyRecord {
  final String uid;
  final String key;
  final DateTime timestamp;
  ReceivedKeyRecord({required this.uid, required this.key, required this.timestamp});
}