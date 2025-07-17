import 'package:buttons_tabbar/buttons_tabbar.dart';
import 'package:flutter/material.dart';
import 'package:hydrohealth/content/nutrisi.dart';
import 'package:hydrohealth/content/ph.dart';
import 'package:hydrohealth/content/suhu_kelembaban.dart';

import '../utils/colors.dart';

class MonitoringPage extends StatefulWidget {
  const MonitoringPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _MonitoringPageState createState() => _MonitoringPageState();
}

class _MonitoringPageState extends State<MonitoringPage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            bottom: ButtonsTabBar(
              backgroundColor: AppColors.primary,
              unselectedBackgroundColor: Colors.white,
              unselectedLabelStyle: const TextStyle(color: AppColors.text),
              labelStyle: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(icon: Icon(Icons.thermostat), text: "Suhu & Kelembaban"),
                Tab(icon: Icon(Icons.opacity), text: "pH"),
                Tab(icon: Icon(Icons.science), text: "Nutrisi"),
              ],
            )),
        body: const TabBarView(
          children: <Widget>[
            SuhuKelembaban(),
            PhLog(),
            NutrisiLog(),
          ],
        ),
      ),
    );
  }
}
