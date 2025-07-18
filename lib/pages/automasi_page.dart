import 'package:flutter/material.dart';
import 'package:hydrohealth/utils/colors.dart';

class AutomasiPage extends StatelessWidget {
  const AutomasiPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.construction_outlined,
                size: 100,
                color: AppColors.secondary,
              ),
              SizedBox(height: 20),
              Text(
                'Fitur Sedang Dibangun',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Sistem Otomasi kami sedang dikembangkan dan akan segera tersedia. Nantikan!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
