// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart'; // ADD THIS
import 'package:smart_card_app_driver/services/bluetooth_service.dart'; // ADD THIS
import 'package:smart_card_app_driver/auth_interfaces/sign_in_page.dart';
import 'package:smart_card_app_driver/services/firestore_service.dart';
import 'package:smart_card_app_driver/services/auth_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthenticationService _auth = AuthenticationService();
  final FirestoreService _firestoreData = FirestoreService();

  String? name;
  String? email;
  String? phone;
  String? licenseNo;
  bool? isActive;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDriverData();
  }

  Future<void> _fetchDriverData() async {
    setState(() => _isLoading = true);

    try {
      final data = await _firestoreData.fetchDriverData();
      setState(() {
        name = data?['name'] ?? 'Unknown';
        email = data?['email'] ?? 'Unknown';
        phone = data?['phone'] ?? 'Unknown';
        licenseNo = data?['licenseNo'] ?? 'Unknown';
        isActive = data?['isActive'] ?? false;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile(
    String updatedName,
    String updatedPhone,
    [String? updatedLicenseNo]
  ) async {
    try {
      await _firestoreData.updateDriverProfile(
        updatedName: updatedName,
        updatedPhone: updatedPhone,
        updatedLicenseNo: updatedLicenseNo,
      );
      setState(() {
        name = updatedName;
        phone = updatedPhone;
        if (updatedLicenseNo != null) licenseNo = updatedLicenseNo;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: name);
    final phoneController = TextEditingController(text: phone);
    final licenseNoController = TextEditingController(text: licenseNo == 'Unknown' ? '' : licenseNo);

    final bool canEditLicenseNo = licenseNo == null || licenseNo!.isEmpty || licenseNo == 'Unknown';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Profile', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
              ),
              if (canEditLicenseNo) ...[
                TextField(
                  controller: licenseNoController,
                  decoration: const InputDecoration(labelText: 'License Number'),
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 8),
                Text(
                  '⚠️ Once set, license number cannot be changed!',
                  style: TextStyle(color: Colors.orange, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updatedName = nameController.text.trim();
              final updatedPhone = phoneController.text.trim();
              final updatedLicenseNo = canEditLicenseNo
                  ? licenseNoController.text.trim()
                  : null;

              if (canEditLicenseNo && (updatedLicenseNo == null || updatedLicenseNo.isEmpty)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('License number cannot be empty.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              await _updateProfile(updatedName, updatedPhone, updatedLicenseNo);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Access BluetoothService for status if you want
    final bluetoothService = Provider.of<BluetoothService>(context);
    final isBluetoothConnected = bluetoothService.connection != null;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Optional: Bluetooth status indicator
                  if (isBluetoothConnected)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bluetooth_connected, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            "NFC Reader Connected",
                            style: GoogleFonts.inter(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Color.fromRGBO(40, 49, 56, 1),
                    child: Icon(Icons.person, size: 60, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Profile',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromRGBO(40, 49, 56, 1),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Your account details',
                    style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 30),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProfileRow('Name', name ?? 'Unknown', Icons.person_outline),
                          const Divider(height: 20),
                          _buildProfileRow('Email', email ?? 'Unknown', Icons.email_outlined),
                          const Divider(height: 20),
                          _buildProfileRow('Phone', phone ?? 'Unknown', Icons.phone),
                          const Divider(height: 20),
                          _buildProfileRow('License Number', licenseNo ?? 'Unknown', Icons.card_membership),
                          const Divider(height: 20),
                          _buildStatusRow(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _showEditProfileDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromRGBO(40, 49, 56, 1),
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Edit Profile',
                      style: GoogleFonts.inter(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await _auth.signOut();
                        if (mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const SignInPage()),
                          );
                        }
                      } catch (e) {
                        final msg = e.toString().replaceFirst('Exception: ', '');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(msg),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Sign Out',
                      style: GoogleFonts.inter(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color.fromRGBO(40, 49, 56, 1)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
              ),
              Text(
                value,
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w500, color: const Color.fromRGBO(40, 49, 56, 1)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow() {
    return Row(
      children: [
        Icon(Icons.circle, color: isActive == true ? Colors.green : Colors.red),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Status',
                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
              ),
              Text(
                isActive == true ? 'Active' : 'Inactive',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: isActive == true ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}