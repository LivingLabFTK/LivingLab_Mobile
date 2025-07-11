import 'dart:async';
import 'dart:io';
import 'dart:math'; // Import buat bikin data acak

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart' hide Query;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/colors.dart';

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
  // ================== SAKLAR MODE ==================
  // Ganti jadi 'false' untuk kembali menggunakan data asli Firebase
  final bool _useDummyData = true;

  // ===============================================

  // Variabel untuk Firebase (dinonaktifkan jika pake dummy)
  final DatabaseReference monitoringRef = FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL:
              'https://hydrohealth-project-9cf6c-default-rtdb.asia-southeast1.firebasedatabase.app')
      .ref('Monitoring');
  final CollectionReference _firestoreRef =
      FirebaseFirestore.instance.collection('SuhuKelembabanLog');
  StreamSubscription? _dataSubscription;

  List<Map<String, dynamic>> _logs = [];
  double _currentSuhu = 27.0;
  double _currentKelembaban = 65.0;
  Timer? _dummyDataTimer;

  // State Paginasi
  int _currentPage = 1;
  final int _itemsPerPage = 5;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (_useDummyData) {
      _startDummyData();
    } else {
      _listenAndLogData();
      _fetchLogs();
    }
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _dummyDataTimer?.cancel();
    super.dispose();
  }

  void _startDummyData() {
    _dummyDataTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;

      final random = Random();
      final dummySuhu = 25.0 + random.nextDouble() * 5.0;
      final dummyKelembaban = 60.0 + random.nextDouble() * 10.0;

      final dummyLog = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'suhu': dummySuhu,
        'kelembaban': dummyKelembaban,
        'timestamp': Timestamp.now(),
      };

      setState(() {
        _currentSuhu = dummySuhu;
        _currentKelembaban = dummyKelembaban;
        _logs.insert(0, dummyLog);
      });
    });
  }

  // --- FUNGSI-FUNGSI FIREBASE (Aman, tidak akan jalan jika _useDummyData = true) ---
  void _listenAndLogData() {
    _dataSubscription = monitoringRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return;

      final latestEntry = data.values.last as Map<dynamic, dynamic>?;
      if (latestEntry == null) return;

      final suhu = latestEntry['Suhu'];
      final kelembaban = latestEntry['Kelembaban'];

      if (suhu != null && kelembaban != null) {
        _firestoreRef.add({
          'suhu': (suhu as num).toDouble(),
          'kelembaban': (kelembaban as num).toDouble(),
          'timestamp': FieldValue.serverTimestamp(),
        }).then((_) {
          if (_currentPage == 1) {
            _fetchLogs();
          }
        });
      }
    });
  }

  void _fetchLogs() async {
    if (_isLoading) return;
    if (mounted)
      setState(() {
        _isLoading = true;
      });

    try {
      Query query = _firestoreRef.orderBy('timestamp', descending: true);
      final querySnapshot = await query.get();

      if (!mounted) return;
      setState(() {
        _logs = querySnapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
    }
  }

  void _deleteLog(String id) async {
    // Fungsi ini tidak akan berjalan di mode dummy
    if (_useDummyData) return;
    try {
      await _firestoreRef.doc(id).delete();
      _fetchLogs();
    } catch (e) {
      // handle error
    }
  }

  void _deleteAllLogs() async {
    // Fungsi ini tidak akan berjalan di mode dummy
    if (_useDummyData) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      final querySnapshot = await _firestoreRef.get();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      _fetchLogs();
    } catch (e) {
      // handle error
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
    sheetObject.appendRow([
      TextCellValue('Timestamp'),
      TextCellValue('Suhu (°C)'),
      TextCellValue('Kelembaban (%)')
    ]);

    for (var log in _logs) {
      final timestamp = (log['timestamp'] as Timestamp).toDate();
      final formattedDate =
          '${timestamp.day}-${timestamp.month}-${timestamp.year} ${timestamp.hour}:${timestamp.minute}:${timestamp.second}';
      sheetObject.appendRow([
        TextCellValue(formattedDate),
        DoubleCellValue((log['suhu'] as num).toDouble()),
        DoubleCellValue((log['kelembaban'] as num).toDouble()),
      ]);
    }

    final fileBytes = excel.save();
    if (fileBytes != null) {
      try {
        final directory = await getExternalStorageDirectory();
        if (!mounted) return;
        final path = await _showSaveFileDialog(context, directory!.path);
        if (path != null) {
          if (!mounted) return;
          File(path)
            ..createSync(recursive: true)
            ..writeAsBytesSync(fileBytes);
          if (!mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Logs exported to $path')));

          await OpenFile.open(path);
        }
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
                onPressed: () => Navigator.of(context).pop()),
            TextButton(
              child: const Text('SAVE'),
              onPressed: () {
                String fileName = fileNameController.text;
                if (fileName.isNotEmpty) {
                  Navigator.of(context).pop('$initialDirectory/$fileName.xlsx');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('File name cannot be empty')));
                }
              },
            ),
          ],
        );
      },
    );
  }

  List<FlSpot> _createSuhuChartData() {
    if (_logs.isEmpty) return [const FlSpot(0, 0)];
    var recentLogs = _logs.take(20).toList();
    var reversedLogs = recentLogs.reversed.toList();
    return reversedLogs.asMap().entries.map((entry) {
      return FlSpot(
          entry.key.toDouble(), (entry.value['suhu'] ?? 0).toDouble());
    }).toList();
  }

  List<FlSpot> _createKelembabanChartData() {
    if (_logs.isEmpty) return [const FlSpot(0, 0)];
    var recentLogs = _logs.take(20).toList();
    var reversedLogs = recentLogs.reversed.toList();
    return reversedLogs.asMap().entries.map((entry) {
      return FlSpot(
          entry.key.toDouble(), (entry.value['kelembaban'] ?? 0).toDouble());
    }).toList();
  }

  String _formatTimeLabel(double value) {
    var recentLogs = _logs.take(20).toList().reversed.toList();
    int index = value.toInt();
    if (index < 0 || index >= recentLogs.length) return '';
    final log = recentLogs[index];
    if (log['timestamp'] == null) return '';
    final timestamp = log['timestamp'] as Timestamp;
    final date = timestamp.toDate();
    return '${date.hour}:${date.minute}';
  }

  void _showOptionsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Wrap(
          children: [
            ListTile(
              leading:
                  const Icon(Icons.delete_forever, color: Colors.redAccent),
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
    final int endIndex = startIndex + _itemsPerPage > totalLogs
        ? totalLogs
        : startIndex + _itemsPerPage;
    final List<Map<String, dynamic>> paginatedLogs =
        (totalLogs > 0) ? _logs.sublist(startIndex, endIndex) : [];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      spreadRadius: 4,
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                children: [
                  Text('Kondisi Saat ini ${_useDummyData ? "(Dummy)" : ""}',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.spaceEvenly,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 5.0,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.thermostat,
                              color: Colors.redAccent, size: 25),
                          Text('Suhu: ${_currentSuhu.toStringAsFixed(0)}°C',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 15))
                        ],
                      ),
                      const Row(
                        children: [
                          SizedBox(width: 5),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.water_drop,
                              color: AppColors.secondary, size: 25),
                          Text(
                              'Kelembapan: ${_currentKelembaban.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 15))
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Temperature (Suhu)',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 200,
                    child: _logs.isEmpty
                        ? const Center(child: Text("Menunggu data..."))
                        : LineChart(LineChartData(
                            gridData: const FlGridData(show: true),
                            titlesData: FlTitlesData(
                                topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 35,
                                        getTitlesWidget: (value, meta) => Padding(
                                            padding:
                                                const EdgeInsets.only(top: 8.0),
                                            child: Text(_formatTimeLabel(value),
                                                style: const TextStyle(
                                                    color: Color(0xFF68737D),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12))))),
                                leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 40,
                                        getTitlesWidget: (value, meta) =>
                                            Padding(padding: const EdgeInsets.only(right: 8.0), child: Text('${value.toInt()}°C', style: const TextStyle(color: Color(0xFF68737D), fontWeight: FontWeight.bold, fontSize: 12)))))),
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
                                              Colors.red.withValues(alpha: 0.0)
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter)),
                                    dotData: const FlDotData(show: false))
                              ])),
                  ),
                  const SizedBox(height: 20),
                  const Text('Humidity (Kelembaban)',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 200,
                    child: _logs.isEmpty
                        ? const Center(child: Text("Menunggu data..."))
                        : LineChart(LineChartData(
                            gridData: const FlGridData(show: true),
                            titlesData: FlTitlesData(
                                topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 35,
                                        getTitlesWidget: (value, meta) => Padding(
                                            padding:
                                                const EdgeInsets.only(top: 8.0),
                                            child: Text(_formatTimeLabel(value),
                                                style: const TextStyle(
                                                    color: Color(0xFF68737D),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12))))),
                                leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 40,
                                        getTitlesWidget: (value, meta) =>
                                            Padding(padding: const EdgeInsets.only(right: 8.0), child: Text('${value.toInt()}%', style: const TextStyle(color: Color(0xFF68737D), fontWeight: FontWeight.bold, fontSize: 12)))))),
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
                                              Colors.blue
                                                  .withValues(alpha: 0.3),
                                              Colors.blue.withValues(alpha: 0.0)
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter)),
                                    dotData: const FlDotData(show: false))
                              ])),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.2),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                children: [
                  Text('Log History ${_useDummyData ? "(DUMMY)" : ""}',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text)),
                  _isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator())
                      : paginatedLogs.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: Text("Belum ada riwayat data."))
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: paginatedLogs.length,
                              itemBuilder: (context, index) {
                                final log = paginatedLogs[index];
                                final timestamp =
                                    log['timestamp'] as Timestamp?;
                                final formattedDate = timestamp != null
                                    ? '${timestamp.toDate().day}-${timestamp.toDate().month}-${timestamp.toDate().year} ${timestamp.toDate().hour}:${timestamp.toDate().minute}'
                                    : 'No timestamp';
                                return ListTile(
                                  title: Text(
                                      'Suhu: ${log['suhu']?.toStringAsFixed(2) ?? 'N/A'}°C, Kelembaban: ${log['kelembaban']?.toStringAsFixed(2) ?? 'N/A'}%'),
                                  subtitle: Text('Timestamp: $formattedDate'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_sharp,
                                        color: Colors.redAccent),
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
                            onPressed: _currentPage > 1
                                ? () {
                                    setState(() {
                                      _currentPage--;
                                    });
                                  }
                                : null,
                            color: AppColors.primary,
                          ),
                          Text('Page $_currentPage of $totalPages',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.text)),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_ios),
                            onPressed: _currentPage < totalPages
                                ? () {
                                    setState(() {
                                      _currentPage++;
                                    });
                                  }
                                : null,
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
        onPressed: () => _showOptionsDialog(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.more_vert, color: Colors.white),
      ),
    );
  }
}
