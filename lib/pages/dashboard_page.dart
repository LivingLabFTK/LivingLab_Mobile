import 'package:flutter/material.dart';
import 'package:hydrohealth/content/profile.dart';
import 'package:hydrohealth/Content/home.dart';
import 'package:hydrohealth/pages/navigasi_tab.dart';
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
        NavigasiTab(),
        Home(),
        Profile(),
      ],
    );
  }
}
