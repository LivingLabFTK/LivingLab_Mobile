// test/monitoring_viewmodel_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hydrohealth/pages/monitoring_page.dart';

// =======================================================================
// SETUP TES
// =======================================================================

// 1. Bikin "Supplier" bohongan.
class MockFirebaseService extends Mock implements FirebaseService {}

void main() {
  // Grup tes untuk ViewModel kita
  group('MonitoringViewModel Tests', () {
    // Siapkan objek-objek yang dibutuhkan untuk setiap tes
    late MonitoringViewModel viewModel;
    late MockFirebaseService mockFirebaseService;

    // Fungsi setUp akan dijalankan sebelum setiap tes individu
    setUp(() {
      // Daftarkan 'any()' dari mocktail agar bisa digunakan
      registerFallbackValue(DateTime(2023));

      mockFirebaseService = MockFirebaseService();
      // DIUBAH: ViewModel dibuat di sini, tapi data belum di-fetch
      viewModel = MonitoringViewModel(firebaseService: mockFirebaseService);
    });

    // =======================================================================
    // CONTOH TES
    // =======================================================================

    test('Harus memfilter dan merata-ratakan data dengan benar', () async {
      // ARRANGE (Persiapan)
      // Siapkan data mentah bohongan
      final fakeRawData = [
        SensorData(
            timestamp: DateTime(2023, 1, 1, 10, 0),
            values: {'tds1_ppm': 100}), // Jam 10:00
        SensorData(
            timestamp: DateTime(2023, 1, 1, 10, 50),
            values: {'tds1_ppm': 150}), // Jam 10:50
        SensorData(
            timestamp: DateTime(2023, 1, 1, 11, 5),
            values: {'tds1_ppm': 200}), // Jam 11:05
      ];

      // --- PERBAIKAN UTAMA ---
      // Atur 'bahan baku bohongan' DULU, SEBELUM koki disuruh masak
      when(() => mockFirebaseService.fetchSensorDataForDateRange(any(), any()))
          .thenAnswer((_) async => fakeRawData);

      // ACT (Aksi)
      // SEKARANG baru kita suruh koki masak dengan data yang sudah disiapkan
      // Kita panggil langsung fungsi utamanya, bukan lewat updateInterval
      await viewModel.fetchAndProcessData();

      // ASSERT (Pengecekan Hasil)

      // Harusnya ada 2 data setelah dirata-ratain per jam (data jam 10 dan data jam 11)
      expect(viewModel.displayData.length, 2);

      // Cek apakah nilai rata-rata untuk data jam 10 sudah benar: (100 + 150) / 2 = 125.0
      expect(viewModel.displayData[0].values['tds1_ppm'], 125.0);

      // Cek apakah nilai rata-rata untuk data jam 11 sudah benar: (200) / 1 = 200.0
      expect(viewModel.displayData[1].values['tds1_ppm'], 200.0);
    });

    test('Harus mengosongkan displayData jika tidak ada data dari Firebase',
        () async {
      // ARRANGE
      // Atur agar mock service mengembalikan list kosong
      when(() => mockFirebaseService.fetchSensorDataForDateRange(any(), any()))
          .thenAnswer((_) async => []);

      // ACT
      await viewModel.fetchAndProcessData();

      // ASSERT
      // Pastikan data yang akan ditampilkan ke chart benar-benar kosong
      expect(viewModel.displayData.isEmpty, true);
    });
  });
}
