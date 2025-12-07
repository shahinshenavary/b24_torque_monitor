import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _viewPinController = TextEditingController(text: '0000');
  
  List<Pile> _piles = [];
  bool _isImporting = false;
  
  // Device DATA TAGs management
  List<int> _deviceDataTags = [];
  final TextEditingController _dataTagController = TextEditingController();

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
        
        // Variables to hold project info from Excel (only name & location)
        String? excelProjectName;
        String? excelLocation;

        for (var table in excel.tables.keys) {
          final sheet = excel.tables[table];
          if (sheet == null) continue;

          // Try to read project info from first 2 rows
          if (sheet.rows.length > 2) {
            // Row 1: Project Name | <value>
            if (sheet.rows[0].length >= 2) {
              final label = sheet.rows[0][0]?.value?.toString().toLowerCase() ?? '';
              if (label.contains('project') || label.contains('name')) {
                excelProjectName = sheet.rows[0][1]?.value?.toString()?.trim();
              }
            }
            
            // Row 2: Location | <value>
            if (sheet.rows[1].length >= 2) {
              final label = sheet.rows[1][0]?.value?.toString().toLowerCase() ?? '';
              if (label.contains('location')) {
                excelLocation = sheet.rows[1][1]?.value?.toString()?.trim();
              }
            }
          }

          // Read piles starting from row 4 (index 3) or row 5 (index 4)
          // Skip header row which should be at index 3
          final startRow = sheet.rows.length > 4 ? 4 : 1;
          
          for (var i = startRow; i < sheet.rows.length; i++) {
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
          
          // Auto-fill only project name & location if found in Excel
          if (excelProjectName != null && excelProjectName.isNotEmpty) {
            _nameController.text = excelProjectName;
          }
          if (excelLocation != null && excelLocation.isNotEmpty) {
            _locationController.text = excelLocation;
          }
        });

        if (mounted) {
          String message = '${importedPiles.length} piles imported';
          if (excelProjectName != null) {
            message += '\nProject info loaded from Excel';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      } else {
        setState(() => _isImporting = false);
      }
    } catch (e) {
      setState(() => _isImporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import error: $e')),
        );
      }
    }
  }
  
  // Add DATA TAG manually
  void _addDataTag() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Device DATA TAG'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the DATA TAG in hexadecimal format:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              'Example: 4D80, 5A90, 6BC0',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _dataTagController,
              decoration: const InputDecoration(
                labelText: 'DATA TAG (Hex)',
                hintText: '4D80',
                prefixText: '0x',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f]')),
                LengthLimitingTextInputFormatter(4),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Hexadecimal (0-9, A-F), max 4 characters',
              style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final hexString = _dataTagController.text.trim().toUpperCase();
              if (hexString.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a DATA TAG')),
                );
                return;
              }
              
              try {
                final dataTag = int.parse(hexString, radix: 16);
                
                if (_deviceDataTags.contains(dataTag)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('DATA TAG already added')),
                  );
                  return;
                }
                
                setState(() {
                  _deviceDataTags.add(dataTag);
                });
                
                _dataTagController.clear();
                Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('DATA TAG 0x$hexString added')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Invalid hex format: $e')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
  
  // Remove DATA TAG
  void _removeDataTag(int dataTag) {
    setState(() {
      _deviceDataTags.remove(dataTag);
    });
  }

  Future<void> _saveProject() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_deviceDataTags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one device DATA TAG')),
      );
      return;
    }
    
    if (_piles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one pile')),
      );
      return;
    }

    try {
      final project = Project(
        id: 'project-${DateTime.now().millisecondsSinceEpoch}',
        name: _nameController.text,
        location: _locationController.text,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        deviceDataTags: _deviceDataTags,
        viewPin: _viewPinController.text,
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
          SnackBar(content: Text('Save error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Project'),
        actions: [
          TextButton.icon(
            onPressed: _saveProject,
            icon: const Icon(Icons.check),
            label: const Text('Save'),
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
              // Project Information Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Project Information',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Project Name',
                          prefixIcon: Icon(Icons.business),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value?.isEmpty ?? true ? 'Project name is required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: 'Location',
                          prefixIcon: Icon(Icons.location_on),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value?.isEmpty ?? true ? 'Location is required' : null,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Device Configuration Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Device Configuration',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Configure the B24 devices used in this project',
                        style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                      ),
                      const SizedBox(height: 16),
                      
                      // VIEW PIN Input
                      TextFormField(
                        controller: _viewPinController,
                        decoration: const InputDecoration(
                          labelText: 'VIEW PIN',
                          hintText: '0000',
                          helperText: 'Default is 0000, change if different',
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z]')),
                          LengthLimitingTextInputFormatter(8),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'VIEW PIN is required';
                          if (value.length > 8) return 'VIEW PIN max 8 characters';
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      
                      // DATA TAGs Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Device DATA TAGs',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            '${_deviceDataTags.length} device(s)',
                            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add the DATA TAG(s) of B24 devices to use',
                        style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                      ),
                      const SizedBox(height: 16),
                      
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _addDataTag,
                          icon: const Icon(Icons.add),
                          label: const Text('Add DATA TAG'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      
                      if (_deviceDataTags.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _deviceDataTags.length,
                          itemBuilder: (context, index) {
                            final dataTag = _deviceDataTags[index];
                            final hexString = dataTag.toRadixString(16).padLeft(4, '0').toUpperCase();
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const Icon(Icons.bluetooth, color: Color(0xFF3B82F6)),
                                title: Text(
                                  'B24-$hexString',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text('DATA TAG: 0x$hexString (Decimal: $dataTag)'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _removeDataTag(dataTag),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Piles Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Piles',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            '${_piles.length} piles',
                            style: const TextStyle(color: Color(0xFF9CA3AF)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isImporting ? null : _importExcel,
                          icon: _isImporting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.upload_file),
                          label: Text(_isImporting ? 'Importing...' : 'Import from Excel'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
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
                              title: Text('${pile.pileId} - No. ${pile.pileNumber}'),
                              subtitle: Text('${pile.pileType} | ${pile.expectedTorque} Nm | ${pile.expectedDepth} m'),
                              dense: true,
                            );
                          },
                        ),
                        if (_piles.length > 5)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'and ${_piles.length - 5} more piles...',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 80), // Space for FAB
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
    _viewPinController.dispose();
    _dataTagController.dispose();
    super.dispose();
  }
}