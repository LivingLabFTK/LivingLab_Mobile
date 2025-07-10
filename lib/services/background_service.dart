import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:workmanager/workmanager.dart';

final Logger _logger = Logger('BackgroundService');

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    _logger.info("Background fetch started");

    // Inisialisasi Firebase
    await Firebase.initializeApp();

    _logger.info("Firebase initialized");

    final DatabaseReference monitoringRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL:
          'https://hydrohealth-project-9cf6c-default-rtdb.asia-southeast1.firebasedatabase.app',
    ).ref('Monitoring');

    final CollectionReference suhuKelembabanFirestoreRef =
        FirebaseFirestore.instance.collection('SuhuKelembabanLog');
    final CollectionReference phFirestoreRef =
        FirebaseFirestore.instance.collection('PhLog');
    final CollectionReference nutrisiFirestoreRef =
        FirebaseFirestore.instance.collection('NutrisiLog');

    try {
      _logger.info("Fetching data from Firebase Realtime Database");

      // Get the latest folder key
      final snapshot = await monitoringRef.orderByKey().limitToLast(1).get();
      final latestKey = (snapshot.value as Map).keys.first;
      final latestDataSnapshot = await monitoringRef.child(latestKey).get();
      final latestData = latestDataSnapshot.value as Map<String, dynamic>;

      _logger.info("Data fetched successfully");

      // Fetching the values from the latest data
      final suhu = latestData['Suhu'];
      final kelembaban = latestData['Kelembaban'];
      final ph = latestData['pH'];
      final nutrisi = latestData['Nutrisi'];

      if (suhu != null && kelembaban != null) {
        final suhuKelembabanLog = {
          'suhu': suhu,
          'kelembaban': kelembaban,
          'timestamp': Timestamp.now(),
        };
        await suhuKelembabanFirestoreRef.add(suhuKelembabanLog);
        _logger.info("Suhu dan Kelembaban data saved to Firestore");
      }

      if (ph != null) {
        final phLog = {
          'value': ph,
          'timestamp': Timestamp.now(),
        };
        await phFirestoreRef.add(phLog);
        _logger.info("Ph data saved to Firestore");
      }

      if (nutrisi != null) {
        final nutrisiLog = {
          'value': nutrisi,
          'timestamp': Timestamp.now(),
        };
        await nutrisiFirestoreRef.add(nutrisiLog);
        _logger.info("Nutrisi data saved to Firestore");
      }
    } catch (e) {
      _logger.info('Error fetching data from Realtime Database: $e');
    }

    _logger.info("Background fetch completed");

    return Future.value(true);
  });
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager().initialize(callbackDispatcher);
  Workmanager().registerPeriodicTask(
    "1",
    "simplePeriodicTask",
    frequency: const Duration(
        minutes: 15), // Mengatur frekuensi tugas menjadi 15 menit
  );
}
