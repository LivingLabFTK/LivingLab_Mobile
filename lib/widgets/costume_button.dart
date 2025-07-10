import 'package:flutter/material.dart';

class CostumeButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const CostumeButton({super.key, required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ButtonStyle(
          // ignore: deprecated_member_use
          foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
          // ignore: deprecated_member_use
          backgroundColor: MaterialStateProperty.all<Color>(
              const Color.fromRGBO(124, 197, 41, 1.0)),
          // ignore: deprecated_member_use
          shape: MaterialStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25.5),
          ))),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15),
      ),
    );
  }
}
