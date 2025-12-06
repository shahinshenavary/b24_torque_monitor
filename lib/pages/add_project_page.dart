import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import '../models/project.dart';
import '../models/pile.dart';
import '../database/database_helper.dart';

class AddProjectPage extends StatefulWidget {
  final String operatorCode;

  const AddProjectPage({Key? key, required this.operatorCode}) : super(key: key);

  @override
  State<AddProjectPage> createState() => _AddProjectPageState();
}

class _AddProjectPageState extends State<AddProjectPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  
  List<Pile> _piles = [];
  bool _isImporting = false;

  Future<void> _importExcel() async {
    setState(() => _isImporting = true);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        final bytes = await file.readAsBytes();
        final excel = Excel.decodeBytes(bytes);

        final tempProjectId = 'temp-${DateTime.now().millisecondsSinceEpoch}';
        List<Pile> importedPiles = [];

        for (var table in excel.tables.keys) {
          final sheet = excel.tables[table];
          if (sheet == null) continue;

          for (var i = 1; i < sheet.rows.length; i++) {
            final row = sheet.rows[i];
            if (row.length < 5) continue;

            final pileId = row[0]?.value?.toString() ?? '';
            final pileNumber = row[1]?.value?.toString() ?? '';
            final pileType = row[2]?.value?.toString() ?? '';
            final expectedTorque = double.tryParse(row[3]?.value?.toString() ?? '0') ?? 0;
            final expectedDepth = double.tryParse(row[4]?.value?.toString() ?? '0') ?? 0;

            if (pileId.isNotEmpty && pileNumber.isNotEmpty) {
              importedPiles.add(Pile(
                id: 'pile-${DateTime.now().millisecondsSinceEpoch}-$i',
                projectId: tempProjectId,
                pileId: pileId,
                pileNumber: pileNumber,
                pileType: pileType,
                expectedTorque: expectedTorque,
                expectedDepth: expectedDepth,
              ));
            }
          }
        }

        setState(() {
          _piles = importedPiles;
          _isImporting = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${importedPiles.length} شمع وارد شد')),
          );
        }
      } else {
        setState(() => _isImporting = false);
      }
    } catch (e) {
      setState(() => _isImporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در import: $e')),
        );
      }
    }
  }

  Future<void> _saveProject() async {
    if (!_formKey.currentState!.validate()) return;
    if (_piles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً حداقل یک شمع اضافه کنید')),
      );
      return;
    }

    try {
      final project = Project(
        id: 'project-${DateTime.now().millisecondsSinceEpoch}',
        name: _nameController.text,
        location: _locationController.text,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      await DatabaseHelper.instance.insertProject(project);

      final updatedPiles = _piles.map((pile) => pile.copyWith(projectId: project.id)).toList();
      await DatabaseHelper.instance.insertPiles(updatedPiles);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در ذخیره: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('پروژه جدید'),
        actions: [
          TextButton.icon(
            onPressed: _saveProject,
            icon: const Icon(Icons.check),
            label: const Text('ذخیره'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('اطلاعات پروژه', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'نام پروژه',
                          prefixIcon: Icon(Icons.business),
                        ),
                        validator: (value) => value?.isEmpty ?? true ? 'نام پروژه الزامی است' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: 'موقعیت',
                          prefixIcon: Icon(Icons.location_on),
                        ),
                        validator: (value) => value?.isEmpty ?? true ? 'موقعیت الزامی است' : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('شمع‌ها', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('${_piles.length} شمع', style: const TextStyle(color: Color(0xFF9CA3AF))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isImporting ? null : _importExcel,
                          icon: _isImporting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.upload_file),
                          label: Text(_isImporting ? 'در حال Import...' : 'Import از Excel'),
                        ),
                      ),
                      if (_piles.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _piles.length > 5 ? 5 : _piles.length,
                          itemBuilder: (context, index) {
                            final pile = _piles[index];
                            return ListTile(
                              leading: const Icon(Icons.push_pin, size: 20),
                              title: Text('${pile.pileId} - شماره ${pile.pileNumber}'),
                              subtitle: Text('${pile.pileType} | ${pile.expectedTorque} Nm | ${pile.expectedDepth} m'),
                              dense: true,
                            );
                          },
                        ),
                        if (_piles.length > 5)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'و ${_piles.length - 5} شمع دیگر...',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }
}
