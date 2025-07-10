import 'package:flutter/material.dart';
import 'package:hydrohealth/pages/coming_soon_page.dart';
import 'package:hydrohealth/pages/dashboard_page.dart';


class SelectionPage extends StatelessWidget {
  const SelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(245, 245, 240, 1.0),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset(
                'assets/images/LivingLabLogo.png'
              ),
              const SizedBox(height: 20),
              const Text(
                'Welcome to Living Lab',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'SFMono',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 44, 95, 0),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Choose your monitoring system',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 50),
              _buildSelectionButton(
                context: context,
                icon: Icons.local_florist_outlined,
                title: 'Smart Garden',
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const Dashboard()),
                  );
                },
              ),
              const SizedBox(height: 20),
              _buildSelectionButton(
                context: context,
                icon: Icons.waves_outlined,
                title: 'Smart Fish',
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const ComingSoonPage()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 28),
      label: Text(title, style: const TextStyle(fontSize: 18)),
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.green,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 5,
      ),
    );
  }
}