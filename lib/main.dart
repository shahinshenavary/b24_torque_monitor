import 'package:b24_torque_monitor/data/local/database.dart';
import 'package:b24_torque_monitor/data/repository/measurement_repository.dart';
import 'package:b24_torque_monitor/presentation/home_page.dart';
import 'package:flutter/material.dart';

// تابع main حالا async است تا بتوانیم قبل از اجرای اپ، دیتابیس را بسازیم
Future<void> main() async {
  // 1. اطمینان از آماده بودن Flutter برای اجرای کدهای نیتیو
  WidgetsFlutterBinding.ensureInitialized();

  // 2. ساخت یک نمونه از دیتابیس و ریپازیتوری
  // این نمونه‌ها در کل طول عمر اپلیکیشن زنده خواهند ماند
  final AppDatabase database = AppDatabase();
  final MeasurementRepository repository = MeasurementRepository(database);

  // 3. اجرای اپلیکیشن و "تزریق وابستگی"
  // ما ریپازیتوری را به صفحه اصلی پاس می‌دهیم تا بتواند از آن استفاده کند
  runApp(MyApp(
    measurementRepository: repository,
  ));
}

class MyApp extends StatelessWidget {
  final MeasurementRepository measurementRepository;

  const MyApp({
    Key? key,
    required this.measurementRepository,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'B24 Torque Monitor',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.blueAccent,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[900],
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      // صفحه اصلی ما حالا ریپازیتوری را به عنوان ورودی دریافت می‌کند
      home: HomePage(repository: measurementRepository),
      debugShowCheckedModeBanner: false,
    );
  }
}
