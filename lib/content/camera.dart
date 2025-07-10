import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hydrohealth/services/classify_api.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

class Camera extends StatefulWidget {
  const Camera({super.key});

  @override
  CameraState createState() => CameraState();
}

class CameraState extends State<Camera> {
  File? imageFile;
  Map<String, dynamic>? result;
  bool isLoading = false;
  final imagePicker = ImagePicker();
  final ApiService apiService = ApiService();

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Scan Image",
          textAlign: TextAlign.center,
        ),
        centerTitle: true,
        backgroundColor: const Color.fromRGBO(225, 240, 218, 1),
      ),
      backgroundColor: const Color.fromRGBO(225, 240, 218, 1),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              height: 250,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.5),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (imageFile != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(imageFile!.path),
                        width: size.width - 40,
                        height: 250,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    const Center(
                      child: Icon(
                        Icons.image_outlined,
                        color: Colors.blueGrey,
                        size: 60,
                      ),
                    ),
                  if (result != null)
                    Positioned(
                      bottom: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        color: Colors.black.withValues(alpha: 0.541),
                        child: Text(
                          '${result!['predicted_class']} (${(result!['probability'] * 100).toStringAsFixed(2)}%)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (isLoading)
                    Container(
                      color: Colors.black.withValues(alpha: 0.541),
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            _buildButton("Pick Image", showPictureDialog),
            const SizedBox(height: 40),
            _buildButton("Clear Image", () {
              setState(() {
                imageFile = null;
                result = null;
                isLoading = false;
              });
            }),
            const SizedBox(height: 40),
            _buildButton("Deteksi Image", () async {
              if (imageFile != null) {
                setState(() {
                  isLoading = true;
                });
                try {
                  final response = await apiService.uploadImage(imageFile!);
                  if (!mounted) return;
                  setState(() {
                    result = response;
                    isLoading = false;
                  });
                } catch (e) {
                  if (!mounted) return;
                  setState(() {
                    isLoading = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(String text, Function() onPressed) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.6,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        color: const Color.fromRGBO(153, 188, 133, 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.5),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        borderRadius: BorderRadius.circular(25),
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: onPressed,
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> showPictureDialog() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    _getImageFromSource(ImageSource.camera);
                  },
                  child: const Text('Open Camera'),
                ),
                const Padding(padding: EdgeInsets.all(8)),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    _getImageFromSource(ImageSource.gallery);
                  },
                  child: const Text('Open Gallery'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _getImageFromSource(ImageSource source) async {
    final pickedFile = await imagePicker.pickImage(
      source: source,
      maxWidth: 1800,
      maxHeight: 1800,
    );
    if (pickedFile != null) {
      File? compressedFile = await _compressImage(File(pickedFile.path));
      setState(() {
        imageFile = compressedFile;
        result = null;
      });
    }
  }

  Future<File?> _compressImage(File file) async {
    final originalImage = img.decodeImage(file.readAsBytesSync());
    if (originalImage == null) return null;
    int quality = 100;
    List<int> compressedBytes;

    do {
      quality -= 10;
      compressedBytes = img.encodeJpg(originalImage, quality: quality);
    } while (compressedBytes.length > 500 * 1024 && quality > 0);

    if (quality == 0) return null;

    final compressedFile = File('${file.path}_compressed.jpg')
      ..writeAsBytesSync(compressedBytes);
    return compressedFile;
  }
}