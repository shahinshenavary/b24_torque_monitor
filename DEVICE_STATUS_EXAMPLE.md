# 📊 مثال کامل: ذخیره و نمایش Device Status

## 1️⃣ **ساختار داده در Database**

### **جدول `measurements` - Schema:**

```sql
CREATE TABLE measurements (
  id TEXT PRIMARY KEY,
  projectId TEXT NOT NULL,
  pileId TEXT NOT NULL,
  operatorCode TEXT NOT NULL,
  timestamp INTEGER NOT NULL,
  torque REAL NOT NULL,
  force REAL NOT NULL,
  mass REAL NOT NULL,
  depth REAL NOT NULL,
  statusByte INTEGER DEFAULT 0,      -- 🆕 Status byte خام (0x00 - 0xFF)
  statusJson TEXT DEFAULT "{}",       -- 🆕 JSON کامل برای آنالیز
  FOREIGN KEY (projectId) REFERENCES projects (id),
  FOREIGN KEY (pileId) REFERENCES piles (id)
);
```

---

## 2️⃣ **مثال داده‌های ذخیره شده**

### **سناریو 1: کار عادی (همه چیز OK)**

```json
{
  "id": "meas_001",
  "projectId": "proj_123",
  "pileId": "pile_456",
  "operatorCode": "OP789",
  "timestamp": 1702012345000,
  "torque": 45.3,
  "force": 444.2,
  "mass": 46.2,
  "depth": 2.5,
  "statusByte": 0,  
  "statusJson": "{\"rawByte\":0,\"shuntCal\":false,\"integrityError\":false,\"isTared\":false,\"overRange\":false,\"fastMode\":false,\"batteryLow\":false,\"digitalInput\":false}"
}
```

**معنی:** همه چیز عادی ✅  
**نمایش در UI:** نشانگر سبز "عادی"

---

### **سناریو 2: باتری کم (Battery Low)**

```json
{
  "id": "meas_002",
  "projectId": "proj_123",
  "pileId": "pile_456",
  "operatorCode": "OP789",
  "timestamp": 1702012346000,
  "torque": 89.7,
  "force": 879.6,
  "mass": 91.5,
  "depth": 3.2,
  "statusByte": 32,  // 0x20 = 0b00100000 (Bit 5 = Battery Low)
  "statusJson": "{\"rawByte\":32,\"shuntCal\":false,\"integrityError\":false,\"isTared\":false,\"overRange\":false,\"fastMode\":false,\"batteryLow\":true,\"digitalInput\":false}"
}
```

**معنی:** باتری کم است 🔋  
**نمایش در UI:** نشانگر نارنجی "باتری کم" (با انیمیشن)  
**اقدام:** کار ادامه پیدا می‌کند، اما اخطار نمایش داده می‌شود

---

### **سناریو 3: خطای سنسور (Integrity Error) + Over Range**

```json
{
  "id": "meas_003",
  "projectId": "proj_123",
  "pileId": "pile_456",
  "operatorCode": "OP789",
  "timestamp": 1702012347000,
  "torque": 215.4,
  "force": 2113.0,
  "mass": 219.7,
  "depth": 4.8,
  "statusByte": 10,  // 0x0A = 0b00001010 (Bit 1 = Integrity Error, Bit 3 = Over Range)
  "statusJson": "{\"rawByte\":10,\"shuntCal\":false,\"integrityError\":true,\"isTared\":false,\"overRange\":true,\"fastMode\":false,\"batteryLow\":false,\"digitalInput\":false}"
}
```

**معنی:** خطای سنسور + خارج از محدوده ⚠️🔴  
**نمایش در UI:** نشانگر قرمز چشمک‌زن "خطای سنسور" + "خارج از محدوده"  
**اقدام:** کار ادامه پیدا می‌کند، اما داده قابل اعتماد نیست

---

### **سناریو 4: Tared Mode + Fast Mode**

```json
{
  "id": "meas_004",
  "projectId": "proj_123",
  "pileId": "pile_456",
  "operatorCode": "OP789",
  "timestamp": 1702012348000,
  "torque": 56.2,
  "force": 551.2,
  "mass": 57.3,
  "depth": 5.1,
  "statusByte": 20,  // 0x14 = 0b00010100 (Bit 2 = Tared, Bit 4 = Fast Mode)
  "statusJson": "{\"rawByte\":20,\"shuntCal\":false,\"integrityError\":false,\"isTared\":true,\"overRange\":false,\"fastMode\":true,\"batteryLow\":false,\"digitalInput\":false}"
}
```

**معنی:** حالت Net (Tare applied) + Fast Mode 🏃  
**نمایش در UI:** نشانگر آبی "Net" + "Fast Mode"  
**اقدام:** کار عادی، فقط اطلاع‌رسانی

---

## 3️⃣ **نحوه بازیابی و نمایش در UI**

### **کد Dart برای بازیابی:**

```dart
// بازیابی از دیتابیس
Future<List<Measurement>> getMeasurementsWithStatus(String pileId) async {
  final db = await database;
  final maps = await db.query(
    'measurements',
    where: 'pileId = ?',
    whereArgs: [pileId],
    orderBy: 'timestamp ASC',
  );
  
  return maps.map((map) => Measurement.fromMap(map)).toList();
}

// هر Measurement حالا شامل DeviceStatus است:
for (var measurement in measurements) {
  print('Torque: ${measurement.torque} Nm');
  print('Status: ${measurement.status.summary}');
  
  if (measurement.status.hasCriticalError) {
    print('⚠️ این داده مشکل دارد!');
  }
}
```

---

## 4️⃣ **نمایش در جدول داده‌ها**

```dart
DataTable(
  columns: [
    DataColumn(label: Text('زمان')),
    DataColumn(label: Text('گشتاور')),
    DataColumn(label: Text('عمق')),
    DataColumn(label: Text('وضعیت')), // 🆕 ستون وضعیت
  ],
  rows: measurements.map((m) {
    return DataRow(
      // اگر خطای critical داشته باشد، رنگ ردیف قرمز می‌شود
      color: m.status.hasCriticalError 
        ? MaterialStateProperty.all(Colors.red.shade50)
        : null,
      cells: [
        DataCell(Text(formatTime(m.timestamp))),
        DataCell(Text('${m.torque.toStringAsFixed(2)} Nm')),
        DataCell(Text('${m.depth.toStringAsFixed(2)} m')),
        DataCell(
          // نمایش compact status indicators
          DeviceStatusIndicators(status: m.status, compact: true)
        ),
      ],
    );
  }).toList(),
)
```

---

## 5️⃣ **گزارش Excel با Status**

```dart
// هنگام export به Excel، status هم شامل می‌شود:
for (var i = 0; i < measurements.length; i++) {
  final m = measurements[i];
  sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 1))
    .value = formatTime(m.timestamp);
  sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1))
    .value = m.torque;
  sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i + 1))
    .value = m.depth;
  
  // 🆕 ستون Status
  sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: i + 1))
    .value = m.status.summary; // مثلاً: "✅ Normal" یا "⚠️ Sensor Error, Battery Low"
    
  // 🆕 رنگ‌آمیزی براساس status
  if (m.status.hasCriticalError) {
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: i + 1))
      .cellStyle = CellStyle(backgroundColorHex: '#FFEBEE'); // قرمز کم‌رنگ
  } else if (m.status.hasWarning) {
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: i + 1))
      .cellStyle = CellStyle(backgroundColorHex: '#FFF3E0'); // نارنجی کم‌رنگ
  }
}
```

---

## 6️⃣ **فیلتر کردن داده‌های مشکل‌دار**

```dart
// فقط داده‌هایی با critical error
final errorMeasurements = measurements.where((m) => m.status.hasCriticalError).toList();

// فقط داده‌های سالم
final cleanMeasurements = measurements.where((m) => 
  !m.status.hasCriticalError && !m.status.hasWarning
).toList();

// نمایش آمار
print('کل داده‌ها: ${measurements.length}');
print('داده‌های سالم: ${cleanMeasurements.length}');
print('داده‌های مشکل‌دار: ${errorMeasurements.length}');
print('درصد سلامت: ${(cleanMeasurements.length / measurements.length * 100).toStringAsFixed(1)}%');
```

---

## 7️⃣ **Query مثال در SQLite**

```sql
-- یافتن همه اندازه‌گیری‌های با خطای سنسور
SELECT * FROM measurements 
WHERE (statusByte & 2) != 0  -- Bit 1 = Integrity Error
ORDER BY timestamp DESC;

-- یافتن اندازه‌گیری‌های با باتری کم
SELECT * FROM measurements 
WHERE (statusByte & 32) != 0  -- Bit 5 = Battery Low
ORDER BY timestamp DESC;

-- یافتن اندازه‌گیری‌های کاملاً سالم
SELECT * FROM measurements 
WHERE statusByte = 0
ORDER BY timestamp DESC;

-- آمار status در یک pile
SELECT 
  COUNT(*) as total,
  SUM(CASE WHEN statusByte = 0 THEN 1 ELSE 0 END) as healthy,
  SUM(CASE WHEN (statusByte & 2) != 0 THEN 1 ELSE 0 END) as sensor_error,
  SUM(CASE WHEN (statusByte & 32) != 0 THEN 1 ELSE 0 END) as battery_low
FROM measurements
WHERE pileId = 'pile_456';
```

---

## 8️⃣ **خلاصه مزایا**

✅ **هر داده ذخیره شده status دارد** - بعداً می‌توانید تحلیل کنید  
✅ **کار قطع نمی‌شود** - فقط هشدار می‌دهد  
✅ **قابل filter و search** - می‌توانید داده‌های مشکل‌دار را جدا کنید  
✅ **Export to Excel** - status هم در گزارش می‌آید  
✅ **Visual indicators** - فوراً متوجه مشکل می‌شوید  

---

**این سیستم کامل است و آماده استفاده! 🚀**
