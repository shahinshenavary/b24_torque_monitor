# Changelog - B24 Torque Monitor

همه تغییرات مهم این پروژه در این فایل مستند می‌شود.

---

## [v1.3.0] - 2024-12-07

### 🔄 Changed - BREAKING CHANGE
- **حذف قابلیت Scan**: دکمه Scan در Add Project حذف شد
- **ورودی دستی DATA TAG و VIEW PIN**: در زمان ایجاد پروژه، کاربر باید DATA TAG و VIEW PIN رو وارد کنه

### 🆕 Added
- **فیلد VIEW PIN**: در صفحه Add Project
  - پیش‌فرض: `0000`
  - حداکثر 8 کاراکتر
  - استفاده برای XOR Decryption
  
- **ورودی دستی DATA TAG**:
  - Dialog برای وارد کردن DATA TAG به صورت HEX
  - Validation: فقط 0-9 و A-F، حداکثر 4 کاراکتر
  - امکان اضافه کردن چندین DATA TAG
  - نمایش DATA TAG ها با فرمت HEX و Decimal

### 🔧 Changed
- `models/project.dart`:
  - اضافه شدن فیلد `viewPin`
  - پیش‌فرض VIEW PIN: `"0000"`

- `database/database_helper.dart`:
  - Migration به version 5
  - اضافه شدن ستون `viewPin` به جدول `projects`

- `pages/add_project_page.dart`:
  - حذف کامل `_DeviceScanDialog`
  - حذف دکمه Scan
  - اضافه شدن `TextFormField` برای VIEW PIN
  - اضافه شدن `_addDataTag()` برای ورودی دستی
  - UI بهبود یافته با Card ها
  - Input validation

- `pages/monitoring_page.dart`:
  - استفاده از `project.viewPin` برای set کردن VIEW PIN
  - Log VIEW PIN در console

### 📝 Documentation
- اضافه شدن `MANUAL_DATA_TAG_VIEWPIN.md` با راهنمای کامل

### ⚠️ Migration Notes
- پروژه‌های قدیمی VIEW PIN پیش‌فرض `"0000"` می‌گیرن
- Database version از 4 به 5 ارتقا می‌یابه

---

## [v1.2.0] - 2024-12-07

### 🆕 Added
- **Debug Bluetooth Scanner Page**: صفحه Debug کامل برای تشخیص مشکلات Scan
  - Raw Scan Mode: نمایش همه دستگاه‌های BLE اطراف
  - Show All Devices toggle: فیلتر کردن فقط B24 یا نمایش همه
  - Real-time Manufacturer Data viewer
  - B24 Pattern Detection (4D 80)
  - DATA TAG decoder
  - Permission checker
  - Detailed console logs with color coding
  - RSSI (signal strength) display
  
- **Debug Button در Projects Page**: دکمه 🐛 برای دسترسی سریع به Debug Scanner

### 📝 Documentation
- اضافه شدن `DEBUG_GUIDE_SCAN_TROUBLESHOOTING.md` با راهنمای کامل رفع مشکل

### 🔧 Purpose
این نسخه برای **تشخیص مشکل Scan** طراحی شده. اگه دستگاه B24 پیدا نمیشه:
1. برو Projects Page → زدن دکمه 🐛
2. "Raw Scan" رو بزن
3. log ها رو چک کن
4. بفهم مشکل از کجاست (permission, bluetooth, device, distance)

---

## [v1.1.0] - 2024-12-07

### 🐛 Fixed
- **مشکل Scan دستگاه‌ها حل شد**: وقتی دکمه Scan در Add Project زده می‌شد، هیچ دستگاهی پیدا نمی‌شد
  - اضافه شدن `DeviceDiscoveryInfo` class
  - اضافه شدن `discoveryStream` مخصوص Device Discovery
  - آپدیت شدن `_DeviceScanDialog` برای استفاده از stream جدید
  - نمایش اطلاعات بیشتر (نام دستگاه، DATA TAG، قدرت سیگنال)

### 🔧 Changed
- `bluetooth_service.dart`:
  - افزودن `DeviceDiscoveryInfo` class
  - افزودن `_discoveryController` و `discoveryStream`
  - افزودن `_discoveredDataTags` set برای جلوگیری از duplicate
  - emit کردن discovery event در `_parseLegacyFormat`
  
- `add_project_page.dart`:
  - تغییر `_DeviceScanDialog` برای استفاده از `discoveryStream`
  - نمایش RSSI (قدرت سیگنال) در لیست دستگاه‌ها
  - بهبود UI و پیغام‌های راهنما

### 📝 Documentation
- اضافه شدن `SCAN_FIX_DISCOVERY_STREAM.md` با توضیحات کامل

---

## [v1.0.0] - 2024-12-05

### ✅ Added
- **DATA TAG Filtering System**: فیلتر کردن دستگاه‌ها بر اساس DATA TAG های تعریف شده در پروژه
  - افزودن فیلد `deviceDataTags` به مدل Project
  - آپدیت Database به version 4
  - پشتیبانی از Legacy Format (Format ID 0x01)
  - UI برای اضافه کردن DATA TAG ها (Manual + Scan)
  - فیلتر خودکار در صفحه Monitoring

### 🔧 Changed
- `bluetooth_service.dart`:
  - حذف فرمت 2 (فقط Legacy Format پشتیبانی می‌شود)
  - اضافه شدن `setAllowedDataTags()` و `clearDataTagFilter()`
  - فیلتر کردن خودکار advertising packets

- `database_helper.dart`:
  - Migration به version 4
  - اضافه شدن ستون `device_data_tags` به جدول projects

### 📝 Documentation
- `DATA_TAG_FILTERING.md` - مستندات کامل سیستم فیلتر
- `IMPLEMENTATION_SUMMARY.md` - خلاصه پیاده‌سازی

---

## [v0.9.0] - 2024-12-03

### ✅ Added
- **Broadcast Mode Monitoring**: دریافت داده از advertising packets بدون نیاز به اتصال
  - استفاده از `continuousUpdates: true` در FlutterBluePlus
  - پشتیبانی از چند فرمت (Legacy و Format 2)
  - XOR Decryption با Default Seed و View PIN

### 🔧 Changed
- تغییر از Connection Mode به Broadcast Mode
- پشتیبانی از چند دستگاه همزمان
- بهبود performance و کاهش مصرف باتری

### 📝 Documentation
- `BROADCAST_MODE_FIXED.md` - توضیح Broadcast Mode
- `B24_BLUETOOTH_GUIDE.md` - راهنمای کامل Bluetooth

---

## [v0.8.0] - 2024-12-01

### ✅ Added
- **Auto Recording System**: ضبط خودکار داده‌ها وقتی گشتاور > 100 Nm
  - Session Management
  - Automatic pause/resume
  - Depth calculation

### 🔧 Changed
- بهبود Monitoring Page UI
- اضافه شدن Recording Status Indicator
- نمایش تعداد رکوردهای ذخیره شده

---

## [v0.7.0] - 2024-11-28

### ✅ Added
- **Project Management**: ایجاد، ویرایش، حذف پروژه‌ها
- **Excel Import**: import کردن اطلاعات شمع‌ها از فایل Excel
- **Pile Management**: مدیریت شمع‌های هر پروژه

### 📝 Database
- اضافه شدن جداول projects، piles، pile_sessions، measurements
- SQLite database با version 1

---

## [v0.5.0] - 2024-11-25

### ✅ Added
- **Login Page**: ورود با کد اپراتور ثابت (1234)
- **Bluetooth Service**: اتصال اولیه به دستگاه B24
- **Basic UI**: صفحات اصلی اپلیکیشن

### 🔧 Setup
- Flutter project initialization
- Dependencies: flutter_blue_plus, sqflite, excel, file_picker

---

## تعاریف

- **Added**: ویژگی‌های جدید
- **Changed**: تغییرات در ویژگی‌های موجود
- **Fixed**: رفع مشکلات و باگ‌ها
- **Removed**: حذف ویژگی‌ها
- **Security**: اصلاحات امنیتی
- **Documentation**: تغییرات در مستندات

---

## نکات نسخه‌گذاری

این پروژه از [Semantic Versioning](https://semver.org/) استفاده می‌کند:
- **MAJOR** (x.0.0): تغییرات ناسازگار با نسخه قبل
- **MINOR** (0.x.0): افزودن ویژگی جدید به صورت سازگار
- **PATCH** (0.0.x): رفع باگ به صورت سازگار