// file: models/b24_measurement.dart

class B24Measurement {
  final String deviceId;      // آدرس مک آدرس یا شناسه دستگاه
  final DateTime timestamp;   // زمان دریافت
  final double value;         // مقدار خوانده شده (خام یا کالیبره شده توسط دستگاه)
  final String unit;          // واحد (مثلاً mV/V یا kg)
  final int signalStrength;   // RSSI
  final int batteryLevel;     // (اگر در آینده اضافه شود، فعلا placeholder)

  B24Measurement({
    required this.deviceId,
    required this.timestamp,
    required this.value,
    required this.unit,
    required this.signalStrength,
    this.batteryLevel = 100,
  });

  @override
  String toString() {
    return 'B24Data(val: $value $unit, rssi: $signalStrength)';
  }
}
