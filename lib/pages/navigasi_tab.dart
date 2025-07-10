import 'package:buttons_tabbar/buttons_tabbar.dart';
import 'package:flutter/material.dart';
import 'package:hydrohealth/content/suhu_kelembaban.dart';
import 'package:hydrohealth/content/nutrisi.dart';
import 'package:hydrohealth/content/ph.dart';

class NavigasiTab extends StatefulWidget {
  const NavigasiTab({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _NavigasiTabState createState() => _NavigasiTabState();
}

class _NavigasiTabState extends State<NavigasiTab> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HISTORY'),
        backgroundColor: const Color.fromRGBO(153, 188, 133, 1),
      ),
      body: SafeArea(
        child: DefaultTabController(
          length: 3,
          child: Container(
            color: const Color.fromRGBO(225, 240, 218, 1),
            child: Column(
              children: <Widget>[
                ButtonsTabBar(
                  backgroundColor: const Color.fromRGBO(153, 188, 133, 1),
                  unselectedBackgroundColor:
                      const Color.fromRGBO(225, 240, 218, 1),
                  unselectedLabelStyle: const TextStyle(color: Colors.black),
                  labelStyle: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.thermostat),
                      text: "SUHU",
                    ),
                    Tab(
                      icon: Icon(Icons.opacity),
                      text: "PH",
                    ),
                    Tab(
                      icon: Icon(Icons.science),
                      text: "NUTRISI",
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
