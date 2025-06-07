// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, depend_on_referenced_packages, unnecessary_brace_in_string_interps

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:smart_card_app_driver/services/bluetooth_service.dart';
import 'package:smart_card_app_driver/services/live_location_service.dart';
import 'package:smart_card_app_driver/themes/colors.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? firstName;
  String? fullName;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchDriverFullName();
  }

  Future<void> fetchDriverFullName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc =
          await FirebaseFirestore.instance
              .collection('drivers')
              .doc(user.uid)
              .get();
      if (doc.exists) {
        final name = doc.data()?['name'] ?? '';
        if (name is String && name.isNotEmpty) {
          setState(() {
            fullName = name;
            firstName = name.split(' ').first;
            isLoading = false;
          });
        }
      }
    }
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _refreshData() async {
    await fetchDriverFullName();
  }

  @override
  Widget build(BuildContext context) {
    final bluetoothService = Provider.of<BluetoothService>(context);
    final isBluetoothConnected = bluetoothService.connection != null;

    // Live Location Service for sharing status
    final liveLocation = Provider.of<LiveLocationService>(context);
    final isSharing = liveLocation.isSharing;
    final selectedRouteName = liveLocation.selectedRouteName;

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: AppColors.accentGreen,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                isLoading ? 'Loading...' : 'Welcome, ${firstName ?? "Driver"}!',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Manage your driver profile',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppColors.grey600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Card with profile info
            Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              color: AppColors.primaryDark,
              child: Container(
                width: double.infinity,
                height: 200,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryDark.withOpacity(0.5),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Driver Profile',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'ACTIVE',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isLoading ? 'Loading...' : fullName ?? 'Driver',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        letterSpacing: 1,
                        color: Colors.white70,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const Spacer(),
                    Text(
                      'Status',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      isLoading ? 'Loading...' : 'Verified Driver',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            if (isLoading)
              const Center(
                child: CircularProgressIndicator(color: AppColors.accentGreen),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Connectivity Information',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            if (!isLoading) const SizedBox(height: 10),

            // Bluetooth status indicator
            Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 4.0, right: 4.0),
              child: Row(
                children: [
                  Icon(
                    isBluetoothConnected
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth_disabled,
                    color:
                        isBluetoothConnected
                            ? Colors.green
                            : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isBluetoothConnected
                        ? "NFC Reader Connected"
                        : "NFC Reader Not Connected",
                    style: GoogleFonts.inter(
                      color:
                          isBluetoothConnected
                              ? Colors.green
                              : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Live Location Sharing status indicator
            Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 4.0, right: 4.0),
              child: Row(
                children: [
                  Icon(
                    isSharing ? Icons.location_on : Icons.location_off,
                    color:
                        isSharing ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isSharing
                        ? "Live Location Sharing Active${selectedRouteName != null ? ' (${selectedRouteName})' : ''}"
                        : "Live Location Sharing Not Active",
                    style: GoogleFonts.inter(
                      color:
                          isSharing
                              ? Colors.green
                              : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
