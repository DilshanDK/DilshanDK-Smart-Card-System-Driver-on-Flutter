// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_card_app_driver/services/bluetooth_service.dart';
import 'package:smart_card_app_driver/themes/colors.dart';

class BluetoothPage extends StatefulWidget {
  const BluetoothPage({super.key});

  @override
  State<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BluetoothService>(context, listen: false).initialize();
    });
  }

  Future<void> _connect(BluetoothDevice device) async {
    final bluetoothService = Provider.of<BluetoothService>(context, listen: false);
    try {
      final success = await bluetoothService.connect(device);
      if (success) {
        _showSnackBar(
          'Connected to ${device.name ?? device.address}',
          color: Colors.green,
        );
      } else {
        _showSnackBar('Failed to connect to device.', color: AppColors.errorRed);
      }
    } catch (e, stack) {
      developer.log('Error connecting to device: $e', error: e, stackTrace: stack);
      _showSnackBar('Error connecting to device.', color: AppColors.errorRed);
    }
  }

  Future<void> _disconnect() async {
    final bluetoothService = Provider.of<BluetoothService>(context, listen: false);
    try {
      final success = await bluetoothService.disconnect();
      if (success) {
        _showSnackBar('Disconnected successfully.', color: Colors.red);
      } else {
        _showSnackBar('Failed to disconnect.', color: AppColors.errorRed);
      }
    } catch (e, stack) {
      developer.log('Error disconnecting: $e', error: e, stackTrace: stack);
      _showSnackBar('Error disconnecting.', color: AppColors.errorRed);
    }
  }

  Future<void> _refresh() async {
    final bluetoothService = Provider.of<BluetoothService>(context, listen: false);
    try {
      await bluetoothService.refreshDevices();
      _showSnackBar('Device list refreshed.', color: AppColors.accentGreen);
    } catch (e, stack) {
      developer.log('Error refreshing devices: $e', error: e, stackTrace: stack);
      _showSnackBar('Failed to refresh devices.', color: AppColors.errorRed);
    }
  }

  void _clearKeys() {
    final bluetoothService = Provider.of<BluetoothService>(context, listen: false);
    bluetoothService.clearReceivedKeyRecords();
    _showSnackBar('Key list cleared.', color: Colors.green);
  }

  void _showSnackBar(String message, {Color color = Colors.green}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    return "${timestamp.hour.toString().padLeft(2, '0')}:"
        "${timestamp.minute.toString().padLeft(2, '0')}:"
        "${timestamp.second.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BluetoothService>(
      builder: (context, bluetoothService, child) {
        final connectedDevice = bluetoothService.getConnectedDevice();
        final isConnecting = bluetoothService.isConnecting;
        final isDisconnecting = bluetoothService.disconnectingInProgress;
        final receivedKeys = bluetoothService.receivedKeyRecords;

        return Scaffold(
          backgroundColor: AppColors.white,
          body: RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.accentGreen,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bluetooth Devices',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connect to your NFC reader',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: AppColors.grey600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    color: AppColors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (connectedDevice != null)
                            Card(
                              color: AppColors.white.withOpacity(0.9),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: AppColors.accentGreen,
                                  width: 1,
                                ),
                              ),
                              elevation: 2,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: Icon(
                                  Icons.bluetooth_connected,
                                  color: AppColors.primaryDark,
                                  size: 32,
                                ),
                                title: Text(
                                  connectedDevice.name ?? 'Unknown Device',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      connectedDevice.address,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Status: Connected',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: AppColors.primaryDark,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: isDisconnecting
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(
                                            AppColors.errorRed,
                                          ),
                                        ),
                                      )
                                    : ElevatedButton(
                                        onPressed: _disconnect,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.errorRed,
                                          foregroundColor: AppColors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                        ),
                                        child: Text(
                                          'Disconnect',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                              ),
                            )
                          else if (bluetoothService.devices.isEmpty)
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.bluetooth_searching,
                                    size: 50,
                                    color: AppColors.grey600,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'No paired devices found',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      color: AppColors.grey600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _refresh,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.accentGreen,
                                      foregroundColor: AppColors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 12,
                                      ),
                                    ),
                                    child: Text(
                                      'Refresh Devices',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: bluetoothService.devices.length,
                              itemBuilder: (context, index) {
                                final device = bluetoothService.devices[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    title: Text(
                                      device.name ?? 'Unknown Device',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: device.name?.contains('HC') == true
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                    subtitle: Text(
                                      device.address,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: AppColors.grey600,
                                      ),
                                    ),
                                    trailing: isConnecting
                                        ? const SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation(
                                                Colors.green,
                                              ),
                                            ),
                                          )
                                        : ElevatedButton(
                                            onPressed: () => _connect(device),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: AppColors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 8,
                                              ),
                                            ),
                                            child: Text(
                                              'Connect',
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Show the received mapped key values
                  Text(
                    'Received Key Values',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: receivedKeys.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Text(
                                  "No keys received yet.",
                                  style: GoogleFonts.inter(
                                    color: AppColors.grey600,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: receivedKeys.length,
                              itemBuilder: (context, index) {
                                final record = receivedKeys[index];
                                return ListTile(
                                  leading: Icon(Icons.vpn_key, color: AppColors.accentGreen),
                                  title: Text(
                                    record.key,
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                  subtitle: Text("UID: ${record.uid}"),
                                  trailing: Text(_formatTimestamp(record.timestamp)),
                                );
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _clearKeys,
                    icon: const Icon(Icons.delete, size: 20, color: AppColors.primaryDark),
                    label: Text(
                      'Clear List',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.errorRed,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 2,
                      minimumSize: const Size(double.infinity, 56),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}