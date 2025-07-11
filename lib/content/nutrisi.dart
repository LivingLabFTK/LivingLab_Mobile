import 'dart:async';
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
import 'package:logging/logging.dart';

import '../utils/colors.dart';

final Logger _logger = Logger('Nutrisi');

void setupLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    _logger.info('${record.level.name}: ${record.time}: ${record.message}');
  });
}

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
  StreamSubscription? _dataSubscription;

  // State untuk Paginasi
  int _currentPage = 1;
  final int _itemsPerPage = 5;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    NotificationHelper.initialize();
    _listenAndLogData();
    _fetchLogs();
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }

  void _listenAndLogData() {
    _dataSubscription = ref.limitToLast(1).onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      final latestData = data?.values.last as Map?;
      final nutrisi = latestData?['Nutrisi'];

      if (nutrisi != null) {
        final nutrisiValue = (nutrisi as num).toDouble();
        if (mounted) {
          setState(() {
            _currentNutrisiValue = nutrisiValue;
          });
        }

        _firestoreRef.add({
          'value': nutrisiValue,
          'timestamp': FieldValue.serverTimestamp(),
        }).then((_) {
          _logger.info('Data nutrisi berhasil dicatat ke Firestore.');
          if (_currentPage == 1 && mounted) {
            _fetchLogs();
          }
        });

        if (nutrisiValue < 800) {
          NotificationHelper.showNotification(
            'Peringatan Nutrisi',
            'Nutrisi di bawah 800ppm, saatnya tambahkan nutrisi',
            'nutrisi_low',
          );
        }
      }
    });
  }

  void _fetchLogs() async {
    if (_isLoading) return;
    if (mounted) setState(() { _isLoading = true; });

    try {
      final querySnapshot =
      await _firestoreRef.orderBy('timestamp', descending: true).get();
      if (!mounted) return;
      setState(() {
        _logs = querySnapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoading = false; });
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Storage permission is required to save logs.')),
      );
    }
  }

  Future<void> _exportLogsToExcel() async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['LogHistory'];
    sheetObject.appendRow(
        [TextCellValue('Timestamp'),  TextCellValue('Nutrisi Value')]);

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
        if (directory == null) return;
        final path = '${directory.path}/NutrisiLog.xlsx';
        File(path)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);

        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Logs exported to $path')));

        await OpenFile.open(path);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error writing file: $e')));
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error generating Excel file.')),
      );
    }
  }

  void _showOptionsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
              title: const Text('Delete All Logs'),
              onTap: () {
                Navigator.pop(context);
                _deleteAllLogs();
              },
            ),
            ListTile(
              leading: const Icon(Icons.download, color: AppColors.primary),
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

  @override
  Widget build(BuildContext context) {
    final int totalLogs = _logs.length;
    final int totalPages = (totalLogs / _itemsPerPage).ceil();
    final int startIndex = (_currentPage - 1) * _itemsPerPage;
    final int endIndex = startIndex + _itemsPerPage > totalLogs ? totalLogs : startIndex + _itemsPerPage;
    final List<Map<String, dynamic>> paginatedLogs = (totalLogs > 0) ? _logs.sublist(startIndex, endIndex) : [];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha:0.8),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha:0.3),
                    spreadRadius: 4,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text('Kondisi Saat ini:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 10),
                  const Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12.0,
                    runSpacing: 8.0,
                    children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.circle, color: Colors.red, size: 10), SizedBox(width: 4), Text('Kurang', style: TextStyle(color: Colors.white))]),
                      Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.circle, color: Colors.yellow, size: 10), SizedBox(width: 4), Text('Cukup', style: TextStyle(color: Colors.white))]),
                      Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.circle, color: Colors.green, size: 10), SizedBox(width: 4), Text('Optimal', style: TextStyle(color: Colors.white))]),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SpeedometerChart(
                    dimension: 200,
                    minValue: 0,
                    maxValue: 1800,
                    value: _currentNutrisiValue,
                    graphColor: const [Colors.red, Colors.yellow, Colors.green],
                    pointerColor: AppColors.text,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.science, color: Colors.white, size: 30),
                      const SizedBox(width: 10),
                      Text('Nutrisi: $_currentNutrisiValue ppm', style: const TextStyle(color: Colors.white, fontSize: 20)),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha:0.2), spreadRadius: 2, blurRadius: 8, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  const Text('Log History', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text)),
                  _isLoading
                      ? const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())
                      : paginatedLogs.isEmpty
                      ? const Padding(padding: EdgeInsets.all(20), child: Text("Belum ada riwayat data."))
                      : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: paginatedLogs.length,
                    itemBuilder: (context, index) {
                      final log = paginatedLogs[index];
                      final timestamp = log['timestamp'] as Timestamp?;
                      final formattedDate = timestamp != null
                          ? '${timestamp.toDate().day}-${timestamp.toDate().month}-${timestamp.toDate().year} ${timestamp.toDate().hour}:${timestamp.toDate().minute}'
                          : 'No timestamp';
                      return ListTile(
                        title: Text('Nutrisi Value: ${log['value']} ppm', style: const TextStyle(color: AppColors.text)),
                        subtitle: Text('Timestamp: $formattedDate'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_sharp, color: Colors.redAccent),
                          onPressed: () => _deleteLog(log['id']),
                        ),
                      );
                    },
                  ),
                  if (totalLogs > _itemsPerPage)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios),
                            onPressed: _currentPage > 1 ? () { setState(() { _currentPage--; }); } : null,
                            color: AppColors.primary,
                          ),
                          Text('Page $_currentPage of $totalPages', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.text)),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_ios),
                            onPressed: _currentPage < totalPages ? () { setState(() { _currentPage++; }); } : null,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showOptionsDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.more_vert, color: Colors.white),
      ),
    );
  }
}