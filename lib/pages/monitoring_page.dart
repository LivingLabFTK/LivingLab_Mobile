import 'dart:async';
import 'dart:io';

import 'package:excel/excel.dart' hide Border;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hydrohealth/utils/colors.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

// =======================================================================
// DATA MODELS & CONFIGS
// =======================================================================
class SensorData {
  final DateTime timestamp;
  final Map<String, dynamic> values;

  SensorData({required this.timestamp, required this.values});
}

class SensorConfig {
  final String key;
  final String label;
  final Color color;

  SensorConfig({required this.key, required this.label, required this.color});
}

final List<SensorConfig> sensorConfigs = [
  SensorConfig(key: 'tds1_ppm', label: 'TDS 1', color: Colors.red),
  SensorConfig(key: 'tds2_ppm', label: 'TDS 2', color: Colors.orange),
  SensorConfig(key: 'turbidity_ntu', label: 'Kekeruhan', color: Colors.green),
  SensorConfig(
      key: 'level1_percent', label: 'Water Level 1', color: Colors.cyan),
  SensorConfig(
      key: 'level2_percent', label: 'Water Level 2', color: Colors.blue),
  SensorConfig(key: 'flow_rate_lpm', label: 'Aliran', color: Colors.teal),
];

// =======================================================================
// FIREBASE SERVICE
// =======================================================================
class FirebaseService {
  final DatabaseReference _dbRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://hydrohealth-project-9cf6c-default-rtdb.asia-southeast1.firebasedatabase.app/',
  ).ref('Hydroponic_Data');

  Future<List<SensorData>> fetchSensorDataForDateRange(
      DateTime startDate, DateTime endDate) async {
    final List<SensorData> fetchedData = [];
    final List<DateTime> datesToFetch = [];
    for (int i = 0; i <= endDate.difference(startDate).inDays; i++) {
      datesToFetch.add(startDate.add(Duration(days: i)));
    }
    final futures = datesToFetch.map((date) {
      final dateString = DateFormat('yyyy-MM-dd').format(date);
      return _dbRef.child(dateString).get();
    }).toList();
    final snapshots = await Future.wait(futures);
    for (final snapshot in snapshots) {
      if (snapshot.exists && snapshot.value != null) {
        final entries = snapshot.value as Map<dynamic, dynamic>;
        entries.forEach((entryKey, entryValue) {
          if (entryValue is Map<dynamic, dynamic> &&
              entryValue.containsKey('timestamp_iso')) {
            fetchedData.add(SensorData(
              timestamp: DateTime.parse(entryValue['timestamp_iso']),
              values: Map<String, dynamic>.from(entryValue),
            ));
          }
        });
      }
    }
    return fetchedData;
  }
}

// =======================================================================
// VIEWMODEL
// =======================================================================
class MonitoringViewModel with ChangeNotifier {
  final FirebaseService _firebaseService;
  bool _isDisposed = false;
  List<SensorData> _displayData = [];

  List<SensorData> get displayData => _displayData;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));

  DateTime get startDate => _startDate;
  DateTime _endDate = DateTime.now();

  DateTime get endDate => _endDate;
  bool _isFetching = true;

  bool get isFetching => _isFetching;
  bool _isFiltering = false;

  bool get isFiltering => _isFiltering;
  late Map<String, bool> _visibleSensors;

  Map<String, bool> get visibleSensors => _visibleSensors;
  late Duration _selectedInterval;

  Duration get selectedInterval => _selectedInterval;
  final Map<String, Duration> intervalOptions = {
    '5 Menit': const Duration(minutes: 5),
    '1 Jam': const Duration(hours: 1),
    '1 Hari': const Duration(days: 1),
  };

  MonitoringViewModel({required FirebaseService firebaseService})
      : _firebaseService = firebaseService {
    _selectedInterval = intervalOptions.values.first;
    _visibleSensors = {for (var sensor in sensorConfigs) sensor.key: true};
    fetchAndProcessData();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<void> fetchAndProcessData() async {
    print("Starting fetchAndProcessData - isFetching: $_isFetching");
    if (!_isFetching) {
      _isFiltering = true;
      _safeNotifyListeners();
    }
    try {
      final fetchedData = await _firebaseService.fetchSensorDataForDateRange(
          _startDate, _endDate);
      final downsamplingParams =
          DownsamplingParams(fetchedData, _selectedInterval);
      _displayData = await compute(_processDownsampling, downsamplingParams);
    } catch (e) {
      print("Error processing data: $e");
    } finally {
      _isFetching = false;
      _isFiltering = false;
      print(
          "Fetch completed - isFetching: $_isFetching, displayData length: ${_displayData.length}");
      _safeNotifyListeners();
    }
  }

  void updateDate(DateTime newDate, {required bool isStartDate}) {
    if (isStartDate) {
      _startDate = newDate;
    } else {
      _endDate = newDate;
    }
    _safeNotifyListeners();
    fetchAndProcessData();
  }

  void updateInterval(Duration newInterval) {
    _selectedInterval = newInterval;
    _safeNotifyListeners();
    fetchAndProcessData();
  }

  void toggleSensorVisibility(String key) {
    _visibleSensors[key] = !(_visibleSensors[key] ?? false);
    _safeNotifyListeners();
  }
}

// =======================================================================
// TOP-LEVEL FUNCTIONS
// =======================================================================
Future<Uint8List?> _generateExcelBytes(List<SensorData> data) async {
  final excel = Excel.createExcel();
  final Sheet sheet = excel['Data Monitoring'];
  final List<String> sensorLabels = sensorConfigs.map((s) => s.label).toList();
  final List<TextCellValue> headers = [
    TextCellValue('Waktu'),
    ...sensorLabels.map(TextCellValue.new)
  ];
  sheet.appendRow(headers);
  for (var entry in data) {
    final List<CellValue> row = [
      TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(entry.timestamp)),
      ...sensorConfigs.map((s) {
        final value = entry.values[s.key];
        return (value is num)
            ? DoubleCellValue(value.toDouble())
            : TextCellValue(value?.toString() ?? 'N/A');
      })
    ];
    sheet.appendRow(row);
  }
  final fileBytes = excel.save();
  return (fileBytes != null) ? Uint8List.fromList(fileBytes) : null;
}

class DownsamplingParams {
  final List<SensorData> fetchedData;
  final Duration interval;

  DownsamplingParams(this.fetchedData, this.interval);
}

List<SensorData> _processDownsampling(DownsamplingParams params) {
  if (params.fetchedData.isEmpty) return [];
  final dataToProcess = params.fetchedData;
  final Map<int, List<SensorData>> buckets = {};
  final intervalMillis = params.interval.inMilliseconds;
  for (var entry in dataToProcess) {
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
    final timestamp = DateTime.fromMillisecondsSinceEpoch(key * intervalMillis);
    averagedData.add(SensorData(timestamp: timestamp, values: avgValues));
  });
  averagedData.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return averagedData;
}

// =======================================================================
// UI
// =======================================================================

class MonitoringPage extends StatelessWidget {
  const MonitoringPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          MonitoringViewModel(firebaseService: FirebaseService()),
      child: Consumer<MonitoringViewModel>(
        builder: (context, model, child) {
          final mainSensors =
              sensorConfigs.where((s) => !s.key.contains('level')).toList();
          final levelSensors =
              sensorConfigs.where((s) => s.key.contains('level')).toList();

          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text('Dashboard Monitoring',
                  style: TextStyle(color: Colors.white)),
              backgroundColor: AppColors.primary,
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FilterCard(),
                  const SizedBox(height: 20),
                  _ExportButton(),
                  const SizedBox(height: 20),
                  if (model.isFetching)
                    SizedBox(
                      height: 400,
                      child: Center(
                          child: Lottie.asset('assets/Walking Pothos.json',
                              width: 200)),
                    )
                  else if (model.displayData.isEmpty)
                    const _EmptyState()
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Grafik Sensor Utama",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 300,
                          child: Stack(children: [
                            _LineChart(sensorsToShow: mainSensors),
                            if (model.isFiltering)
                              const Center(child: CircularProgressIndicator()),
                          ]),
                        ),
                        const SizedBox(height: 20),
                        const Text("Grafik Level Air (%)",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 300,
                          child: Stack(children: [
                            _LineChart(sensorsToShow: levelSensors),
                            if (model.isFiltering)
                              const Center(child: CircularProgressIndicator()),
                          ]),
                        ),
                        const SizedBox(height: 10),
                        if (!model.isFetching) _InteractiveLegend(),
                        const SizedBox(height: 70),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 400,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.data_exploration_outlined,
                size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              "Tidak Ada Data",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Coba pilih rentang tanggal yang berbeda.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            const Row(
              children: [
                Expanded(child: _DatePickerButton(isStartDate: true)),
                SizedBox(width: 10),
                Expanded(child: _DatePickerButton(isStartDate: false)),
              ],
            ),
            const SizedBox(height: 10),
            _IntervalSelector(),
          ],
        ),
      ),
    );
  }
}

class _DatePickerButton extends StatelessWidget {
  final bool isStartDate;

  const _DatePickerButton({super.key, required this.isStartDate});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<MonitoringViewModel>();
    final date = isStartDate ? model.startDate : model.endDate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(isStartDate ? "Dari" : "s.d.",
            style: const TextStyle(fontSize: 12)),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) {
              context
                  .read<MonitoringViewModel>()
                  .updateDate(picked, isStartDate: isStartDate);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(5)),
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
}

class _IntervalSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final model = context.watch<MonitoringViewModel>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          const Text("Interval Data:", style: TextStyle(fontSize: 12)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(5)),
            child: DropdownButton<Duration>(
              value: model.selectedInterval,
              underline: const SizedBox(),
              items: model.intervalOptions.entries.map((entry) {
                return DropdownMenuItem<Duration>(
                    value: entry.value, child: Text(entry.key));
              }).toList(),
              onChanged: (Duration? newValue) {
                if (newValue != null) {
                  context.read<MonitoringViewModel>().updateInterval(newValue);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LineChart extends StatelessWidget {
  final List<SensorConfig> sensorsToShow;

  const _LineChart({required this.sensorsToShow});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<MonitoringViewModel>();

    final List<LineChartBarData> chartBars = sensorsToShow
        .where((sensor) => model.visibleSensors[sensor.key] ?? false)
        .map((sensor) {
      return LineChartBarData(
        spots: model.displayData.map((data) {
          final x = data.timestamp.millisecondsSinceEpoch.toDouble();
          final y = (data.values[sensor.key] ?? 0.0);
          return FlSpot(x, y);
        }).toList(),
        isCurved: true,
        color: sensor.color,
        barWidth: 2.5,
        dotData: const FlDotData(show: false),
      );
    }).toList();
    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots
                  .map((spot) {
                    final visibleBarsInThisChart = sensorsToShow
                        .where((s) => model.visibleSensors[s.key]!)
                        .toList();
                    if (spot.barIndex < visibleBarsInThisChart.length) {
                      final sensor = visibleBarsInThisChart[spot.barIndex];
                      return LineTooltipItem(
                        '${sensor.label}\n${spot.y.toStringAsFixed(2)}',
                        TextStyle(
                            color: sensor.color, fontWeight: FontWeight.bold),
                      );
                    }
                    return null;
                  })
                  .whereType<LineTooltipItem>()
                  .toList();
            },
          ),
        ),
        clipData: const FlClipData.all(),
        lineBarsData: chartBars,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  getTitlesWidget: (value, meta) => Text(meta.formattedValue,
                      style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black,
                          fontWeight: FontWeight.bold)))),
          bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (value, meta) {
                    final date =
                        DateTime.fromMillisecondsSinceEpoch(value.toInt());
                    String text;
                    if (model.endDate.difference(model.startDate).inDays > 2) {
                      text = DateFormat('d MMM').format(date);
                    } else {
                      text = DateFormat('HH:mm').format(date);
                    }
                    return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          text,
                          style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black,
                              fontWeight: FontWeight.bold),
                        ));
                  })),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(
            show: true,
            border: Border.all(color: const Color(0xff37434d), width: 1)),
      ),
    );
  }
}

class _InteractiveLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Wrap(
        spacing: 16.0,
        runSpacing: 8.0,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: sensorConfigs.map((sensor) {
          final isVisible =
              context.watch<MonitoringViewModel>().visibleSensors[sensor.key] ??
                  false;
          return InkWell(
            onTap: () => context
                .read<MonitoringViewModel>()
                .toggleSensorVisibility(sensor.key),
            borderRadius: BorderRadius.circular(4.0),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 12,
                      height: 12,
                      color: isVisible
                          ? sensor.color
                          : Colors.grey.withValues(alpha: 0.5)),
                  const SizedBox(width: 8),
                  Text(
                    sensor.label,
                    style: TextStyle(
                      fontSize: 14,
                      color: isVisible ? Colors.black : Colors.grey,
                      decoration: isVisible
                          ? TextDecoration.none
                          : TextDecoration.lineThrough,
                    ),
                  )
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ExportButton extends StatefulWidget {
  const _ExportButton();

  @override
  __ExportButtonState createState() => __ExportButtonState();
}

class __ExportButtonState extends State<_ExportButton> {
  bool _isExporting = false;

  Future<void> _exportToExcel(
      BuildContext context, List<SensorData> data) async {
    if (_isExporting) return;
    if (data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tidak ada data untuk diekspor.")));
      return;
    }
    setState(() => _isExporting = true);
    try {
      final fileBytes = await compute(_generateExcelBytes, data);
      if (fileBytes == null) throw Exception("Gagal membuat file Excel.");
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/DataMonitoring.xlsx';
      await File(path).writeAsBytes(fileBytes);
      final result = await OpenFile.open(path);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Tidak dapat membuka file: ${result.message}")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Gagal mengekspor: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<MonitoringViewModel>();
    return Container(
      alignment: Alignment.centerRight,
      child: ElevatedButton.icon(
        onPressed: (_isExporting || model.isFiltering)
            ? null
            : () => _exportToExcel(context, model.displayData),
        icon: _isExporting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.0,
                ))
            : const Icon(Icons.grid_on),
        label: const Text('Export Excel'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey,
        ),
      ),
    );
  }
}
