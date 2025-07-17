import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:hydrohealth/content/weather.dart';

import '../utils/colors.dart';

class RealtimePage extends StatefulWidget {
  const RealtimePage({super.key});

  @override
  State<RealtimePage> createState() => _RealtimePageState();
}

class _RealtimePageState extends State<RealtimePage> {
  final DatabaseReference ref = FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL:
              'https://hydrohealth-project-9cf6c-default-rtdb.asia-southeast1.firebasedatabase.app')
      .ref('Monitoring');

  String suhu = '...';
  String kelembaban = '...';
  String ph = '...';
  String nutrisi = '...';
  String sisaLarutanKontainer = '...';

  @override
  void initState() {
    super.initState();
    _listenToRealtimeDatabase();
  }

  void _listenToRealtimeDatabase() {
    ref.limitToLast(1).onValue.listen((event) {
      if (!mounted) return;
      if (event.snapshot.value == null) return;

      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final latestEntry = data.values.first as Map<dynamic, dynamic>;

      setState(() {
        suhu = (latestEntry['Suhu'] ?? 'N/A').toString();
        kelembaban = (latestEntry['Kelembaban'] ?? 'N/A').toString();
        ph = (latestEntry['pH'] ?? 'N/A').toString();
        nutrisi = (latestEntry['Nutrisi'] ?? 'N/A').toString();
        sisaLarutanKontainer =
            (latestEntry['Sisa Larutan Kontainer'] ?? 'N/A').toString();
      });
    });
  }

  Widget _buildSensorCard(
      String title, String value, String unit, IconData icon) {
    return Card(
      elevation: 4.0,
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary, size: 40),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$value $unit', style: const TextStyle(fontSize: 18)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Realtime Data'),
        backgroundColor: AppColors.primary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const WeatherPage(),
          const SizedBox(height: 20),
          _buildSensorCard('Suhu', suhu, '°C', Icons.thermostat_outlined),
          _buildSensorCard(
              'Kelembaban', kelembaban, '%', Icons.water_drop_outlined),
          _buildSensorCard('pH Air', ph, '', Icons.science_outlined),
          _buildSensorCard('Nutrisi (TDS)', nutrisi, 'PPM', Icons.eco_outlined),
          _buildSensorCard('Sisa Larutan', sisaLarutanKontainer, 'L',
              Icons.local_drink_outlined),
        ],
      ),
    );
  }
}
