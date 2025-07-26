import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../utils/colors.dart';

class RealtimePage extends StatefulWidget {
  const RealtimePage({super.key});

  @override
  State<RealtimePage> createState() => _RealtimePageState();
}

class _RealtimePageState extends State<RealtimePage> {
  String tds1 = '...';
  String tds2 = '...';
  String turbidity = '...';
  String level1 = '...';
  String level2 = '...';
  String flowRate = '...';
  String lastUpdate = '...';

  late DatabaseReference _dataRef;

  @override
  void initState() {
    super.initState();
    _initializeDbRef();
    _listenToRealtimeDatabase();
  }

  void _initializeDbRef() {
    final String todayPath = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _dataRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL:
          'https://hydrohealth-project-9cf6c-default-rtdb.asia-southeast1.firebasedatabase.app/',
    ).ref("Hydroponic_Data/$todayPath");
  }

  void _listenToRealtimeDatabase() {
    _dataRef.orderByKey().limitToLast(1).onValue.listen((event) {
      if (!mounted || event.snapshot.value == null) {
        setState(() {
          lastUpdate = "Menunggu data...";
        });
        return;
      }

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final timeKey = data.keys.first;
      final latestData = Map<String, dynamic>.from(data[timeKey]);

      setState(() {
        tds1 = (latestData['tds1_ppm'] ?? 'N/A').toString();
        tds2 = (latestData['tds2_ppm'] ?? 'N/A').toString();
        turbidity = (latestData['turbidity_ntu'] ?? 'N/A').toString();
        level1 = (latestData['level1_percent'] ?? 'N/A').toString();
        level2 = (latestData['level2_percent'] ?? 'N/A').toString();
        flowRate = (latestData['flow_rate_lpm'] ?? 'N/A').toString();

        final timestamp = DateTime.tryParse(latestData['timestamp_iso'] ?? '');
        if (timestamp != null) {
          lastUpdate = "Update: ${DateFormat('HH:mm:ss').format(timestamp)}";
        }
      });
    }, onError: (error) {
      setState(() {
        lastUpdate = "Gagal memuat data";
      });

      print("Error listening to database: $error");
    });
  }

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
          _buildSensorCard('TDS 1', tds1, 'PPM', Icons.water_drop),
          _buildSensorCard('TDS 2', tds2, 'PPM', Icons.water_drop_outlined),
          _buildSensorCard('Kekeruhan', turbidity, 'NTU', Icons.cloudy_snowing),
          _buildSensorCard(
              'Water Level 1', level1, '%', Icons.align_vertical_bottom),
          _buildSensorCard(
              'Water Level 2', level2, '%', Icons.align_vertical_center),
          _buildSensorCard('Aliran Air', flowRate, 'L/min', Icons.waves),
        ],
      ),
    );
  }
}
