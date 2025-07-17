// lib/pages/realtime_page.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../utils/colors.dart';

class RealtimePage extends StatefulWidget {
  const RealtimePage({super.key});

  @override
  State<RealtimePage> createState() => _RealtimePageState();
}

class _RealtimePageState extends State<RealtimePage> {
  // Mengarahkan ke root database untuk mendapatkan data terbaru
  final DatabaseReference ref = FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL:
              'https://hydrohealth-project-9cf6c-default-rtdb.asia-southeast1.firebasedatabase.app/')
      .ref('Hydroponic_Data');

  // Variabel untuk menampung setiap nilai sensor
  String tds1 = '...';
  String tds2 = '...';
  String turbidity = '...';
  String level1 = '...';
  String level2 = '...';
  String flowRate = '...';
  String lastUpdate = '...';

  @override
  void initState() {
    super.initState();
    _listenToRealtimeDatabase();
  }

  void _listenToRealtimeDatabase() {
    // Mengambil 1 data terakhir yang masuk
    ref.limitToLast(1).onValue.listen((event) {
      if (!mounted || event.snapshot.value == null) return;

      // Struktur data disesuaikan dengan JSON yang kamu berikan
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final latestEntryKey = data.keys.first;
      final latestEntry = Map<String, dynamic>.from(data[latestEntryKey]);

      setState(() {
        tds1 = (latestEntry['tds1_ppm'] ?? 'N/A').toString();
        tds2 = (latestEntry['tds2_ppm'] ?? 'N/A').toString();
        turbidity = (latestEntry['turbidity_ntu'] ?? 'N/A').toString();
        level1 = (latestEntry['level1_percent'] ?? 'N/A').toString();
        level2 = (latestEntry['level2_percent'] ?? 'N/A').toString();
        flowRate = (latestEntry['flow_rate_lpm'] ?? 'N/A').toString();

        // Menampilkan waktu update terakhir
        final timestamp = DateTime.tryParse(latestEntry['timestamp_iso'] ?? '');
        if (timestamp != null) {
          lastUpdate =
              "Update: ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}";
        }
      });
    }, onError: (error) {
      // Handle error jika ada
      setState(() {
        lastUpdate = "Gagal memuat data";
      });
    });
  }

  // Widget template untuk setiap kartu sensor
  Widget _buildSensorCard(
      String title, String value, String unit, IconData icon) {
    return Card(
      elevation: 3.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.text)),
                  const SizedBox(height: 4),
                  Text('$value $unit',
                      style: const TextStyle(
                          fontSize: 20, color: AppColors.primary)),
                ],
              ),
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
        title:
            const Text('Realtime Data', style: TextStyle(color: Colors.white)),
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
          // Menampilkan kartu sensor sesuai permintaan baru
          _buildSensorCard('TDS 1', tds1, 'PPM', Icons.water_drop),
          _buildSensorCard('TDS 2', tds2, 'PPM', Icons.water_drop_outlined),
          _buildSensorCard('Kekeruhan', turbidity, 'NTU', Icons.cloudy_snowing),
          _buildSensorCard('Level 1', level1, '%', Icons.align_vertical_bottom),
          _buildSensorCard('Level 2', level2, '%', Icons.align_vertical_center),
          _buildSensorCard('Aliran Air', flowRate, 'L/min', Icons.waves),
        ],
      ),
    );
  }
}
