import 'dart:async';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../local/database.dart';

class MeasurementRepository {
  final AppDatabase _db;
  
  // متغیرهای داخلی
  String? _currentProjectId; 
  final List<MeasurementsCompanion> _buffer = []; 
  Timer? _batchTimer; 

  MeasurementRepository(this._db);

  // =========================================================
  //  GETTERS (این‌ها باعث رفع خطای currentProjectId می‌شوند)
  // =========================================================
  
  /// آیا الان در حال ضبط هستیم؟
  bool get isRecording => _currentProjectId != null;
  
  /// دسترسی به شناسه پروژه فعلی
  String? get currentProjectId => _currentProjectId;

  // =========================================================
  //  METHODS (این‌ها باعث رفع خطای onNewDataReceived می‌شوند)
  // =========================================================

  /// شروع یک پروژه جدید
  Future<String> startNewProject(String projectName) async {
    final newId = const Uuid().v4();
    
    // استفاده از ProjectsCompanion برای درج داده
    await _db.createProject(ProjectsCompanion(
      id: Value(newId),
      title: Value(projectName),
      createdAt: Value(DateTime.now()),
      isSynced: const Value(false),
    ));

    _currentProjectId = newId;
    _startBufferTimer();
    
    print("Started recording Project: $projectName ($newId)");
    return newId;
  }

  /// توقف ضبط
  Future<void> stopRecording() async {
    if (_currentProjectId == null) return;

    await _flushBuffer();
    _batchTimer?.cancel();
    _currentProjectId = null;
    print("Stopped recording.");
  }

  /// دریافت داده جدید از بلوتوث
  /// (این همان تابعی است که خطا می‌داد تعریف نشده است)
  void onNewDataReceived(double value) {
    // اگر ضبط فعال نیست، کاری نکن
    if (_currentProjectId == null) return;

    _buffer.add(MeasurementsCompanion(
      projectId: Value(_currentProjectId!),
      value: Value(value),
      timestamp: Value(DateTime.now()),
    ));

    if (_buffer.length >= 500) {
      _flushBuffer();
    }
  }

  // =========================================================
  //  INTERNAL HELPER METHODS
  // =========================================================

  Future<void> _flushBuffer() async {
    if (_buffer.isEmpty) return;

    final batchToSave = List<MeasurementsCompanion>.from(_buffer);
    _buffer.clear(); 

    try {
      await _db.insertBatchMeasurements(batchToSave);
      print("Saved batch of ${batchToSave.length} records.");
    } catch (e) {
      print("Error saving batch: $e");
    }
  }

  void _startBufferTimer() {
    _batchTimer?.cancel();
    _batchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _flushBuffer();
    });
  }
  
  Future<List<Project>> getRecentProjects() {
    return _db.getAllProjects();
  }
}
