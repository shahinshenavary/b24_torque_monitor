// file: services/b24_repository.dart

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/b24_measurement.dart';

class B24Repository {
  // --- تنظیمات امنیتی پروتکل ---
  final List<int> _seed = [0x5C, 0x6F, 0x2F, 0x41, 0x21, 0x7A, 0x26, 0x45, 0x5C, 0x6F];
  final List<int> _defaultPin = [0x30, 0x30, 0x30, 0x30]; // "0000"
  final int _tagHead = 0x4D;
  final int _tagTail = 0x80;

  // استریم کنترلر برای پخش داده‌ها به کل اپلیکیشن
  final _dataStreamController = StreamController<B24Measurement>.broadcast();

  Stream<B24Measurement> get measurementStream => _dataStreamController.stream;

  StreamSubscription? _scanSubscription;
  bool isScanning = false;

  // شروع اسکن و شنود
   // شروع اسکن و شنود (نسخه اصلاح شده)
  Future<void> startMonitoring() async {
    if (isScanning) return;

    // اطمینان از روشن بودن بلوتوث
    if (await FlutterBluePlus.adapterState.first == BluetoothAdapterState.off) {
      throw Exception("Bluetooth is off");
    }

    isScanning = true;
    
    // دستور شروع اسکن (خط خطا دار حذف شد)
    await FlutterBluePlus.startScan(
      continuousUpdates: true, // این خط باعث می‌شود تغییرات لحظه‌ای دیتا را بگیریم
      // allowDuplicates حذف شد چون در نسخه جدید لازم نیست
    );

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult result in results) {
        _processScanResult(result);
      }
    });
  }


  // توقف اسکن
  Future<void> stopMonitoring() async {
    await FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    isScanning = false;
  }

  // منطق دیکد کردن (Core Logic)
  void _processScanResult(ScanResult result) {
    result.advertisementData.manufacturerData.forEach((mId, packetBytes) {
      // بررسی اولیه هدر برای سرعت
      if (packetBytes.length < 8) return;

      // جستجوی پترن 4D 80
      for (int i = 0; i < packetBytes.length - 1; i++) {
        if (packetBytes[i] == _tagHead && packetBytes[i + 1] == _tagTail) {
          int dataStartIndex = i + 2;
          
          // محافظت در برابر طول آرایه
          if (dataStartIndex + 6 <= packetBytes.length) {
            _decodeAndEmit(result.device.remoteId.str, result.rssi, packetBytes, dataStartIndex);
            return; // وقتی پکت پیدا شد، از حلقه خارج شو
          }
        }
      }
    });
  }

  void _decodeAndEmit(String deviceId, int rssi, List<int> rawPacket, int startIndex) {
    try {
      // 1. اعمال الگوریتم XOR
      List<int> decoded = [];
      for (int j = 0; j < 6; j++) {
        int encryptedByte = rawPacket[startIndex + j];
        // فرمول جادویی: Encrypted ^ (Seed ^ PIN)
        int key = _seed[j] ^ _defaultPin[j % 4];
        decoded.add(encryptedByte ^ key);
      }

      // 2. استخراج فیلدها
      // Byte 0: Status (فعلا نادیده می‌گیریم)
      int unitByte = decoded[1]; // Byte 1: Unit Code
      
      // Bytes 2-5: Data (Float - Big Endian)
      Uint8List floatBytes = Uint8List.fromList(decoded.sublist(2, 6));
      double value = ByteData.sublistView(floatBytes).getFloat32(0, Endian.big);

      // 3. تشخیص واحد (طبق مستندات)
      String unitLabel = "Unknown";
      if (unitByte == 0x00) unitLabel = "mV/V";
      else if (unitByte == 0xFF) unitLabel = "Custom (Raw)";
      else if (unitByte == 0x2D) unitLabel = "kg";
      else if (unitByte == 0x96) unitLabel = "Nm";
      // ... سایر واحدها طبق Appendix B

      // 4. ساخت آبجکت نهایی و ارسال به UI
      final measurement = B24Measurement(
        deviceId: deviceId,
        timestamp: DateTime.now(),
        value: value,
        unit: unitLabel,
        signalStrength: rssi,
      );

      _dataStreamController.add(measurement);

    } catch (e) {
      print("Decoding Error: $e");
    }
  }
}
