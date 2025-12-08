import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/project.dart';
import '../models/pile.dart';
import '../models/measurement.dart';
import '../database/database_helper.dart';

class ExcelExportService {
  static final ExcelExportService instance = ExcelExportService._init();
  ExcelExportService._init();

  /// Export project with all data to Excel file
  Future<String> exportProject(Project project) async {
    try {
      // Create Excel workbook
      final excel = Excel.createExcel();
      
      // Remove default sheet
      excel.delete('Sheet1');

      // Get project data
      final piles = await DatabaseHelper.instance.getPilesByProject(project.id);
      
      // Create sheets
      await _createProjectInfoSheet(excel, project, piles);
      await _createPilesSummarySheet(excel, project, piles);
      await _createDetailedMeasurementsSheet(excel, project, piles);

      // Save file
      final filePath = await _saveExcelFile(excel, project.name);
      
      return filePath;
    } catch (e) {
      throw Exception('Export failed: $e');
    }
  }

  /// Share project Excel file (NO PERMISSION REQUIRED!)
  Future<void> shareProject(Project project) async {
    try {
      // Create Excel workbook
      final excel = Excel.createExcel();
      
      // Remove default sheet
      excel.delete('Sheet1');

      // Get project data
      final piles = await DatabaseHelper.instance.getPilesByProject(project.id);
      
      // Create sheets
      await _createProjectInfoSheet(excel, project, piles);
      await _createPilesSummarySheet(excel, project, piles);
      await _createDetailedMeasurementsSheet(excel, project, piles);

      // Save to temporary file
      final fileBytes = excel.encode();
      if (fileBytes == null) {
        throw Exception('Failed to encode Excel file');
      }

      // Create filename with timestamp
      final timestamp = DateTime.now();
      final fileName = '${project.name.replaceAll(RegExp(r'[^\w\s-]'), '_')}_${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}_${timestamp.hour.toString().padLeft(2, '0')}${timestamp.minute.toString().padLeft(2, '0')}.xlsx';
      
      // Use temporary directory
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);

      // Share the file
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'B24 Torque Report - ${project.name}',
        text: 'Project: ${project.name}\nLocation: ${project.location}\nTotal Piles: ${piles.length}',
      );
    } catch (e) {
      throw Exception('Share failed: $e');
    }
  }

  /// Sheet 1: Project Information
  Future<void> _createProjectInfoSheet(Excel excel, Project project, List<Pile> piles) async {
    final sheet = excel['Project Info'];
    
    // Styling
    final headerStyle = CellStyle(
      bold: true,
      fontSize: 14,
      backgroundColorHex: ExcelColor.fromHexString('#2563EB'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );
    
    final labelStyle = CellStyle(
      bold: true,
      fontSize: 12,
    );

    int row = 0;
    
    // Title
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = TextCellValue('B24 TORQUE MONITORING REPORT')
      ..cellStyle = CellStyle(bold: true, fontSize: 16);
    row += 2;

    // Project Information
    final projectInfo = [
      ['Project Name:', project.name],
      ['Location:', project.location],
      ['Created Date:', _formatDate(DateTime.fromMillisecondsSinceEpoch(project.createdAt))],
      ['Total Piles:', piles.length.toString()],
      ['Completed Piles:', piles.where((p) => p.status == 'completed').length.toString()],
      ['In Progress:', piles.where((p) => p.status == 'in_progress').length.toString()],
      ['Pending:', piles.where((p) => p.status == 'pending').length.toString()],
    ];

    for (var info in projectInfo) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue(info[0]);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).cellStyle = labelStyle;
      
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue(info[1]);
      row++;
    }

    row += 1;

    // Device Configuration
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = TextCellValue('Device Configuration:')
      ..cellStyle = labelStyle;
    row++;
    
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue('VIEW PIN:');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue(project.viewPin);
    row++;
    
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue('Device DATA TAGs:');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue(
      project.deviceDataTags.map((tag) => '0x${tag.toRadixString(16).toUpperCase()}').join(', ')
    );
  }

  /// Sheet 2: Piles Summary with Max Torque and Final Depth
  Future<void> _createPilesSummarySheet(Excel excel, Project project, List<Pile> piles) async {
    final sheet = excel['Piles Summary'];
    
    final headerStyle = CellStyle(
      bold: true,
      fontSize: 12,
      backgroundColorHex: ExcelColor.fromHexString('#2563EB'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );

    int row = 0;

    // Headers
    final headers = [
      'Pile ID',
      'Pile Number',
      'Type',
      'Expected Torque (Nm)',
      'Max Torque (Nm)',
      'Expected Depth (m)',
      'Final Depth (m)',
      'Status',
      'Measurements Count',
    ];

    for (int i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row))
        ..value = TextCellValue(headers[i])
        ..cellStyle = headerStyle;
    }
    row++;

    // Data rows
    for (var pile in piles) {
      // Get measurements for this pile
      final measurements = await DatabaseHelper.instance.getMeasurementsByPile(pile.id);
      
      // Calculate max torque
      double maxTorque = 0;
      if (measurements.isNotEmpty) {
        maxTorque = measurements.map((m) => m.torque.abs()).reduce((a, b) => a > b ? a : b);
      }

      final rowData = [
        pile.pileId,
        pile.pileNumber,
        pile.pileType,
        pile.expectedTorque.toStringAsFixed(1),
        measurements.isNotEmpty ? maxTorque.toStringAsFixed(1) : 'N/A',
        pile.expectedDepth.toStringAsFixed(2),
        pile.finalDepth != null ? pile.finalDepth!.toStringAsFixed(2) : 'N/A',
        _getStatusText(pile.status),
        measurements.length.toString(),
      ];

      for (int i = 0; i < rowData.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row));
        cell.value = TextCellValue(rowData[i]);
        
        // Color code status
        if (i == 7) { // Status column
          if (pile.status == 'completed') {
            cell.cellStyle = CellStyle(
              backgroundColorHex: ExcelColor.fromHexString('#D1FAE5'),
              fontColorHex: ExcelColor.fromHexString('#065F46'),
            );
          } else if (pile.status == 'in_progress') {
            cell.cellStyle = CellStyle(
              backgroundColorHex: ExcelColor.fromHexString('#FEF3C7'),
              fontColorHex: ExcelColor.fromHexString('#92400E'),
            );
          }
        }
      }
      row++;
    }
  }

  /// Sheet 3: Detailed Measurements (for charts)
  Future<void> _createDetailedMeasurementsSheet(Excel excel, Project project, List<Pile> piles) async {
    final sheet = excel['Detailed Measurements'];
    
    final headerStyle = CellStyle(
      bold: true,
      fontSize: 12,
      backgroundColorHex: ExcelColor.fromHexString('#2563EB'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );

    int row = 0;

    // Headers
    final headers = [
      'Pile ID',
      'Pile Number',
      'Timestamp',
      'Torque (Nm)',
      'Depth (m)',
      'Force (N)',
      'Mass (kg)',
    ];

    for (int i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row))
        ..value = TextCellValue(headers[i])
        ..cellStyle = headerStyle;
    }
    row++;

    // Add measurements for each pile
    for (var pile in piles) {
      final measurements = await DatabaseHelper.instance.getMeasurementsByPile(pile.id);
      
      for (var measurement in measurements) {
        final rowData = [
          pile.pileId,
          pile.pileNumber,
          _formatDateTime(DateTime.fromMillisecondsSinceEpoch(measurement.timestamp)),
          measurement.torque.toStringAsFixed(2),
          measurement.depth.toStringAsFixed(3),
          measurement.force.toStringAsFixed(1),
          measurement.mass.toStringAsFixed(1),
        ];

        for (int i = 0; i < rowData.length; i++) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row)).value = TextCellValue(rowData[i]);
        }
        row++;
      }
    }

    // Add note about charts
    row += 2;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = TextCellValue('NOTE: You can create charts in Excel using this data')
      ..cellStyle = CellStyle(italic: true, fontColorHex: ExcelColor.fromHexString('#6B7280'));
    row++;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = TextCellValue('Suggested: Insert > Chart > Line Chart (Torque vs Timestamp for each pile)')
      ..cellStyle = CellStyle(italic: true, fontColorHex: ExcelColor.fromHexString('#6B7280'));
  }

  /// Save Excel file to app-specific directory (NO PERMISSION REQUIRED!)
  Future<String> _saveExcelFile(Excel excel, String projectName) async {
    // Encode Excel
    final fileBytes = excel.encode();
    if (fileBytes == null) {
      throw Exception('Failed to encode Excel file');
    }

    // Create filename with timestamp
    final timestamp = DateTime.now();
    final fileName = '${projectName.replaceAll(RegExp(r'[^\w\s-]'), '_')}_${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}_${timestamp.hour.toString().padLeft(2, '0')}${timestamp.minute.toString().padLeft(2, '0')}.xlsx';
    
    if (Platform.isAndroid) {
      // Use getExternalStorageDirectory - NO PERMISSION NEEDED!
      // This saves to: /storage/emulated/0/Android/data/com.example.b24_torque_monitor/files/B24_Reports
      final externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        throw Exception('Could not access external storage directory');
      }

      // Create B24_Reports folder
      final reportsDir = Directory('${externalDir.path}/B24_Reports');
      if (!await reportsDir.exists()) {
        await reportsDir.create(recursive: true);
      }

      // Create file path
      final filePath = '${reportsDir.path}/$fileName';
      final file = File(filePath);

      // Write file
      await file.writeAsBytes(fileBytes);

      return filePath;
    } else {
      throw Exception('iOS export not implemented yet');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'completed':
        return 'Completed';
      case 'in_progress':
        return 'In Progress';
      case 'pending':
        return 'Pending';
      default:
        return status;
    }
  }
}