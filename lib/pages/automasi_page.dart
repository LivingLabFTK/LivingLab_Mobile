import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../utils/colors.dart';

class AutomasiPage extends StatefulWidget {
  const AutomasiPage({super.key});

  @override
  State<AutomasiPage> createState() => _AutomasiPageState();
}

class _AutomasiPageState extends State<AutomasiPage> {
  String mode = '...';
  bool pompaIrigasi = false;
  bool pompaPengaduk = false;
  bool pompaKuras = false;
  String lastUpdate = '...';
  bool isUpdating = false;
  bool isAuthenticated = false;

  late DatabaseReference _dataRef;

  @override
  void initState() {
    super.initState();
    _initializeAuthentication();
  }

  Future<void> _initializeAuthentication() async {
    try {
      await FirebaseAuth.instance.signInAnonymously();
      if (FirebaseAuth.instance.currentUser != null) {
        setState(() {
          isAuthenticated = true;
        });
        print("Autentikasi anonim berhasil");
        _initializeDbRef();
        _listenToRealtimeDatabase();
      }
    } catch (e) {
      print("Gagal autentikasi anonim: $e");
      if (!mounted) return;
      setState(() {
        lastUpdate = "Gagal autentikasi, coba lagi...";
      });
    }
  }

  void _initializeDbRef() {
    _dataRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL:
          'https://hydrohealth-project-9cf6c-default-rtdb.asia-southeast1.firebasedatabase.app/',
    ).ref("Kontrol_Panel");
  }

  void _listenToRealtimeDatabase() {
    _dataRef.onValue.listen((event) {
      if (!mounted || event.snapshot.value == null) {
        setState(() {
          lastUpdate = "Menunggu data...";
        });
        return;
      }

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      setState(() {
        mode = (data['mode'] ?? 'N/A').toString();
        pompaIrigasi = (data['pompa_irigasi'] ?? false) as bool;
        pompaPengaduk = (data['pompa_pengaduk'] ?? false) as bool;
        pompaKuras = (data['pompa_kuras'] ?? false) as bool;
        isUpdating = false;
        lastUpdate = "Update: ${DateFormat('HH:mm:ss').format(DateTime.now())}";
      });
    }, onError: (error) {
      setState(() {
        lastUpdate = "Gagal memuat data";
      });
      print("Error listening to database: $error");
    });
  }

  Future<void> _togglePumpStatus(String pumpName, bool currentStatus) async {
    if (isUpdating || !isAuthenticated) return;
    setState(() {
      isUpdating = true;
    });

    try {
      await _dataRef.update({pumpName: !currentStatus});
      if (mounted) {
        setState(() {
          lastUpdate =
              "Update: ${DateFormat('HH:mm:ss').format(DateTime.now())}";
        });
      }
      print("Status $pumpName updated to ${!currentStatus}");
    } catch (error) {
      print("Failed to update $pumpName: $error");
      if (mounted) {
        setState(() {
          isUpdating = false;
        });
      }
    }
  }

  Widget _buildPumpCard(
      String title, bool status, VoidCallback onToggle, String description) {
    return Card(
      elevation: 3.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              status ? Icons.power : Icons.power_off,
              color: AppColors.primary,
              size: 40,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.text),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status ? 'Hidup' : 'Mati',
                    style:
                        const TextStyle(fontSize: 20, color: AppColors.primary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                        fontSize: 12, color: AppColors.text.withOpacity(0.7)),
                  ),
                ],
              ),
            ),
            Switch(
              value: status,
              onChanged: (isUpdating || !isAuthenticated)
                  ? null
                  : (value) {
                      onToggle();
                    },
              activeColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Automasi', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(
                lastUpdate,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            elevation: 3.0,
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0)),
            color: mode == "AUTO" ? Colors.grey[300] : null,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(
                    Icons.settings,
                    color: mode == "AUTO" ? Colors.grey : AppColors.primary,
                    size: 40,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mode',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.text),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          mode,
                          style: TextStyle(
                              fontSize: 20,
                              color: mode == "AUTO"
                                  ? Colors.grey
                                  : AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildPumpCard(
            'Pompa Irigasi',
            pompaIrigasi,
            () => _togglePumpStatus('pompa_irigasi', pompaIrigasi),
            'Mengairi tanaman',
          ),
          _buildPumpCard(
            'Pompa Kuras',
            pompaKuras,
            () => _togglePumpStatus('pompa_kuras', pompaKuras),
            'Membersihkan tangki',
          ),
          _buildPumpCard(
            'Pompa Pengaduk',
            pompaPengaduk,
            () => _togglePumpStatus('pompa_pengaduk', pompaPengaduk),
            'Mengaduk nutrisi',
          ),
        ],
      ),
    );
  }
}
