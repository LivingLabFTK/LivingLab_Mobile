import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hydrohealth/content/tanaman.dart';
import 'package:hydrohealth/utils/colors.dart';
import 'package:hydrohealth/widgets/button_web.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hydrohealth/widgets/costume_button.dart';
import 'package:url_launcher/url_launcher.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  Future<void> _launchURL() async {
    final Uri url = Uri.parse('https://hydrohealth.vercel.app/');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  File? _profileImage;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    setState(() {
      if (pickedFile != null) {
        _profileImage = File(pickedFile.path);
      }
    });
  }


  Future<void> _uploadProfileImage() async {
    if (_profileImage != null) {
      try {
        final storageRef = FirebaseStorage.instanceFor(
          bucket: 'gs://hydrohealth-project-9cf6c.appspot.com',
        ).ref().child('profile_images').child('default_user_profile.jpg');

        await storageRef.putFile(_profileImage!);
        final downloadUrl = await storageRef.getDownloadURL();

        setState(() {
          _profileImageUrl = downloadUrl;
        });

      } catch (e) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading profile image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 40),
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 70,
                  backgroundImage: _profileImage != null
                      ? FileImage(_profileImage!)
                      : (_profileImageUrl != null
                      ? NetworkImage(_profileImageUrl!)
                      : const AssetImage('assets/images/logo.png'))
                  as ImageProvider,
                ),
              ),
              const SizedBox(height: 20),
              _buildEditableItem(
                  'Name', _nameController, CupertinoIcons.person),
              const SizedBox(height: 10),
              _buildEditableItem(
                  'Phone', _phoneController, CupertinoIcons.phone),
              const SizedBox(height: 50),
              SizedBox(
                width: double.infinity,
                child: CostumeButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const Tanaman(),
                      ),
                    );
                  },
                  text: 'Tambah Informasi Tanaman',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: CostumeButton(
                  onPressed: () {
                    _saveProfile();
                  },
                  text: 'Save',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child:
                ButtonWeb(text: "Visit Our Website", onPressed: _launchURL),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditableItem(
      String title, TextEditingController controller, IconData iconData) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 5),
            color: const Color.fromARGB(255, 44, 95, 0).withValues(alpha: .2),
            spreadRadius: 2,
            blurRadius: 10,
          ),
        ],
      ),
      child: ListTile(
        title: Text(title),
        subtitle: TextField(
          controller: controller,
          decoration: const InputDecoration(
            border: InputBorder.none,
          ),
        ),
        leading: Icon(iconData),
      ),
    );
  }

  // Fungsi save disederhanakan
  void _saveProfile() async {
    await _uploadProfileImage();

    // Simpan info lain jika perlu (misal ke Firestore, tapi tanpa user ID)
    await FirebaseFirestore.instance.collection('user_profiles').doc('default_user').set({
      'name': _nameController.text,
      'phone': _phoneController.text,
      'photoUrl': _profileImageUrl ?? '',
    }, SetOptions(merge: true));

    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated')),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}