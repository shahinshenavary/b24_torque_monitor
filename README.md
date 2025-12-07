# 🔧 B24 Torque Monitor - Flutter App

اپلیکیشن Flutter برای مانیتورینگ گشتاور دستگاه B24 در نصب شمع‌های ساختمانی.

---

## 📋 فهرست

- [ویژگی‌ها](#ویژگیها)
- [نصب و راه‌اندازی](#نصب-و-راهاندازی)
- [نحوه استفاده](#نحوه-استفاده)
- [مشکلات رایج](#مشکلات-رایج)
- [Debug](#debug)
- [مستندات](#مستندات)

---

## 🎯 ویژگی‌ها

### ✅ مدیریت پروژه
- ایجاد پروژه با نام و موقعیت
- **ورودی دستی DATA TAG و VIEW PIN** (بدون نیاز به Scan)
- Import شمع‌ها از فایل Excel
- فیلتر خودکار دستگاه‌های مجاز

### ✅ Bluetooth Monitoring
- **Broadcast Mode**: دریافت داده بدون اتصال
- پشتیبانی از چند دستگاه همزمان
- XOR Decryption با VIEW PIN قابل تنظیم
- Real-time torque monitoring

### ✅ Auto Recording
- ضبط خودکار وقتی Torque > 100 Nm
- Pause خودکار وقتی Torque < 100 Nm
- محاسبه عمق نصب
- ذخیره session ها در SQLite

### ✅ Debug Tools
- **Debug Scanner Page**: مشاهده همه دستگاه‌های BLE
- Raw manufacturer data viewer
- Permission checker
- Real-time console logs

---

## 🚀 نصب و راه‌اندازی

### 1️⃣ Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_blue_plus: ^1.32.12
  sqflite: ^2.3.0
  path_provider: ^2.1.1
  excel: ^4.0.3
  file_picker: ^6.1.1
  intl: ^0.19.0
```

### 2️⃣ Permissions

#### **Android** (`android/app/src/main/AndroidManifest.xml`):

```xml
<!-- Bluetooth -->
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />

<!-- Location (required for BLE scan) -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

<!-- Feature -->
<uses-feature android:name="android.hardware.bluetooth_le" android:required="true" />
```

**⚠️ مهم:** بدون این permission ها، Scan کار نمی‌کنه!

فایل کامل: `CORRECT_AndroidManifest.xml`

#### **iOS** (`ios/Runner/Info.plist`):

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth to connect to B24 devices</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>Location is required for Bluetooth scanning</string>
```

فایل کامل: `Info_plist_EXAMPLE.xml`

### 3️⃣ اجرا

```bash
# دریافت dependencies
flutter pub get

# اجرا
flutter run

# یا build برای release
flutter build apk
```

### 4️⃣ Login

کد اپراتور پیش‌فرض: **1234**

---

## 📝 نحوه استفاده

### **مرحله 1: Login**
- کد اپراتور: **1234**

### **مرحله 2: ایجاد پروژه جدید**
- Projects → **New Project**
- نام و موقعیت پروژه را وارد کنید

### **مرحله 3: تنظیم دستگاه‌ها (Manual Input)**

#### **VIEW PIN:**
- پیش‌فرض: `0000`
- اگه دستگاه VIEW PIN متفاوتی داره، تغییرش بده
- حداکثر 8 کاراکتر

#### **DATA TAG:**
- دکمه **"Add DATA TAG"** → Dialog باز میشه
- DATA TAG رو به فرمت HEX وارد کن (مثلا `4D80`)
- می‌تونی چندتا DATA TAG اضافه کنی

**💡 نکته:** برای پیدا کردن DATA TAG:
- از روی برچسب دستگاه
- یا از Debug Scanner (دکمه 🐛)

### **مرحله 4: Import شمع‌ها**
- دکمه **"Import from Excel"**
- فایل Excel شمع‌ها رو انتخاب کن

### **مرحله 5: ذخیره و شروع**
- Save Project
- انتخاب شمع از لیست
- Start Monitoring
- وقتی Torque > 100 → خودکار ضبط میشه ✅

**📖 راهنمای کامل:** `MANUAL_DATA_TAG_VIEWPIN.md`

---

## ❌ مشکلات رایج

### **مشکل 1: Scan دستگاه رو پیدا نمی‌کنه**

**راه‌حل سریع:**

1. برو صفحه Projects
2. بزن روی آیکون 🐛 (Debug)
3. دکمه **"Check Permissions"** رو بزن
4. اگه OK بود، دکمه **"Raw Scan"** رو بزن
5. log ها رو چک کن

**جزئیات کامل:** `HOW_TO_DEBUG_SCAN.md` 👈 **شروع از اینجا!**

---

### **مشکل 2: "Bluetooth is OFF"**

**راه‌حل:**
- Bluetooth گوشی رو روشن کن
- اگه روشنه، App رو بسته و دوباره باز کن

---

### **مشکل 3: "Permission denied"**

**Android:**
1. Settings → Apps → B24 Torque Monitor
2. Permissions → Location و Bluetooth رو ON کن
3. GPS گوشی رو روشن کن

**iOS:**
1. Settings → B24 Torque Monitor
2. Bluetooth و Location رو Allow کن

---

### **مشکل 4: دستگاه پیدا میشه ولی data نداره**

**علت:** دستگاه در حالت idle هست

**راه‌حل:**
- دکمه روی B24 رو بزن
- یک نیرو به سنسور وارد کن
- دستگاه رو restart کن

---

## 🐛 Debug

### **Debug Scanner Page**

برای دسترسی:
1. صفحه Projects → آیکون 🐛
2. یا از کد:
   ```dart
   Navigator.push(
     context,
     MaterialPageRoute(builder: (context) => DebugBluetoothPage()),
   );
   ```

### **ویژگی‌ها:**
- ✅ Raw Bluetooth Scan (همه دستگاه‌ها)
- ✅ B24 Monitor (فقط B24)
- ✅ Permission Checker
- ✅ Real-time Logs
- ✅ Manufacturer Data Viewer
- ✅ Signal Strength (RSSI)

### **نحوه استفاده:**

**برای دیدن همه دستگاه‌ها:**
1. Toggle "Show All Devices" → ON
2. دکمه "Raw Scan"
3. چک کردن log ها

**برای چک کردن Permission:**
1. دکمه "Check Permissions"
2. چک کردن output

**برای مانیتور B24:**
1. دکمه "B24 Monitor"
2. مشاهده torque data

---

## 📚 مستندات

### **راهنماهای اصلی:**
- `HOW_TO_DEBUG_SCAN.md` ⭐ **شروع از اینجا**
- `DEBUG_GUIDE_SCAN_TROUBLESHOOTING.md` - راهنمای کامل Debug
- `CHANGELOG.md` - تاریخچه تغییرات

### **مستندات فنی:**
- `B24_BLUETOOTH_GUIDE.md` - راهنمای Bluetooth B24
- `DATA_TAG_FILTERING.md` - سیستم فیلتر DATA TAG
- `BROADCAST_MODE_FIXED.md` - Broadcast Mode
- `SCAN_FIX_DISCOVERY_STREAM.md` - رفع مشکل Scan

### **Setup:**
- `BLUETOOTH_SETUP.md` - راه‌اندازی Bluetooth
- `CORRECT_AndroidManifest.xml` - فایل نمونه Android
- `Info_plist_EXAMPLE.xml` - فایل نمونه iOS

---

## 🏗️ ساختار پروژه

```
lib/
├── main.dart                    # Entry point
├── models/                      # Data models
│   ├── project.dart
│   ├── pile.dart
│   └── pile_session.dart
├── database/
│   └── database_helper.dart     # SQLite
├── services/
│   └── bluetooth_service.dart   # B24 Bluetooth
└── pages/
    ├── login_page.dart
    ├── home_page.dart
    ├── projects_page.dart       # دکمه 🐛 Debug اینجاست
    ├── add_project_page.dart
    ├── pile_list_page.dart
    ├── monitoring_page.dart
    ├── history_page.dart
    └── debug_bluetooth_page.dart ⭐ صفحه Debug
```

---

## 🔄 Workflow

```
1. Login (کد: 1234)
   ↓
2. Projects Page
   ↓
3. New Project
   ↓
4. Add Device DATA TAGs
   - Scan (اسکن خودکار)
   - Manual (وارد کردن دستی)
   ↓
5. Import Piles (Excel)
   ↓
6. Save Project
   ↓
7. Select Pile
   ↓
8. Start Monitoring
   ↓
9. Auto Recording (Torque > 100)
```

---

## 🧪 تست

### **تست Bluetooth:**
```dart
// در Debug Scanner:
1. "Check Permissions" → باید "ON and ready" باشه
2. "Raw Scan" → باید دستگاه‌ها رو ببینه
3. "B24 Monitor" → باید B24 رو detect کنه
```

### **تست با App های دیگه:**
- **nRF Connect** (Android/iOS)
- **BLE Scanner** (Android)
- **LightBlue** (iOS)

اگه این app ها B24 رو می‌بینن ولی app ما نمی‌بینه → مشکل از permission ها یا کد

---

## 📊 B24 Data Format

### **Legacy Format (Company ID 0x04C3):**

```
Byte 0:     Format ID (0x01)
Byte 1-2:   Data Tag (Little Endian)
Byte 3-12:  Encrypted Data (XOR)
```

**مثال:**
```
01 80 4D 5F 6A 7B 8C ...
│  └─┘  └─ Encrypted (Status, Units, Torque...)
│   └─ Data Tag = 0x4D80
└─ Format = 0x01
```

### **XOR Decryption:**
```dart
Default Seed: [0x5C, 0x6F, 0x2F, 0x41, 0x21, 0x7A, 0x26, 0x45, 0x5C, 0x6F]
View PIN: "0000" (default)

Key = Seed XOR PIN
Decrypted = Encrypted XOR Key
```

جزئیات: `B24_BLUETOOTH_GUIDE.md`

---

## ⚙️ تنظیمات

### **Threshold گشتاور:**
```dart
// در monitoring_page.dart
static const double RECORDING_THRESHOLD = 100.0; // Nm
```

### **View PIN:**
```dart
// در bluetooth_service.dart
B24BluetoothService.instance.setViewPin("0000");
```

### **Mock Data (برای تست):**
```dart
B24BluetoothService.instance.setMockDataEnabled(true);
```

---

## 🔐 امنیت

- ✅ داده‌ها فقط در دستگاه local ذخیره می‌شن (SQLite)
- ✅ هیچ ارتباطی با سرور نیست
- ✅ Bluetooth در Broadcast Mode (بدون اتصال)
- ⚠️ View PIN پیش‌فرض: "0000" (می‌تونی تغییر بدی)

---

## 🤝 مشارکت

برای گزارش مشکل یا پیشنهاد:
1. فایل `HOW_TO_DEBUG_SCAN.md` رو بخون
2. Debug Scanner رو امتحان کن
3. Log ها رو بفرست
4. اطلاعات گوشی (مدل، OS) رو بنویس

---

## 📄 License

این پروژه برای استفاده داخلی طراحی شده.

---

## 🙏 Credits

- **Flutter Blue Plus** - Bluetooth BLE
- **SQFlite** - Local Database
- **Excel** - File Import
- **B24 Torque Wrench** - Mantracourt

---

## 📞 پشتیبانی

مشکلی داری؟

1. **اول:** `HOW_TO_DEBUG_SCAN.md` رو بخون
2. **دوم:** Debug Scanner رو امتحان کن
3. **سوم:** با log ها و screenshot تماس بگیر

---

**نسخه:** v1.3.0  
**آخرین بروزرسانی:** 2024-12-07  
**وضعیت:** ✅ Production Ready - Manual DATA TAG & VIEW PIN Input