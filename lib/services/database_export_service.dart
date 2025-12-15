import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';

class DatabaseExportService {
  static final DatabaseExportService instance = DatabaseExportService._init();
  DatabaseExportService._init();

  /// Share the entire database file
  Future<void> shareDatabaseFile() async {
    try {
      // Get the database path
      final dbPath = await DatabaseHelper.instance.getDatabasePath();
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        throw Exception('Database file not found');
      }

      // Create a temporary directory
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'b24_torque_backup_$timestamp.db';
      final tempFile = File(join(tempDir.path, fileName));

      // Copy database to temp directory
      await dbFile.copy(tempFile.path);

      // Share the file
      await Share.shareXFiles(
        [XFile(tempFile.path)],
        subject: 'B24 Torque Database Backup',
        text: 'Database backup created on ${DateTime.now().toString()}',
      );

      // Clean up temp file after a delay (give time for sharing)
      Future.delayed(const Duration(seconds: 10), () {
        if (tempFile.existsSync()) {
          tempFile.deleteSync();
        }
      });
    } catch (e) {
      throw Exception('Failed to share database: $e');
    }
  }

  /// Get database file size in MB
  Future<String> getDatabaseSize() async {
    try {
      final dbPath = await DatabaseHelper.instance.getDatabasePath();
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        return '0 MB';
      }

      final sizeInBytes = await dbFile.length();
      final sizeInMB = sizeInBytes / (1024 * 1024);

      if (sizeInMB < 0.1) {
        return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
      } else {
        return '${sizeInMB.toStringAsFixed(2)} MB';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}
