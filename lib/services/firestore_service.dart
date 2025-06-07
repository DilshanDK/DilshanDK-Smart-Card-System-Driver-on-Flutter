
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static final RegExp _phoneRegex = RegExp(r'^\+?[0-9]{10}$');

  /// Validate phone number (must be exactly 10 digits)
  String? validatePhone(String phone) {
    if (phone.trim().isEmpty) {
      return 'Phone number cannot be empty';
    }
    if (!_phoneRegex.hasMatch(phone.trim())) {
      return 'Phone number must be exactly 10 digits';
    }
    return null;
  }

  /// Validate name
  String? validateName(String name) {
    if (name.trim().isEmpty) {
      return 'Name cannot be empty';
    }
    if (name.trim().length < 2) {
      return 'Name must be at least 2 characters long';
    }
    return null;
  }

   String? validateLicenseNo(String value) {
  if (value.trim().isEmpty) {
    return 'License number cannot be empty';
  }
  if (!RegExp(r'^(B)?\d{7}$').hasMatch(value.trim())) {
    return 'Invalid license number format (e.g., 1234567 or B1234567)';
  }
  return null;
  
  }



  Future<Map<String, dynamic>?> fetchDriverData() async {
    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        throw Exception('No authenticated user found.');
      }

      final DocumentSnapshot doc =
          await _firestore.collection('drivers').doc(user.uid).get();

      if (!doc.exists) {
        throw Exception('Driver document does not exist.');
      }

      return doc.data() as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Error fetching driver data: $e');
    }
  }

  /// Update driver's profile in Firestore
Future<void> updateDriverProfile({
  required String updatedName,
  required String updatedPhone,
  String? updatedLicenseNo,
}) async {
  // Validate input
  final nameError = validateName(updatedName);
  final phoneError = validatePhone(updatedPhone);
  final user = _auth.currentUser;

  if (nameError != null) throw nameError; // <-- throw String
  if (phoneError != null) throw phoneError;
  if (user == null) throw 'No authenticated user found.';

  // Get current license number
  final driverDoc = await _firestore.collection('drivers').doc(user.uid).get();
  final currentLicenseNo = driverDoc.data()?['licenseNo'] as String? ?? '';

  final updateData = <String, dynamic>{
    'name': updatedName,
    'phone': updatedPhone,
  };

  // Handle license number logic
  final isLicenseUnset = currentLicenseNo.isEmpty || currentLicenseNo == 'Unknown';
  if (isLicenseUnset && updatedLicenseNo != null) {
    final licenseError = validateLicenseNo(updatedLicenseNo);
    if (licenseError != null) throw licenseError;

    // Check uniqueness
    final query = await _firestore
        .collection('drivers')
        .where('licenseNo', isEqualTo: updatedLicenseNo)
        .get();
    final alreadyExists = query.docs.any((doc) => doc.id != user.uid);
    if (alreadyExists) {
      throw 'License number already exists. Please enter a unique license number.';
    }
    updateData['licenseNo'] = updatedLicenseNo;
  } else if (updatedLicenseNo != null && updatedLicenseNo != currentLicenseNo) {
    throw 'License number cannot be changed once set.';
  }

  // Update Firestore
  try {
    await _firestore.collection('drivers').doc(user.uid).update(updateData);
  } catch (e) {
    throw 'Error updating driver profile: $e';
  }
}


static Future<List<Map<String, dynamic>>> fetchRoutes() async {
    try {
      developer.log('Fetching routes from Firestore', name: 'FirestoreServices');
      final snapshot = await FirebaseFirestore.instance.collection('routes').get();
      if (snapshot.docs.isEmpty) {
        developer.log('No routes found in Firestore', name: 'FirestoreServices');
        return [];
      }
      final routes = snapshot.docs
          .map((doc) {
            final data = doc.data();
            final routeName = data['routeName'];
            if (routeName is String && routeName.isNotEmpty) {
              return {
                'id': doc.id,
                'name': routeName,
                'routeId': data['routeId'] ?? doc.id,
              };
            }
            developer.log('Invalid route data for doc ${doc.id}: routeName=$routeName', name: 'FirestoreServices');
            return null;
          })
          .where((route) => route != null)
          .cast<Map<String, dynamic>>()
          .toList();
      developer.log('Fetched ${routes.length} routes: ${routes.map((r) => r['id'])}', name: 'FirestoreServices');
      return routes;
    } catch (e, stackTrace) {
      developer.log('Error fetching routes: $e', name: 'FirestoreServices', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }



  static Future<Map<String, dynamic>?> fetchRouteDetails(String routeId) async {
    final doc = await FirebaseFirestore.instance.collection('routes').doc(routeId).get();
    return doc.exists ? doc.data() : null;
  }

}

