import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart' hide Query;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../utils/colors.dart';
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
  StreamSubscription? _dataSubscription;

  // State untuk Paginasi
  int _currentPage = 1;
  final int _itemsPerPage = 5;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _listenAndLogData();
    _fetchLogs();
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }

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
          _logger.info('Data suhu & kelembaban berhasil dicatat ke Firestore.');
          if (_currentPage == 1) {
            _fetchLogs();
          }
        }).catchError((error) {
          _logger.warning('Gagal mencatat data ke Firestore: $error');
        });
      }
    });
  }

  void _fetchLogs() async {
    if (_isLoading) return;
    setState(() { _isLoading = true; });

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
      _logger.info('Berhasil mengambil total ${_logs.length} data log.');
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
        IntCellValue(log['suhu'] ?? 0),
        IntCellValue(log['kelembaban'] ?? 0)
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
    if (_logs.isEmpty) return [];
    return _logs
        .asMap()
        .entries
        .map((entry) => FlSpot(
        (_logs.length - 1 - entry.key).toDouble(),
        (entry.value['suhu'] ?? 0).toDouble()))
        .toList();
  }

  List<FlSpot> _createKelembabanChartData() {
    if (_logs.isEmpty) return [];
    return _logs
        .asMap()
        .entries
        .map((entry) => FlSpot(
        (_logs.length - 1 - entry.key).toDouble(),
        (entry.value['kelembaban'] ?? 0).toDouble()))
        .toList();
  }

  String _formatTimeLabel(double value) {
    int index = _logs.length - 1 - value.toInt();
    if (index < 0 || index >= _logs.length || _logs[index]['timestamp'] == null) return '';
    final timestamp = _logs[index]['timestamp'] as Timestamp;
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
              leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
              title: const Text('Delete All Logs'),
              onTap: () { Navigator.pop(context); _deleteAllLogs(); },
            ),
            ListTile(
              leading: const Icon(Icons.download, color: AppColors.primary),
              title: const Text('Download Logs as Excel'),
              onTap: () { Navigator.pop(context); _requestPermission(); },
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
                color: AppColors.primary.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), spreadRadius: 4, blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  const Text('Kondisi Saat ini:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 10),
                  StreamBuilder(
                    stream: monitoringRef.limitToLast(1).onValue,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const CircularProgressIndicator(color: Colors.white);
                      if (!snapshot.hasData || snapshot.data?.snapshot.value == null) return const Text('Menunggu data...', style: TextStyle(color: Colors.white));
                      if (snapshot.hasError) return Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white));

                      final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                      final latestEntry = data.values.last as Map<dynamic, dynamic>;
                      final suhu = latestEntry['Suhu'] ?? 'N/A';
                      final kelembaban = latestEntry['Kelembaban'] ?? 'N/A';

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Row(children: [const Icon(Icons.thermostat, color: Colors.redAccent, size: 30), const SizedBox(width: 10), Text('Suhu: $suhu°C', style: const TextStyle(color: Colors.white, fontSize: 18))]),
                          Row(children: [const Icon(Icons.water_drop, color: AppColors.secondary, size: 30), const SizedBox(width: 10), Text('Kelembaban: $kelembaban%', style: const TextStyle(color: Colors.white, fontSize: 18))]),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Temperature (Suhu)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 200,
                    child: _logs.isEmpty
                        ? const Center(child: Text("Menunggu data..."))
                        : LineChart(LineChartData(gridData: const FlGridData(show: true), titlesData: FlTitlesData(topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 35, getTitlesWidget: (value, meta) => Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(_formatTimeLabel(value), style: const TextStyle(color: Color(0xFF68737D), fontWeight: FontWeight.bold, fontSize: 12))))), leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (value, meta) => Padding(padding: const EdgeInsets.only(right: 8.0), child: Text('${value.toInt()}°C', style: const TextStyle(color: Color(0xFF68737D), fontWeight: FontWeight.bold, fontSize: 12)))))), borderData: FlBorderData(show: true), lineBarsData: [LineChartBarData(spots: _createSuhuChartData(), isCurved: true, color: Colors.red, barWidth: 3, belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [Colors.red.withOpacity(0.3), Colors.red.withOpacity(0.0)], begin: Alignment.topCenter, end: Alignment.bottomCenter)), dotData: const FlDotData(show: true))])),
                  ),
                  const SizedBox(height: 20),
                  const Text('Humidity (Kelembaban)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 200,
                    child: _logs.isEmpty
                        ? const Center(child: Text("Menunggu data..."))
                        : LineChart(LineChartData(gridData: const FlGridData(show: true), titlesData: FlTitlesData(topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 35, getTitlesWidget: (value, meta) => Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(_formatTimeLabel(value), style: const TextStyle(color: Color(0xFF68737D), fontWeight: FontWeight.bold, fontSize: 12))))), leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (value, meta) => Padding(padding: const EdgeInsets.only(right: 8.0), child: Text('${value.toInt()}%', style: const TextStyle(color: Color(0xFF68737D), fontWeight: FontWeight.bold, fontSize: 12)))))), borderData: FlBorderData(show: true), lineBarsData: [LineChartBarData(spots: _createKelembabanChartData(), isCurved: true, color: Colors.blue, barWidth: 3, belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [Colors.blue.withOpacity(0.3), Colors.blue.withOpacity(0.0)], begin: Alignment.topCenter, end: Alignment.bottomCenter)), dotData: const FlDotData(show: true))])),
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
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), spreadRadius: 2, blurRadius: 8, offset: const Offset(0, 4))],
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
                      final formattedDate = timestamp != null ? '${timestamp.toDate().day}-${timestamp.toDate().month}-${timestamp.toDate().year} ${timestamp.toDate().hour}:${timestamp.toDate().minute}' : 'No timestamp';
                      return ListTile(
                        title: Text('Suhu: ${log['suhu'] ?? 0}°C, Kelembaban: ${log['kelembaban'] ?? 0}%'),
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
        onPressed: () => _showOptionsDialog(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.more_vert, color: Colors.white),
      ),
    );
  }
}