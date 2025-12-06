import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// این خط خیلی مهم است. نام فایل باید دقیقاً database.g.dart باشد
part 'database.g.dart';

// --- تعریف جدول‌ها ---

// ۱. جدول پروژه‌ها
class Projects extends Table {
  TextColumn get id => text()(); // شناسه یکتا
  TextColumn get title => text().withLength(min: 1, max: 100)(); // نام پروژه
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  
  // وضعیت سینک: آیا این پروژه به سرور فرستاده شده؟
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))(); 

  @override
  Set<Column> get primaryKey => {id};
}

// ۲. جدول اندازه‌گیری‌ها (برای داده‌های ۱۰ هرتز)
class Measurements extends Table {
  IntColumn get id => integer().autoIncrement()(); // شناسه خودکار
  TextColumn get projectId => text().references(Projects, #id)(); // لینک به پروژه
  RealColumn get value => real()(); // عدد نهایی کالیبره شده
  DateTimeColumn get timestamp => dateTime()(); // زمان دقیق ثبت

  // برای سرعت بالا در جستجو
  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE'
  ];
}

// --- کلاس اصلی دیتابیس ---

@DriftDatabase(tables: [Projects, Measurements])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // --- متدهای کمکی (Queries) ---

  // ایجاد پروژه جدید
Future<int> createProject(ProjectsCompanion entry) {
  return into(projects).insert(entry);
}
  // لیست همه پروژه‌ها
  Future<List<Project>> getAllProjects() {
    return select(projects).get();
  }

  // اضافه کردن یک رکورد (تک‌شات)
  Future<int> insertMeasurement(String pId, double val) {
    return into(measurements).insert(MeasurementsCompanion(
      projectId: Value(pId),
      value: Value(val),
      timestamp: Value(DateTime.now()),
    ));
  }

  // اضافه کردن گروهی (برای حالت لاگینگ سریع)
  Future<void> insertBatchMeasurements(List<MeasurementsCompanion> items) async {
    await batch((batch) {
      batch.insertAll(measurements, items);
    });
  }

  // خواندن داده‌های یک پروژه خاص
  Future<List<Measurement>> getProjectMeasurements(String pId) {
    return (select(measurements)
      ..where((tbl) => tbl.projectId.equals(pId))
      ..orderBy([(t) => OrderingTerm(expression: t.timestamp)])
    ).get();
  }
}

// تابعی برای باز کردن فایل دیتابیس روی گوشی
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'b24_telemetry.sqlite'));
    return NativeDatabase(file);
  });
}
