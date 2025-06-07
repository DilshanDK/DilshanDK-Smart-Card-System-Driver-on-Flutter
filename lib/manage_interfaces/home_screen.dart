// ignore_for_file: library_private_types_in_public_api, unused_import

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_card_app_driver/manage_interfaces/home_page.dart';
import 'package:smart_card_app_driver/themes/colors.dart';
import 'package:firebase_auth/firebase_auth.dart'; // For Firebase Auth

import 'live_location_page.dart';
import 'bluetooth_page.dart';
import 'profile_page.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String? _driverId;

  @override
  void initState() {
    super.initState();
    _fetchDriverId();
  }

  Future<void> _fetchDriverId() async {
    // Assuming driver is authenticated with Firebase Auth
    User? user = FirebaseAuth.instance.currentUser;
    setState(() {
      _driverId = user?.uid;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Waiting for driverId to load before showing pages
    if (_driverId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ignore: no_leading_underscores_for_local_identifiers
    final List<Widget> _pages = [
      HomePage(),
      LiveLocationPage(driverId: _driverId!), // Pass authenticated driverId
      BluetoothPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        title: Text(
          'Smart Card Dashboard - Driver',
          style: GoogleFonts.inter(
            fontSize: 22,
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: AppColors.primaryDark,
        unselectedItemColor: AppColors.grey600,
        backgroundColor: AppColors.white,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.primaryDark,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.grey600,
        ),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.broadcast_on_home_rounded), label: 'Live Location'),
          BottomNavigationBarItem(icon: Icon(Icons.bluetooth_drive_outlined), label: 'NFC'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}