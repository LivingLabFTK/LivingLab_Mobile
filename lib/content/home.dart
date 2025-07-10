import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hydrohealth/content/weather.dart';
import 'package:hydrohealth/services/notification_helper.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

final Logger _logger = Logger('Home');

void setupLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    _logger.info('${record.level.name}: ${record.time}: ${record.message}');
  });
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool mainPump = false;
  bool solutionStirrer = false;
  bool pestProtection = false;
  bool pesticideMisting = false;
  bool foliarFertilizerMisting = false;
  bool hydroponicPipeDrainValve = false;
  bool containerDrainValve = false;
  bool containerIntakeValve = false;

  final DatabaseReference ref = FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL:
              'https://hydrohealth-project-9cf6c-default-rtdb.asia-southeast1.firebasedatabase.app')
      .ref('Monitoring');

  final DatabaseReference controlPanelRef = FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL:
              'https://hydrohealth-project-9cf6c-default-rtdb.asia-southeast1.firebasedatabase.app')
      .ref('Kontrol_panel');

  String cuaca = 'Loading...';
  String kelembaban = 'Loading...';
  String nutrisi = 'Loading...';
  String suhu = 'Loading...';
  String timestamp = 'Loading...';
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
    NotificationHelper.initialize(); // Initialize notifications
    _listenToRealtimeDatabase();
    _loadControlPanelData();
  }

  void _listenToRealtimeDatabase() {
    ref.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>;

      // ignore: unnecessary_null_comparison
      if (data != null) {
        // Fetch the latest child node
        var latestEntry = data.entries.last.value;

        setState(() {
          cuaca = (latestEntry['Cuaca'] ?? 'N/A').toString();
          kelembaban = (latestEntry['Kelembaban'] ?? 'N/A').toString();
          nutrisi = (latestEntry['Nutrisi'] ?? 'N/A').toString();
          suhu = (latestEntry['Suhu'] ?? 'N/A').toString();
          timestamp = (latestEntry['Timestamp'] ?? 'N/A').toString();
          ph = (latestEntry['pH'] ?? 'N/A').toString();
          sisaLarutanKontainer =
              (latestEntry['Sisa Larutan Kontainer'] ?? 'N/A').toString();
          sisaNutrisiA = (latestEntry['SisaNutris'] ?? 'N/A').toString();
          // sisaNutrisiB = (latestEntry['Sisa Nutrisi B'] ?? 'N/A').toString();
          sisaPestisida = (latestEntry['SisaPestisida'] ?? 'N/A').toString();
          sisaPupukDaun = (latestEntry['SisaPupukDaun'] ?? 'N/A').toString();
          sisaPhDown = (latestEntry['SisaPhDown'] ?? 'N/A').toString();
          sisaPhUp = (latestEntry['Sisa pH Up'] ?? 'N/A').toString();
        });

        _checkAndSendNotifications();
      }
    });
  }

  void _checkAndSendNotifications() {
    _logger.info('Checking notifications...');
    _logger.info('Current pH: $ph');
    _logger.info('Current Nutrisi: $nutrisi');

    // if (double.tryParse(ph) != null && double.parse(ph) < 5) {
    //   print('pH below 5, sending notification...');
    //   NotificationHelper.showNotification(
    //     'Peringatan pH',
    //     'Ph di bawah 5 Anda perlu menaikan Ph',
    //     'ph_low',
    //   );
    // }

    // if (double.tryParse(nutrisi) != null && double.parse(nutrisi) < 800) {
    //   print('Nutrisi below 800, sending notification...');
    //   NotificationHelper.showNotification(
    //     'Peringatan Nutrisi',
    //     'Nutrisi di bawah 800ppm, saatnya tambahkan nutrisi',
    //     'nutrisi_low',
    //   );
    // }
  }

  void _loadControlPanelData() {
    controlPanelRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>;

      // ignore: unnecessary_null_comparison
      if (data != null) {
        setState(() {
          mainPump = (data['Pompa_air'] ?? false);
          solutionStirrer = (data['Pengaduk_larutan'] ?? false);
          pestProtection = (data['Pelindung Hama'] ?? false);
          pesticideMisting = (data['Misting_pestisida'] ?? false);
          foliarFertilizerMisting = (data['Misting_pupuk'] ?? false);
          hydroponicPipeDrainValve =
              (data['Pembuangan Pipa Hidroponik'] ?? false);
          containerDrainValve = (data['Pembuangan_air'] ?? false);
          containerIntakeValve = (data['Peasukan_air'] ?? false);
        });
      }
    });
  }

  void _updateDatabase(String key, bool value) {
    controlPanelRef.update({key: value});
  }

  Widget _buildSensorCard(String title, String value, String unit) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE1F0DA), // Light Green
        border:
            Border.all(color: const Color(0xFF99BC85), width: 2), // Dark Green
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'poppins',
            color: Color(0xFF99BC85), // Dark Green
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '$value $unit',
          style: const TextStyle(color: Colors.black54),
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
    final TextEditingController plantingDateController =
        TextEditingController(text: _formatTimestamp(data?['plantingDate']));
    final TextEditingController harvestDateController =
        TextEditingController(text: _formatTimestamp(data?['harvestDate']));

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Plant Information'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: countController,
                decoration: const InputDecoration(labelText: 'Count'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: plantingDateController,
                decoration: const InputDecoration(labelText: 'Planting Date'),
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (picked != null) {
                    plantingDateController.text =
                        DateFormat.yMMMMd().format(picked);
                  }
                },
              ),
              TextField(
                controller: harvestDateController,
                decoration: const InputDecoration(labelText: 'Harvest Date'),
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (picked != null) {
                    harvestDateController.text =
                        DateFormat.yMMMMd().format(picked);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                FirebaseFirestore.instance
                    .collection('InformasiTanaman')
                    .doc(document.id)
                    .update({
                  'name': nameController.text,
                  'count': int.parse(countController.text),
                  'plantingDate': Timestamp.fromDate(
                      DateFormat.yMMMMd().parse(plantingDateController.text)),
                  'harvestDate': Timestamp.fromDate(
                      DateFormat.yMMMMd().parse(harvestDateController.text)),
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
        ? _formatTimestamp(data?['plantingDate'])
        : 'N/A';
    final harvestDate = data?['harvestDate'] != null
        ? _formatTimestamp(data?['harvestDate'])
        : 'N/A';

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE1F0DA), // Light Green
        border:
            Border.all(color: const Color(0xFF99BC85), width: 2), // Dark Green
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: [
          ListTile(
            leading: const Icon(
              Icons.eco,
              color: Color(0xFF99BC85), // Dark Green
            ),
            title: Text(
              name,
              style: const TextStyle(
                color: Color(0xFF99BC85), // Dark Green
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Count: $count',
                    style: const TextStyle(color: Colors.black54)),
                Text('Planting Date: $plantingDate',
                    style: const TextStyle(color: Colors.black54)),
                Text('Harvest Date: $harvestDate',
                    style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit,
                      color: Color(0xFF99BC85)), // Dark Green
                  onPressed: () {
                    _editPlantInfo(document);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete,
                      color: Color(0xFF99BC85)), // Dark Green
                  onPressed: () {
                    _deletePlantInfo(document);
                  },
                ),
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
      backgroundColor: const Color(0xFFD4E7C5), // Very Light Green
      body: SafeArea(
        child: ListView(
          children: [
            // Weather Information
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'Informasi Cuaca',
                style: TextStyle(
                  fontFamily: 'SFMono',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF99BC85), // Dark Green
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(20),
              child: WeatherPage(),
            ),

            // Live cam
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF99BC85), // Dark Green
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Text(
                    'Live Cam',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            // Switch Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE1F0DA), // Light Green
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF99BC85), // Dark Green
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Center(
                        child: Column(
                          children: [
                            const Text(
                              'Control Panel',
                              style: TextStyle(
                                fontFamily: 'SFMono',
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF99BC85), // Dark Green
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              width: double.infinity,
                              height: 2,
                              color: const Color(0xFF99BC85), // Dark Green
                            ),
                          ],
                        ),
                      ),
                    ),
                    _buildControlGroup('Sistem Utama', [
                      _buildSwitchRow('Pompa Utama', mainPump, (value) {
                        setState(() {
                          mainPump = value;
                        });
                        _updateDatabase('Pompa Utama', value);
                      }),
                      _buildSwitchRow('Pengaduk Larutan', solutionStirrer,
                          (value) {
                        setState(() {
                          solutionStirrer = value;
                        });
                        _updateDatabase('Pengaduk Larutan', value);
                      }),
                    ]),
                    const SizedBox(height: 20),
                    _buildControlGroup('Sistem Proteksi', [
                      _buildSwitchRow('Pelindung Hama', pestProtection,
                          (value) {
                        setState(() {
                          pestProtection = value;
                        });
                        _updateDatabase('Pelindung Hama', value);
                      }),
                      _buildSwitchRow('Misting Pestisida', pesticideMisting,
                          (value) {
                        setState(() {
                          pesticideMisting = value;
                        });
                        _updateDatabase('Misting Pestisida', value);
                      }),
                      _buildSwitchRow(
                          'Misting Pupuk Daun', foliarFertilizerMisting,
                          (value) {
                        setState(() {
                          foliarFertilizerMisting = value;
                        });
                        _updateDatabase('Misting Pupuk Daun', value);
                      }),
                    ]),
                    const SizedBox(height: 20),
                    _buildControlGroup('Selenoid Valve Kontrol', [
                      _buildSwitchRow('Pembuangan Pipa Hidroponik',
                          hydroponicPipeDrainValve, (value) {
                        setState(() {
                          hydroponicPipeDrainValve = value;
                        });
                        _updateDatabase('Pembuangan Pipa Hidroponik', value);
                      }),
                      _buildSwitchRow(
                          'Pembuangan ke Kontainer', containerDrainValve,
                          (value) {
                        setState(() {
                          containerDrainValve = value;
                        });
                        _updateDatabase('Pembuangan ke Kontainer', value);
                      }),
                      _buildSwitchRow(
                          'Pemasukan ke Kontainer', containerIntakeValve,
                          (value) {
                        setState(() {
                          containerIntakeValve = value;
                        });
                        _updateDatabase('Pemasukan ke Kontainer', value);
                      }),
                    ]),
                  ],
                ),
              ),
            ),

            // Monitoring Text
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Monitoring Kondisi Hydrohealth',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF99BC85), // Dark Green
                ),
              ),
            ),
            // List Column
            _buildSensorCard('Monitoring Sensor Cuaca', cuaca, ''),
            _buildSensorCard('Monitoring Sensor Suhu', suhu, '°C'),
            _buildSensorCard('Monitoring Sensor Kelembaban', kelembaban, '%'),
            _buildSensorCard('Monitoring Sensor Ph', ph, ''),
            _buildSensorCard('Monitoring Sensor Nutrisi', nutrisi, ''),
            const Padding(
              padding: EdgeInsets.all(10),
              child: Text(
                'Monitoring Kondisi Supplai',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF99BC85), // Dark Green
                ),
              ),
            ),
            _buildSensorCard(
                'Sisa Larutan Kontainer', sisaLarutanKontainer, 'L'),
            _buildSensorCard('Sisa Nutrisi A', sisaNutrisiA, 'L'),
            _buildSensorCard('Sisa Nutrisi B', sisaNutrisiB, 'L'),
            _buildSensorCard('Sisa Pestisida', sisaPestisida, 'L'),
            _buildSensorCard('Sisa Pupuk Daun', sisaPupukDaun, 'L'),
            _buildSensorCard('Sisa pH Down', sisaPhDown, 'L'),
            _buildSensorCard('Sisa pH Up', sisaPhUp, 'L'),
            // Plant Info from Firestore
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Informasi Tanaman',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF99BC85), // Dark Green
                ),
              ),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('InformasiTanaman')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                return Column(
                  children: snapshot.data!.docs.map((document) {
                    return Column(
                      children: [
                        _buildPlantInfoCard(document),
                        const Divider(
                          color: Color(0xFF99BC85), // Dark Green
                          thickness: 1,
                        ),
                      ],
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlGroup(String title, List<Widget> controls) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: 'poppins',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF99BC85), // Dark Green
            ),
          ),
        ),
        ...controls,
      ],
    );
  }

  Widget _buildSwitchRow(
      String title, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'poppins',
              color: Color(0xFF99BC85), // Dark Green
              fontWeight: FontWeight.bold,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF99BC85), // Dark Green
          ),
        ],
      ),
    );
  }
}
