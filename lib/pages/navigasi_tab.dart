import 'package:buttons_tabbar/buttons_tabbar.dart';
import 'package:flutter/material.dart';
import 'package:hydrohealth/content/suhu_kelembaban.dart';
import 'package:hydrohealth/content/nutrisi.dart';
import 'package:hydrohealth/content/ph.dart';
import '../utils/colors.dart';

class NavigasiTab extends StatefulWidget {
  const NavigasiTab({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _NavigasiTabState createState() => _NavigasiTabState();
}

class _NavigasiTabState extends State<NavigasiTab> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: SafeArea(
          child: Container(
            color: AppColors.background,
            child: Column(
              children: <Widget>[
                const SizedBox(height: 16),
                ButtonsTabBar(
                  backgroundColor: AppColors.primary,
                  unselectedBackgroundColor: Colors.white,
                  unselectedLabelStyle:
                  const TextStyle(color: AppColors.text),
                  labelStyle: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.thermostat),
                      text: "Suhu",
                    ),
                    Tab(
                      icon: Icon(Icons.opacity),
                      text: "PH",
                    ),
                    Tab(
                      icon: Icon(Icons.science),
                      text: "Nutrisi",
                    ),
                  ],
                ),
                const Expanded(
                  child: TabBarView(
                    children: <Widget>[
                      Center(
                        child: SuhuKelembaban(),
                      ),
                      Center(
                        child: PhLog(),
                      ),
                      Center(
                        child: NutrisiLog(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}