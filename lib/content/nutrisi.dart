import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:hydrohealth/services/notification_helper.dart';
import 'package:speedometer_chart/speedometer_chart.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:excel/excel.dart';

class NutrisiLog extends StatefulWidget {
  const NutrisiLog({super.key});

  @override
  State<NutrisiLog> createState() => _NutrisiLogState();
}

class _NutrisiLogState extends State<NutrisiLog> {
  final DatabaseReference ref = FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL:
              'https://hydrohealth-project-9cf6c-default-rtdb.asia-southeast1.firebasedatabase.app')
      .ref('Monitoring');

  final CollectionReference _firestoreRef =
      FirebaseFirestore.instance.collection('NutrisiLog');
  List<Map<String, dynamic>> _logs = [];
  double _currentNutrisiValue = 0.0;
  bool _showAllLogs = false;

  @override
  void initState() {
    super.initState();
    NotificationHelper.initialize(); // Initialize notifications
    _fetchLogs();
    _listenToRealtimeDatabase();
  }

  void _fetchLogs() async {
    try {
      final querySnapshot = await _firestoreRef
          .orderBy('timestamp', descending: true)
          .limit(_showAllLogs ? 1000 : 20)
          .get();
      setState(() {
        _logs = querySnapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
            .toList();
      });
    } catch (e) {
      print('Error fetching logs from Firestore: $e');
    }
  }

  void _listenToRealtimeDatabase() {
    ref.limitToLast(1).onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      final latestData = data?.values.last as Map?;
      final nutrisi = latestData?['Nutrisi'];

      setState(() {
        _currentNutrisiValue =
            nutrisi != null ? (nutrisi as num).toDouble() : 0.0;
      });
      if (_currentNutrisiValue < 800) {
        NotificationHelper.showNotification(
          'Peringatan Nutrisi',
          'Nutrisi di bawah 800ppm, saatnya tambahkan nutrisi',
          'nutrisi_low',
        );
      }
    });
  }

  void _deleteLog(String id) async {
    try {
      await _firestoreRef.doc(id).delete();
      _fetchLogs();
    } catch (e) {
      print('Error deleting log: $e');
    }
  }

  void _deleteAllLogs() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final querySnapshot = await _firestoreRef.get();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      _fetchLogs();
    } catch (e) {
      print('Error deleting all logs: $e');
    }
  }

  Future<void> _requestPermission() async {
    if (await Permission.storage.request().isGranted) {
      _exportLogsToExcel();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Storage permission is required to save logs.')),
      );
    }
  }

  Future<void> _exportLogsToExcel() async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['LogHistory'];
    sheetObject.appendRow([
      TextCellValue('Timestamp'),
      TextCellValue('Nutrisi Value')
    ]); // Header

    for (var log in _logs) {
      final timestamp = (log['timestamp'] as Timestamp).toDate();
      final formattedDate =
          '${timestamp.day}-${timestamp.month}-${timestamp.year} ${timestamp.hour}:${timestamp.minute}:${timestamp.second}';
      sheetObject.appendRow([
        TextCellValue(formattedDate),
        DoubleCellValue((log['value'] as num).toDouble())
      ]);
    }

    final fileBytes = excel.save();
    if (fileBytes != null) {
      try {
        final directory = await getExternalStorageDirectory();
        final path = '${directory!.path}/NutrisiLog.xlsx';
        final file = File(path)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);

        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Logs exported to $path')));

        await OpenFile.open(path);
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error writing file: $e')));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error generating Excel file.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE1F0DA),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: const Color(0xFF99BC85),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Kondisi Saat ini:',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.circle, color: Colors.red, size: 10),
                          SizedBox(width: 5),
                          Text('Kurang Nutrisi'),
                        ],
                      ),
                      SizedBox(width: 15),
                      Row(
                        children: [
                          Icon(Icons.circle, color: Colors.yellow, size: 10),
                          SizedBox(width: 5),
                          Text('Cukup Nutrisi'),
                        ],
                      ),
                      SizedBox(width: 15),
                      Row(
                        children: [
                          Icon(Icons.circle, color: Colors.green, size: 10),
                          SizedBox(width: 5),
                          Text('Optimal Nutrisi'),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SpeedometerChart(
                    dimension: 200,
                    minValue: 0,
                    maxValue: 1800,
                    value: _currentNutrisiValue,
                    graphColor: const [Colors.red, Colors.yellow, Colors.green],
                    pointerColor: Colors.black,
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder(
                    stream: ref.onValue,
                    builder: (context, nutrisiSnapshot) {
                      if (nutrisiSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }
                      if (nutrisiSnapshot.hasError) {
                        return Text('Error: ${nutrisiSnapshot.error}');
                      }
                      final data = nutrisiSnapshot.data?.snapshot.value as Map?;
                      final latestData = data?.values.last as Map?;
                      final nutrisi = latestData?['Nutrisi'] ?? 'N/A';
                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.science,
                                  color: Colors.green, size: 30),
                              const SizedBox(width: 10),
                              Text(
                                'Nutrisi: $nutrisi ppm',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 20,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: const Color(0xFF99BC85),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Log History',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      final timestamp =
                          (log['timestamp'] as Timestamp).toDate();
                      final formattedDate =
                          '${timestamp.day}-${timestamp.month}-${timestamp.year} ${timestamp.hour}:${timestamp.minute}:${timestamp.second}';
                      return ListTile(
                        title: Text('Nutrisi Value: ${log['value']} ppm'),
                        subtitle: Text('Timestamp: $formattedDate'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_sharp,
                              color: Color.fromARGB(255, 0, 0, 0)),
                          onPressed: () => _deleteLog(log['id']),
                        ),
                      );
                    },
                  ),
                  if (!_showAllLogs)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showAllLogs = true;
                        });
                        _fetchLogs();
                      },
                      child: const Text('Load More'),
                    ),
                  if (_showAllLogs)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showAllLogs = false;
                        });
                        _fetchLogs();
                      },
                      child: const Text('Show Less'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showOptionsDialog,
        backgroundColor: const Color(0xFF99BC85),
        child: const Icon(Icons.more_vert, color: Colors.white),
      ),
    );
  }

  void _showOptionsDialog() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.delete_forever),
              title: const Text('Delete All Logs'),
              onTap: () {
                Navigator.pop(context);
                _deleteAllLogs();
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Download Logs as Excel'),
              onTap: () {
                Navigator.pop(context);
                _requestPermission();
              },
            ),
          ],
        );
      },
    );
  }
}
