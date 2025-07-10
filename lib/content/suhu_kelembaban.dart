import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:excel/excel.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:logging/logging.dart';

final Logger _logger = Logger('SuhuKelembapan');

void setupLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    _logger.info('${record.level.name}: ${record.time}: ${record.message}');
  });
}

class SuhuKelembaban extends StatefulWidget {
  const SuhuKelembaban({super.key});

  @override
  State<SuhuKelembaban> createState() => _SuhuKelembabanState();
}

class _SuhuKelembabanState extends State<SuhuKelembaban> {
  final DatabaseReference monitoringRef = FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL:
              'https://hydrohealth-project-9cf6c-default-rtdb.asia-southeast1.firebasedatabase.app')
      .ref('Monitoring');

  final CollectionReference _firestoreRef =
      FirebaseFirestore.instance.collection('SuhuKelembabanLog');

  List<Map<String, dynamic>> _logs = [];
  Timer? _timer;
  bool _showAllLogs = false;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
    _startUpdatingData();
  }

  void _startUpdatingData() {
    const updateInterval = Duration(minutes: 15);

    void onDataUpdated(Timer timer) {
      _fetchLogs();
    }

    _timer = Timer.periodic(updateInterval, onDataUpdated);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
            .toList(); // Ensure latest logs are at the top for history
      });
    } catch (e) {
      _logger.info('Error fetching logs from Firestore: $e');
    }
  }

  void _deleteLog(String id) async {
    try {
      await _firestoreRef.doc(id).delete();
      _fetchLogs();
    } catch (e) {
      _logger.info('Error deleting log: $e');
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
      _logger.info('Error deleting all logs: $e');
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
      TextCellValue('Suhu (°C)'),
      TextCellValue('Kelembaban (%)')
    ]); // Header

    for (var log in _logs) {
      final timestamp = (log['timestamp'] as Timestamp).toDate();
      final formattedDate =
          '${timestamp.day}-${timestamp.month}-${timestamp.year} ${timestamp.hour}:${timestamp.minute}:${timestamp.second}';
      sheetObject.appendRow([
        TextCellValue(formattedDate),
        IntCellValue(log['suhu'] ?? 0), // Provide default value if null
        IntCellValue(log['kelembaban'] ?? 0) // Provide default value if null
      ]);
    }

    final fileBytes = excel.save();
    if (fileBytes != null) {
      try {
        final directory = await getExternalStorageDirectory();
        final path = await _showSaveFileDialog(context, directory!.path);
        if (path != null) {
          // ignore: unused_local_variable
          final file = File(path)
            ..createSync(recursive: true)
            ..writeAsBytesSync(fileBytes);

          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Logs exported to $path')));

          // Open the file
          await OpenFile.open(path);
        }
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

  Future<String?> _showSaveFileDialog(
      BuildContext context, String initialDirectory) async {
    TextEditingController fileNameController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Save As'),
          content: TextField(
            controller: fileNameController,
            decoration: const InputDecoration(hintText: "Enter file name"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('CANCEL'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('SAVE'),
              onPressed: () {
                String fileName = fileNameController.text;
                if (fileName.isNotEmpty) {
                  Navigator.of(context).pop('$initialDirectory/$fileName.xlsx');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('File name cannot be empty')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  List<FlSpot> _createSuhuChartData() {
    return _logs
        .asMap()
        .entries
        .map((entry) => FlSpot(
            (_logs.length - entry.key - 1).toDouble(),
            (entry.value['suhu'] ?? 0)
                .toDouble())) // Provide default value if null
        .toList();
  }

  List<FlSpot> _createKelembabanChartData() {
    return _logs
        .asMap()
        .entries
        .map((entry) => FlSpot(
            (_logs.length - entry.key - 1).toDouble(),
            (entry.value['kelembaban'] ?? 0)
                .toDouble())) // Provide default value if null
        .toList();
  }

  String _formatTimeLabel(double value) {
    int index = _logs.length - value.toInt() - 1;
    if (index < 0 || index >= _logs.length) return '';
    final timestamp = _logs[index]['timestamp'] as Timestamp;
    final date = timestamp.toDate();
    return '${date.hour}:${date.minute}';
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
                    color: Colors.grey.withValues(alpha: 0.5),
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: const Offset(0, 3), // changes position of shadow
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
                  StreamBuilder(
                    stream: monitoringRef.limitToLast(1).onValue,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }
                      if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      }
                      final data = snapshot.data?.snapshot.value as Map?;
                      final latestData = data?.values.last as Map?;
                      final suhu = latestData?['Suhu'] ?? 'N/A';
                      final kelembaban = latestData?['Kelembaban'] ?? 'N/A';
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.thermostat,
                                  color: Colors.red, size: 30),
                              const SizedBox(width: 10),
                              Text(
                                'Suhu: ${suhu}°C',
                                style: const TextStyle(
                                    color: Colors.black, fontSize: 20),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.water_drop,
                                  color: Colors.blue, size: 30),
                              const SizedBox(width: 10),
                              Text(
                                'Kelembaban: ${kelembaban}%',
                                style: const TextStyle(
                                    color: Colors.black, fontSize: 20),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Temperature (Suhu)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: true),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 35,
                              getTitlesWidget: (value, meta) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    _formatTimeLabel(
                                        value), // Use formatted label
                                    style: const TextStyle(
                                      color: Color(0xFF68737D),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Text(
                                    '${value.toInt()}°C', // Display as temperature values
                                    style: const TextStyle(
                                        color: Color(0xFF68737D),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: true),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _createSuhuChartData(),
                            isCurved: true,
                            color: Colors.red,
                            barWidth: 3,
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.red.withValues(alpha: 0.3),
                                  Colors.red.withValues(alpha: 0.0),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            dotData: const FlDotData(show: true),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Humidity (Kelembaban)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: true),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 35,
                              getTitlesWidget: (value, meta) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    _formatTimeLabel(
                                        value), // Use formatted label
                                    style: const TextStyle(
                                      color: Color(0xFF68737D),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Text(
                                    '${value.toInt()}%', // Display as humidity values
                                    style: const TextStyle(
                                        color: Color(0xFF68737D),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: true),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _createKelembabanChartData(),
                            isCurved: true,
                            color: Colors.blue,
                            barWidth: 3,
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.withValues(alpha: 0.3),
                                  Colors.blue.withValues(alpha: 0.0),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            dotData: const FlDotData(show: true),
                          ),
                        ],
                      ),
                    ),
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
                    color: Colors.grey.withValues(alpha: 0.5),
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
                        title: Text(
                            'Suhu: ${log['suhu'] ?? 0}°C, Kelembaban: ${log['kelembaban'] ?? 0}%'),
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
        onPressed: () => _showOptionsDialog(context),
        backgroundColor: const Color(0xFF99BC85),
        child: const Icon(Icons.more_vert, color: Colors.white),
      ),
    );
  }

  void _showOptionsDialog(BuildContext context) {
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
