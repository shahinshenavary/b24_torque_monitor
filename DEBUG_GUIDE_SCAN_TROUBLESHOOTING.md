# 🐛 راهنمای Debug و رفع مشکل Scan

## مشکل: دستگاه B24 پیدا نمی‌شه

اگه هنوز هم Scan دستگاه رو پیدا نمی‌کنه، از این راهنما استفاده کن:

---

## ✅ مرحله 1: Check Permissions

### Android (`android/app/src/main/AndroidManifest.xml`):

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    
    <!-- ✅ Bluetooth Permissions (REQUIRED) -->
    <uses-permission android:name="android.permission.BLUETOOTH" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" 
                     android:usesPermissionFlags="neverForLocation" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
    
    <!-- ✅ Location Permissions (REQUIRED for BLE scan on Android) -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    
    <!-- ✅ Feature Declaration -->
    <uses-feature android:name="android.hardware.bluetooth_le" android:required="true" />
    
    <application ...>
        ...
    </application>
</manifest>
```

### iOS (`ios/Runner/Info.plist`):

```xml
<dict>
    ...
    
    <!-- ✅ Bluetooth Usage Description -->
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>This app needs Bluetooth to connect to B24 torque monitoring devices</string>
    
    <key>NSBluetoothPeripheralUsageDescription</key>
    <string>This app needs Bluetooth to monitor torque data from B24 devices</string>
    
    <!-- ✅ Location Usage (for BLE scan) -->
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>Location is required for Bluetooth scanning on iOS</string>
    
    ...
</dict>
```

---

## ✅ مرحله 2: Runtime Permissions

در کد اصلی، باید permission بگیری:

```dart
// افزودن به pubspec.yaml:
dependencies:
  permission_handler: ^11.0.0

// کد برای گرفتن permission:
import 'package:permission_handler/permission_handler.dart';

Future<void> requestPermissions() async {
  if (Platform.isAndroid) {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }
}
```

**⚠️ CRITICAL:** بدون این permission ها، هیچ دستگاهی پیدا نمی‌شه!

---

## ✅ مرحله 3: استفاده از Debug Scanner

1. برو به صفحه **Projects**
2. آیکون 🐛 (bug) رو بزن در گوشه بالا
3. صفحه **Debug Scanner** باز میشه

### گزینه‌های Debug:

#### **A) Raw Scan (توصیه میشه)**
- همه دستگاه‌های Bluetooth اطراف رو نشون میده
- می‌تونی ببینی آیا گوشی اصلا Bluetooth scan می‌کنه یا نه

**نحوه استفاده:**
1. Toggle رو روی "Show All Devices" بذار
2. دکمه "Raw Scan" رو بزن
3. منتظر بمون 10-30 ثانیه
4. باید log هایی مثل این ببینی:

```
[12:34:56] 🔍 Starting RAW Bluetooth Scan...
[12:34:56] 📡 Mode: ALL DEVICES
[12:34:56] 📶 Bluetooth State: BluetoothAdapterState.on
[12:34:56] ✅ Starting scan with continuousUpdates...
[12:34:56] ✅ Scan started - waiting for devices...
[12:34:57] 📡 Scan tick: 5 devices found
[12:34:57] 📱 Device: iPhone (ID: 12345678...) RSSI: -45 dBm [#1]
[12:34:57]    ⚠️ No manufacturer data
[12:34:58] 📱 Device: B24-4D80 (ID: 87654321...) RSSI: -65 dBm [#1]
[12:34:58]    📦 Mfg Data [0x04c3]: 01 80 4D 5F ... (14 bytes)
[12:34:58]    🎯 B24 PATTERN FOUND at byte 1: 4D 80
[12:34:58]    🏷️ Legacy Format: DATA TAG = 19840 (0x4D80)
```

#### **B) B24 Monitor**
- استفاده از `BluetoothService` برای scan
- فقط دستگاه‌های B24 رو نشون میده

#### **C) Check Permissions**
- چک می‌کنه که Bluetooth روشن باشه
- چک می‌کنه که permission ها داده شده باشن

---

## 🔍 تحلیل Log ها

### ✅ خوب - همه چیز OK:
```
📡 Scan tick: 3 devices found
📱 Device: B24-4D80 (ID: ...) RSSI: -65 dBm
   📦 Mfg Data [0x04c3]: 01 80 4D ...
   🎯 B24 PATTERN FOUND at byte 1: 4D 80
   🏷️ Legacy Format: DATA TAG = 19840 (0x4D80)
🎯 Discovery: B24-4D80 - TAG: 0x4D80 (RSSI: -65)
```

### ⚠️ هشدار - دستگاه پیدا میشه ولی data نداره:
```
📱 Device: B24-4D80 (ID: ...) RSSI: -65 dBm
   ⚠️ No manufacturer data
```
**راه حل:** دستگاه رو **restart** کن یا یک دکمه روش فشار بده تا شروع به broadcast کنه.

### ❌ خطا - هیچ دستگاهی پیدا نمیشه:
```
📡 Scan tick: 0 devices found
```

**احتمالات:**
1. **Bluetooth خاموشه:** `Check Permissions` رو بزن
2. **Permission نداده شده:** Settings گوشی → Apps → B24 Torque → Permissions → Bluetooth & Location رو ON کن
3. **دستگاه خاموشه:** B24 رو روشن کن
4. **دور از گوشی:** نزدیک‌تر بیا (حداقل < 5 متر)

### ❌ خطا - Bluetooth خاموشه:
```
❌ Bluetooth is OFF - Please turn it on
```
**راه حل:** Bluetooth گوشی رو روشن کن.

---

## 🛠️ رفع مشکلات رایج

### مشکل 1: هیچ log ای نمی‌بینم
**علت:** Console log ها disable هستن  
**راه حل:** توی VS Code یا Android Studio، Debug Console رو چک کن

### مشکل 2: "Bluetooth not supported"
**علت:** دستگاه شما BLE ندارد  
**راه حل:** از گوشی یا تبلت دیگه‌ای استفاده کن که BLE داشته باشه

### مشکل 3: Scan شروع میشه ولی هیچ device ای نمیاد
**علت:** Permission ها درست داده نشدن  
**چک لیست:**
- ✅ AndroidManifest.xml یا Info.plist رو check کن
- ✅ Settings گوشی → Permissions → Bluetooth & Location
- ✅ GPS روشن باشه (Android)
- ✅ App رو uninstall/reinstall کن (اگه manifest تغییر کرده)

### مشکل 4: دستگاه B24 پیدا میشه ولی manufacturer data نداره
**علت:** دستگاه در حالت idle هست و broadcast نمی‌کنه  
**راه حل:**
- دکمه روی B24 رو فشار بده
- یک نیرو به سنسور وارد کن
- دستگاه رو restart کن

### مشکل 5: DATA TAG نشون داده نمیشه
**علت:** فرمت advertising packet متفاوته  
**راه حل:**
- Log ها رو بفرست برای بررسی
- `Mfg Data` رو check کن ببین byte اول `01` هست یا نه

---

## 📊 فرمت‌های Advertising Packet

### Legacy Format (0x04C3 Company ID):
```
Byte 0:    Format ID (0x01)
Byte 1-2:  Data Tag (Little Endian)
Byte 3+:   Encrypted Data (XOR)
```

مثال:
```
01 80 4D 5F 6A 7B ...
└─ Format ID = 0x01
   └─ Data Tag = 0x4D80 (19840 decimal)
      └─ Encrypted bytes...
```

### Modern Format (Alternative):
```
... 4D 80 [6 encrypted bytes] ...
    └─ Pattern (Tag Head + Tail)
       └─ 6 bytes data
```

---

## 🧪 تست موارد

### ✅ تست 1: آیا Bluetooth کار می‌کنه؟
1. برو Settings گوشی
2. Bluetooth رو روشن کن
3. ببین دستگاه‌های دیگه (هدفون، ساعت) رو پیدا می‌کنه؟

اگه **بله** → Bluetooth سالمه، مشکل از app یا permission  
اگه **خیر** → مشکل سخت‌افزاری گوشی

### ✅ تست 2: آیا App permission داره؟
1. دکمه "Check Permissions" در Debug Scanner
2. باید ببینی: `Adapter State: BluetoothAdapterState.on`

اگه **بله** → Permission OK  
اگه **خیر** → برو Settings → Permissions

### ✅ تست 3: آیا دستگاه broadcast می‌کنه؟
1. از app دیگه‌ای مثل **nRF Connect** (Android/iOS) استفاده کن
2. Scan کن
3. ببین B24 رو پیدا می‌کنه؟

اگه **بله** → دستگاه سالمه، مشکل از app  
اگه **خیر** → دستگاه خاموشه یا مشکل داره

---

## 📱 Apps مفید برای Debug

### Android:
- **nRF Connect** (Nordic Semiconductor)
- **BLE Scanner** (Bluepixel Technologies)

### iOS:
- **nRF Connect** (Nordic Semiconductor)
- **LightBlue** (Punch Through)

این app ها رو نصب کن و ببین B24 رو پیدا می‌کنن یا نه. اگه پیدا کردن، یعنی مشکل از app Flutter ماست.

---

## 📤 گزارش مشکل

اگه هنوز حل نشد، این اطلاعات رو بده:

1. **Screenshot از Debug Scanner** (با log ها)
2. **نوع گوشی و Android/iOS version**
3. **آیا با app دیگه (مثل nRF Connect) دستگاه رو می‌بینی؟**
4. **Output دکمه "Check Permissions"**
5. **AndroidManifest.xml** (خطوط permissions)

---

## 🎯 خلاصه چک‌لیست سریع

- [ ] Bluetooth روشن هست؟
- [ ] GPS/Location روشن هست? (Android)
- [ ] Permission ها داده شدن؟ (Settings → App → Permissions)
- [ ] AndroidManifest.xml permission های لازم رو داره؟
- [ ] دستگاه B24 روشنه؟
- [ ] دستگاه B24 نزدیکه؟ (< 5 متر)
- [ ] با Debug Scanner تست کردی؟
- [ ] با "Raw Scan" + "Show All Devices" امتحان کردی؟
- [ ] با app دیگه (nRF Connect) تست کردی؟
- [ ] App رو reinstall کردی؟

اگه همه اینا OK بود ولی هنوز کار نمی‌کنه، Log ها رو بفرست! 📊
