import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class Tanaman extends StatefulWidget {
  const Tanaman({super.key});

  @override
  State<Tanaman> createState() => _TanamanState();
}

class _TanamanState extends State<Tanaman> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _countController = TextEditingController();
  final TextEditingController _plantingDateController = TextEditingController();
  final TextEditingController _harvestDateController = TextEditingController();

  final CollectionReference _plantsCollection =
      FirebaseFirestore.instance.collection('InformasiTanaman');

  DateTime? _selectedPlantingDate;
  DateTime? _selectedHarvestDate;

  Future<void> _selectDate(BuildContext context,
      TextEditingController controller, DateTime? initialDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != initialDate) {
      setState(() {
        if (controller == _plantingDateController) {
          _selectedPlantingDate = picked;
        } else {
          _selectedHarvestDate = picked;
        }
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _savePlantInfo() async {
    if (_nameController.text.isEmpty ||
        _countController.text.isEmpty ||
        _plantingDateController.text.isEmpty ||
        _harvestDateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    try {
      await _plantsCollection.add({
        'name': _nameController.text,
        'count': int.parse(_countController.text),
        'plantingDate': _selectedPlantingDate,
        'harvestDate': _selectedHarvestDate,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plant information saved successfully')),
      );
      _nameController.clear();
      _countController.clear();
      _plantingDateController.clear();
      _harvestDateController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save plant information: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add/Edit Plant Information'),
        backgroundColor: const Color.fromRGBO(153, 188, 133, 1),
      ),
      body: Container(
        color: const Color.fromRGBO(225, 240, 218, 1),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Plant Name',
                filled: true,
                fillColor: const Color.fromRGBO(212, 231, 197, 1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _countController,
              decoration: InputDecoration(
                labelText: 'Number of Plants',
                filled: true,
                fillColor: const Color.fromRGBO(212, 231, 197, 1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide.none,
                ),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _plantingDateController,
              decoration: InputDecoration(
                labelText: 'Planting Date',
                filled: true,
                fillColor: const Color.fromRGBO(212, 231, 197, 1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () {
                    _selectDate(context, _plantingDateController,
                        _selectedPlantingDate);
                  },
                ),
              ),
              readOnly: true,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _harvestDateController,
              decoration: InputDecoration(
                labelText: 'Harvest Date',
                filled: true,
                fillColor: const Color.fromRGBO(212, 231, 197, 1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () {
                    _selectDate(
                        context, _harvestDateController, _selectedHarvestDate);
                  },
                ),
              ),
              readOnly: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _savePlantInfo,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(153, 188, 133, 1),
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: const TextStyle(fontSize: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
