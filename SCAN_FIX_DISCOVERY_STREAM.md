# 🔧 Fix: Bluetooth Scan Not Discovering Devices

## مشکل قبلی ❌

وقتی در صفحه **Add Project** دکمه **Scan** زده می‌شد، هیچ دستگاهی پیدا نمی‌شد، ولی دکمه **Manual** کار می‌کرد.

### علت مشکل:

1. `_DeviceScanDialog` منتظر پیغام‌های خاصی از `debugStream` بود
2. این پیغام‌ها باید فرمت `"Data Tag: xxx (0x...)"` داشتند
3. ولی `bluetooth_service.dart` این فرمت رو emit نمی‌کرد
4. در نتیجه dialog هیچ دستگاهی نشون نمی‌داد

---

## راه‌حل ✅

### 1️⃣ **اضافه کردن `discoveryStream` جدید**

یک **Stream مخصوص Device Discovery** اضافه شد:

```dart
// bluetooth_service.dart

class DeviceDiscoveryInfo {
  final int dataTag;
  final String deviceName;
  final int rssi;
  final int timestamp;
}

class B24BluetoothService {
  // 🆕 Stream جدید برای Device Discovery
  final StreamController<DeviceDiscoveryInfo> _discoveryController = 
      StreamController<DeviceDiscoveryInfo>.broadcast();
  
  Stream<DeviceDiscoveryInfo> get discoveryStream => _discoveryController.stream;
}
```

---

### 2️⃣ **Emit کردن Event هنگام پیدا کردن دستگاه**

در تابع `_parseLegacyFormat`، وقتی DATA TAG شناسایی می‌شه، یک event emit می‌شه:

```dart
void _parseLegacyFormat(List<int> data, {String deviceName = 'Unknown', int rssi = 0}) {
  // ... parse data tag
  
  final dataTag = (data[2] << 8) | data[1];
  
  // 🆕 Emit device discovery event (فقط یکبار برای هر دستگاه)
  if (_isScanning && !_discoveredDataTags.contains(dataTag)) {
    _discoveredDataTags.add(dataTag);
    _discoveryController.add(DeviceDiscoveryInfo(
      dataTag: dataTag,
      deviceName: deviceName,
      rssi: rssi,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
    print("   📢 Device discovery event emitted: DATA TAG 0x$hexString");
  }
}
```

---

### 3️⃣ **آپدیت کردن Dialog برای استفاده از Stream جدید**

```dart
class _DeviceScanDialogState extends State<_DeviceScanDialog> {
  final Map<int, DeviceDiscoveryInfo> _discoveredDevices = {};
  late final StreamSubscription<DeviceDiscoveryInfo> _discoverySubscription;

  void _startListeningForDevices() {
    // 🆕 Listen to discoveryStream به جای debugStream
    _discoverySubscription = B24BluetoothService.instance.discoveryStream.listen((discoveryInfo) {
      if (!_discoveredDevices.containsKey(discoveryInfo.dataTag)) {
        if (mounted) {
          setState(() {
            _discoveredDevices[discoveryInfo.dataTag] = discoveryInfo;
          });
        }
      }
    });
  }
}
```

---

### 4️⃣ **نمایش اطلاعات بیشتر در UI**

```dart
ListTile(
  leading: const Icon(Icons.bluetooth, color: Colors.blue),
  title: Text(info.deviceName),  // نام دستگاه (مثلا B24-...)
  subtitle: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('DATA TAG: 0x$hexString ($dataTag)'),
      Text('Signal: ${info.rssi} dBm'),  // قدرت سیگنال
    ],
  ),
)
```

---

## تغییرات اصلی 📝

### فایل `bluetooth_service.dart`:

1. ✅ اضافه شدن کلاس `DeviceDiscoveryInfo`
2. ✅ اضافه شدن `_discoveryController` و `discoveryStream`
3. ✅ اضافه شدن `_discoveredDataTags` برای جلوگیری از duplicate
4. ✅ افزودن پارامترهای `deviceName` و `rssi` به `_parseAdvertisingData` و `_parseLegacyFormat`
5. ✅ Emit کردن `DeviceDiscoveryInfo` هنگام پیدا کردن DATA TAG
6. ✅ پاک کردن `_discoveredDataTags` در `stopBroadcastMonitoring()`
7. ✅ Close کردن `_discoveryController` در `dispose()`

### فایل `add_project_page.dart`:

1. ✅ تغییر `_discoveredDevices` از `Map<int, String>` به `Map<int, DeviceDiscoveryInfo>`
2. ✅ حذف `_dataTagPattern` regex (دیگه لازم نیست)
3. ✅ تغییر subscription از `debugStream` به `discoveryStream`
4. ✅ نمایش اطلاعات بیشتر (نام دستگاه، DATA TAG، قدرت سیگنال)
5. ✅ بهبود UI و پیغام‌های راهنما

---

## نحوه استفاده 🚀

### برای Scan کردن دستگاه‌ها:

1. باز کردن صفحه **Add Project**
2. زدن دکمه **Scan** در قسمت Devices
3. منتظر ماندن تا دستگاه‌های B24 پیدا شوند
4. Tap کردن روی دستگاه مورد نظر برای اضافه کردن

### نکات مهم:

- ✅ دستگاه B24 باید **روشن** باشه
- ✅ دستگاه باید در حال **broadcast** باشه (داده ارسال کنه)
- ✅ Bluetooth گوشی باید **فعال** باشه
- ✅ Permission های Bluetooth و Location باید **داده شده** باشن

---

## Log های مفید 📊

وقتی Scan می‌کنی، این log ها رو باید ببینی:

```
🔍 Starting B24 Broadcast Monitoring (View Mode)...
📡 Scan Results: 2 devices found
   Device: B24-4D80 (RSSI: -65)
   ✅ B24 Device Found: B24-4D80
   📦 Manufacturer Data Keys: [1219]
   📦 Raw Manufacturer Data (0x04C3): 01 80 4D ...
   Data Tag: 19840 (0x4D80)
   📢 Device discovery event emitted: DATA TAG 0x4D80
📱 UI: Device added to list - DATA TAG: 0x4D80
```

---

## مقایسه قبل و بعد

### ❌ قبل:
- Dialog باز می‌شد ولی خالی بود
- پیغام "Searching for devices..." همیشه نمایش داده می‌شد
- هیچ دستگاهی پیدا نمی‌شد

### ✅ بعد:
- دستگاه‌ها به محض پیدا شدن نمایش داده می‌شن
- اطلاعات کامل (نام، DATA TAG، سیگنال) نشون داده می‌شه
- می‌تونی روی دستگاه Tap کنی و اضافه کنی

---

## چک‌لیست تست ✓

- [ ] دکمه Scan کار می‌کنه
- [ ] دستگاه‌های B24 پیدا می‌شن
- [ ] اطلاعات دستگاه‌ها نمایش داده می‌شه
- [ ] Tap کردن روی دستگاه کار می‌کنه
- [ ] دستگاه به لیست اضافه می‌شه
- [ ] دکمه Close کار می‌کنه
- [ ] دکمه Manual هنوز کار می‌کنه

---

## فایل‌های تغییر یافته

```
/aaa/lib/services/bluetooth_service.dart  ← اضافه شدن discoveryStream
/aaa/lib/pages/add_project_page.dart      ← آپدیت شدن _DeviceScanDialog
```

---

**تاریخ:** 2024-12-07  
**نسخه:** v1.1.0 - Discovery Stream Fix
