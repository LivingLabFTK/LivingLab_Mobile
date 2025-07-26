import 'package:flutter/material.dart';
import 'package:hydrohealth/content/profile.dart';
import 'package:hydrohealth/pages/automasi_page.dart';
import 'package:hydrohealth/pages/monitoring_page.dart';
import 'package:hydrohealth/pages/realtime_page.dart';
import 'package:hydrohealth/widgets/navbar.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  @override
  Widget build(BuildContext context) {
    return const CircleNavBarPage(
      pages: [
        MonitoringPage(),
        RealtimePage(),
        AutomasiPage(),
        Profile(),
      ],
    );
  }
}
