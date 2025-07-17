// lib/pages/monitoring_page.dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:excel/excel.dart' hide Border;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hydrohealth/utils/colors.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';

// Model Data Sensor
class SensorData {
  final DateTime timestamp;
  final Map<String, dynamic> values;

  SensorData({required this.timestamp, required this.values});
}

// Konfigurasi Sensor
class SensorConfig {
  final String key;
  final String label;
  final Color color;

  SensorConfig({required this.key, required this.label, required this.color});
}

final List<SensorConfig> sensorConfigs = [
  SensorConfig(key: 'tds1_ppm', label: 'TDS 1 (PPM)', color: Colors.red),
  SensorConfig(key: 'tds2_ppm', label: 'TDS 2 (PPM)', color: Colors.orange),
  SensorConfig(
      key: 'turbidity_ntu',
      label: 'Kekeruhan (NTU)',
      color: Colors.lightGreenAccent),
  SensorConfig(key: 'level1_percent', label: 'Level 1 (%)', color: Colors.cyan),
  SensorConfig(key: 'level2_percent', label: 'Level 2 (%)', color: Colors.blue),
  SensorConfig(
      key: 'flow_rate_lpm', label: 'Aliran (L/min)', color: Colors.purple),
];

class MonitoringPage extends StatefulWidget {
  const MonitoringPage({super.key});

  @override
  _MonitoringPageState createState() => _MonitoringPageState();
}

class _MonitoringPageState extends State<MonitoringPage> {
  final GlobalKey _chartKey = GlobalKey();
  List<SensorData> _rawData = [];
  List<SensorData> _displayData = [];
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final DatabaseReference ref = FirebaseDatabase.instanceFor(
              app: Firebase.app(),
              databaseURL:
                  'https://hydrohealth-project-9cf6c-default-rtdb.asia-southeast1.firebasedatabase.app/')
          .ref('Hydroponic_Data');

      final snapshot = await ref.get();
      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final List<SensorData> processedData = [];

        data.forEach((dateKey, entries) {
          if (entries is Map<dynamic, dynamic>) {
            entries.forEach((entryKey, entryValue) {
              if (entryValue is Map<dynamic, dynamic> &&
                  entryValue.containsKey('timestamp_iso')) {
                processedData.add(SensorData(
                  timestamp: DateTime.parse(entryValue['timestamp_iso']),
                  values: Map<String, dynamic>.from(entryValue),
                ));
              }
            });
          }
        });

        processedData.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        if (mounted) {
          setState(() {
            _rawData = processedData;
            _filterAndDownsampleData();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal mengambil data: $e")),
        );
      }
    }
  }

  void _filterAndDownsampleData() {
    if (_rawData.isEmpty) {
      if (mounted) setState(() => _displayData = []);
      return;
    }

    final start = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final end =
        DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);

    final filtered = _rawData.where((item) {
      return !item.timestamp.isBefore(start) && !item.timestamp.isAfter(end);
    }).toList();

    final downsampled =
        _downsampleWithAverage(filtered, const Duration(minutes: 5));

    if (mounted) {
      setState(() {
        _displayData = downsampled;
      });
    }
  }

  List<SensorData> _downsampleWithAverage(
      List<SensorData> data, Duration interval) {
    if (data.isEmpty) return [];

    final Map<int, List<SensorData>> buckets = {};
    final intervalMillis = interval.inMilliseconds;

    for (var entry in data) {
      final bucketKey =
          (entry.timestamp.millisecondsSinceEpoch / intervalMillis).floor();
      buckets.putIfAbsent(bucketKey, () => []).add(entry);
    }

    final List<SensorData> averagedData = [];
    buckets.forEach((key, bucketEntries) {
      if (bucketEntries.isEmpty) return;

      final avgValues = <String, double>{};
      for (var sensor in sensorConfigs) {
        double sum = 0;
        int count = 0;
        for (var entry in bucketEntries) {
          final value = entry.values[sensor.key];
          if (value != null && value is num) {
            sum += value;
            count++;
          }
        }
        avgValues[sensor.key] = count > 0 ? sum / count : 0.0;
      }

      final timestamp =
          DateTime.fromMillisecondsSinceEpoch(key * intervalMillis);
      averagedData.add(SensorData(timestamp: timestamp, values: avgValues));
    });

    averagedData.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return averagedData;
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
        _filterAndDownsampleData(); // Otomatis filter setelah tanggal dipilih
      });
    }
  }

  Future<void> _exportToExcel() async {
    if (_displayData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tidak ada data untuk diekspor.")));
      return;
    }

    final excel = Excel.createExcel();
    final Sheet sheet = excel['Data Monitoring (Rata-rata 5 Menit)'];

    final List<TextCellValue> headers = [
      'Waktu',
      ...sensorConfigs.map((s) => s.label)
    ].map((header) => TextCellValue(header)).toList();
    sheet.appendRow(headers);

    for (var data in _displayData) {
      final List<CellValue> row = [
        TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(data.timestamp)),
        ...sensorConfigs.map((s) {
          final value = data.values[s.key];
          if (value is num) {
            return DoubleCellValue(value.toDouble());
          }
          return TextCellValue(value?.toString() ?? 'N/A');
        })
      ];
      sheet.appendRow(row);
    }

    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }

    final directory = await getExternalStorageDirectory();
    final path = '${directory!.path}/DataMonitoring_RataRata.xlsx';
    final fileBytes = excel.save();

    if (fileBytes != null) {
      File(path)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Berhasil diekspor ke $path')));
      OpenFile.open(path);
    }
  }

  Future<Uint8List> _captureChart() async {
    RenderRepaintBoundary boundary =
        _chartKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _exportToPdf() async {
    if (_displayData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tidak ada data untuk diekspor.")));
      return;
    }

    final chartImageBytes = await _captureChart();
    final chartImage = pw.MemoryImage(chartImageBytes);

    final pdf = pw.Document();

    final headers = [
      'Waktu (Rata-rata 5 Menit)',
      ...sensorConfigs.map((s) => s.label)
    ];
    final data = _displayData
        .map((item) => [
              DateFormat('yyyy-MM-dd HH:mm').format(item.timestamp),
              ...sensorConfigs.map((s) =>
                  (item.values[s.key] as double?)?.toStringAsFixed(2) ?? 'N/A')
            ])
        .toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) => [
          pw.Header(
              level: 0,
              child: pw.Text("Laporan Data Monitoring Gabungan",
                  textScaleFactor: 2)),
          pw.Container(
            height: 350,
            width: double.infinity,
            child: pw.Image(chartImage),
          ),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headers: headers,
            data: data,
            border: pw.TableBorder.all(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.center,
            cellStyle: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Dashboard Monitoring',
            style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                        child: _buildDatePicker("Dari", _startDate,
                            () => _selectDate(context, true))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _buildDatePicker("s.d.", _endDate,
                            () => _selectDate(context, false))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Chart Section
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _displayData.isEmpty
                      ? const Center(
                          child: Text(
                              "Tidak ada data pada rentang tanggal yang dipilih."))
                      : RepaintBoundary(
                          key: _chartKey,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
                            color: Colors.white,
                            child: LineChart(_buildChartData()),
                          ),
                        ),
            ),
            // Export Buttons
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: _exportToExcel, // Tombol export ke Excel
                    icon: const Icon(Icons.grid_on),
                    label: const Text('Export Excel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _exportToPdf, // Tombol export ke PDF
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Export PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker(String label, DateTime date, VoidCallback onPressed) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        InkWell(
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(DateFormat('dd-MM-yyyy').format(date)),
                const Icon(Icons.calendar_today, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(fontSize: 10);
    final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
    String text;
    if (_endDate.difference(_startDate).inDays > 1) {
      text = DateFormat('d MMM').format(date);
    } else {
      text = DateFormat('HH:mm').format(date);
    }
    return Text(text, style: style);
  }

  LineChartData _buildChartData() {
    return LineChartData(
      lineBarsData: sensorConfigs.map((sensor) {
        return LineChartBarData(
          spots: _displayData.map((data) {
            final double x = data.timestamp.millisecondsSinceEpoch.toDouble();
            final double y = (data.values[sensor.key] ?? 0.0);
            return FlSpot(x, y);
          }).toList(),
          isCurved: true,
          color: sensor.color,
          barWidth: 2.5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        );
      }).toList(),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 44)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 32,
            getTitlesWidget: bottomTitleWidgets,
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: const FlGridData(show: true),
      borderData: FlBorderData(
          show: true,
          border: Border.all(color: const Color(0xff37434d), width: 1)),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final sensorLabel = sensorConfigs[spot.barIndex].label;
              return LineTooltipItem(
                '$sensorLabel: ${spot.y.toStringAsFixed(2)}',
                TextStyle(
                    color: sensorConfigs[spot.barIndex].color,
                    fontWeight: FontWeight.bold),
              );
            }).toList();
          },
        ),
      ),
    );
  }
}
