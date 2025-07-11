import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hydrohealth/content/weather.dart';
import 'package:intl/intl.dart';

import '../utils/colors.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  // Referensi ke node Monitoring di Firebase
  final DatabaseReference ref = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL:
      'https://hydrohealth-project-9cf6c-default-rtdb.asia-southeast1.firebasedatabase.app')
      .ref('Monitoring');

  // Variabel untuk menampung data sensor
  String cuaca = 'Loading...';
  String kelembaban = 'Loading...';
  String nutrisi = 'Loading...';
  String suhu = 'Loading...';
  String ph = 'Loading...';
  String sisaLarutanKontainer = 'Loading...';
  String sisaNutrisiA = 'Loading...';
  String sisaNutrisiB = 'Loading...';
  String sisaPestisida = 'Loading...';
  String sisaPupukDaun = 'Loading...';
  String sisaPhDown = 'Loading...';
  String sisaPhUp = 'Loading...';

  @override
  void initState() {
    super.initState();
    _listenToRealtimeDatabase();
  }

  void _listenToRealtimeDatabase() {
    // Dengerin data terbaru aja pake limitToLast(1), lebih efisien!
    ref.limitToLast(1).onValue.listen((event) {
      if (!mounted) return;
      if (event.snapshot.value == null) return;

      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final latestEntry = data.values.first as Map<dynamic, dynamic>;

      setState(() {
        // Pastiin semua key ini SAMA PERSIS kayak di Firebase lo
        cuaca = (latestEntry['Cuaca'] ?? 'N/A').toString();
        kelembaban = (latestEntry['Kelembaban'] ?? 'N/A').toString();
        nutrisi = (latestEntry['Nutrisi'] ?? 'N/A').toString();
        suhu = (latestEntry['Suhu'] ?? 'N/A').toString();
        ph = (latestEntry['pH'] ?? 'N/A').toString();
        sisaLarutanKontainer =
            (latestEntry['Sisa Larutan Kontainer'] ?? 'N/A').toString();
        sisaNutrisiA = (latestEntry['SisaNutrisA'] ?? 'N/A').toString(); // Perhatikan key ini
        sisaNutrisiB = (latestEntry['SisaNutrisB'] ?? 'N/A').toString(); // Perhatikan key ini
        sisaPestisida = (latestEntry['SisaPestisida'] ?? 'N/A').toString();
        sisaPupukDaun = (latestEntry['SisaPupukDaun'] ?? 'N/A').toString();
        sisaPhDown = (latestEntry['SisaPhDown'] ?? 'N/A').toString();
        sisaPhUp = (latestEntry['Sisa pH Up'] ?? 'N/A').toString();
      });
    });
  }

  Widget _buildSensorCard(String title, String value, String unit) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.primary, width: 1.5),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'SFMono',
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '$value $unit',
          style: TextStyle(color: AppColors.text.withValues(alpha: 0.7), fontSize: 16),
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    return DateFormat.yMMMMd().format(date);
  }

  void _editPlantInfo(DocumentSnapshot document) {
    final data = document.data() as Map<String, dynamic>?;

    final TextEditingController nameController =
    TextEditingController(text: data?['name']);
    final TextEditingController countController =
    TextEditingController(text: data?['count'].toString());
    final TextEditingController plantingDateController = TextEditingController(
        text: data?['plantingDate'] != null
            ? _formatTimestamp(data!['plantingDate'])
            : '');
    final TextEditingController harvestDateController = TextEditingController(
        text: data?['harvestDate'] != null
            ? _formatTimestamp(data!['harvestDate'])
            : '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Plant Information'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
                TextField(controller: countController, decoration: const InputDecoration(labelText: 'Count'), keyboardType: TextInputType.number),
                TextField(
                  controller: plantingDateController,
                  decoration: const InputDecoration(labelText: 'Planting Date'),
                  onTap: () async {
                    DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2101));
                    if (picked != null) {
                      plantingDateController.text = DateFormat.yMMMMd().format(picked);
                    }
                  },
                ),
                TextField(
                  controller: harvestDateController,
                  decoration: const InputDecoration(labelText: 'Harvest Date'),
                  onTap: () async {
                    DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2101));
                    if (picked != null) {
                      harvestDateController.text = DateFormat.yMMMMd().format(picked);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                FirebaseFirestore.instance
                    .collection('InformasiTanaman')
                    .doc(document.id)
                    .update({
                  'name': nameController.text,
                  'count': int.parse(countController.text),
                  'plantingDate': Timestamp.fromDate(DateFormat.yMMMMd().parse(plantingDateController.text)),
                  'harvestDate': Timestamp.fromDate(DateFormat.yMMMMd().parse(harvestDateController.text)),
                });
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _deletePlantInfo(DocumentSnapshot document) {
    FirebaseFirestore.instance
        .collection('InformasiTanaman')
        .doc(document.id)
        .delete();
  }

  Widget _buildPlantInfoCard(DocumentSnapshot document) {
    final data = document.data() as Map<String, dynamic>?;

    final name = data?['name'] ?? 'Unknown Plant';
    final count = data?['count'] ?? 'N/A';
    final plantingDate = data?['plantingDate'] != null
        ? _formatTimestamp(data!['plantingDate'])
        : 'N/A';
    final harvestDate = data?['harvestDate'] != null
        ? _formatTimestamp(data!['harvestDate'])
        : 'N/A';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.primary, width: 1.5),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Stack(
        children: [
          ListTile(
            leading: const Icon(Icons.eco, color: AppColors.primary),
            title: Text(name, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Count: $count', style: TextStyle(color: AppColors.text.withValues(alpha: 0.7))),
                Text('Planting Date: $plantingDate', style: TextStyle(color: AppColors.text.withValues(alpha: 0.7))),
                Text('Harvest Date: $harvestDate', style: TextStyle(color: AppColors.text.withValues(alpha: 0.7))),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.edit, color: AppColors.primary), onPressed: () => _editPlantInfo(document)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => _deletePlantInfo(document)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Informasi Cuaca',
                style: TextStyle(fontFamily: 'SFMono', fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(20),
              child: WeatherPage(),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Text(
                'Monitoring Kondisi Hydrohealth',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text),
              ),
            ),
            _buildSensorCard('Monitoring Sensor Cuaca', cuaca, ''),
            _buildSensorCard('Monitoring Sensor Suhu', suhu, '°C'),
            _buildSensorCard('Monitoring Sensor Kelembaban', kelembaban, '%'),
            _buildSensorCard('Monitoring Sensor Ph', ph, ''),
            _buildSensorCard('Monitoring Sensor Nutrisi', nutrisi, 'PPM'),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Monitoring Kondisi Supplai',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text),
              ),
            ),
            _buildSensorCard('Sisa Larutan Kontainer', sisaLarutanKontainer, 'L'),
            _buildSensorCard('Sisa Nutrisi A', sisaNutrisiA, 'L'),
            _buildSensorCard('Sisa Nutrisi B', sisaNutrisiB, 'L'),
            _buildSensorCard('Sisa Pestisida', sisaPestisida, 'L'),
            _buildSensorCard('Sisa Pupuk Daun', sisaPupukDaun, 'L'),
            _buildSensorCard('Sisa pH Down', sisaPhDown, 'L'),
            _buildSensorCard('Sisa pH Up', sisaPhUp, 'L'),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Informasi Tanaman',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text),
              ),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('InformasiTanaman').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("Belum ada informasi tanaman."));
                }
                return Column(
                  children: snapshot.data!.docs.map((document) => _buildPlantInfoCard(document)).toList(),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}