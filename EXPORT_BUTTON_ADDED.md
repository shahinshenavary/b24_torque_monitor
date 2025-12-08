# ✅ دکمه Export اضافه شد!

## 📍 مکان دکمه Export

دکمه Export در **صفحه Projects** کنار هر پروژه قرار دارد:

```
┌─────────────────────────────────────────┐
│  📁 Tehran Metro Line 7                 │
│  📍 Azadi Square, Tehran                │
│  📅 2024/12/07 14:30                   │
│                                         │
│                      [12 piles] 🟢      │
│                      [🗑️ Delete]        │
│                      [📥 Export] ✅      │  ← دکمه جدید!
└─────────────────────────────────────────┘
```

## 🎨 طراحی دکمه

- **آیکون**: 📥 `Icons.file_download`
- **رنگ**: سبز (#10B981) - همرنگ با badge "piles"
- **مکان**: زیر دکمه Delete، در ستون سمت راست

## 🔧 تغییرات انجام شده

### 1️⃣ فایل‌های ایجاد شده:

```
✅ /aaa/lib/services/excel_export_service.dart
   → سرویس اصلی Export به Excel
   
✅ /aaa/EXPORT_FEATURE.md
   → راهنمای کامل استفاده از قابلیت Export
   
✅ /aaa/EXPORT_BUTTON_ADDED.md
   → این فایل (توضیحات دکمه)
```

### 2️⃣ فایل‌های ویرایش شده:

```
✅ /aaa/lib/pages/projects_page.dart
   → اضافه شدن:
     - import ExcelExportService
     - تابع _exportProject()
     - دکمه Export در UI
     
✅ /aaa/pubspec.yaml
   → اضافه شدن:
     - permission_handler: ^11.3.1
     
✅ /aaa/CORRECT_AndroidManifest.xml
   → اضافه شدن Storage Permissions:
     - READ_EXTERNAL_STORAGE
     - WRITE_EXTERNAL_STORAGE
     - MANAGE_EXTERNAL_STORAGE
     - READ_MEDIA_* (Android 13+)
```

## 🚀 نحوه استفاده

### کاربر:

1. وارد صفحه **Projects** شوید
2. دکمه **سبز Export** (📥) کنار پروژه مورد نظر را بزنید
3. Loading dialog نمایش داده می‌شود
4. فایل Excel ذخیره می‌شود
5. دیالوگ موفقیت با مسیر فایل نمایش داده می‌شود

### خروجی:

```
📁 /storage/emulated/0/Download/B24_Reports/
   └─ Tehran_Metro_Line_7_20241207_1430.xlsx
```

## 📊 محتوای فایل Excel

### Sheet 1: Project Info
- نام پروژه
- موقعیت
- تاریخ ایجاد
- آمار شمع‌ها (Completed, In Progress, Pending)
- تنظیمات دستگاه (VIEW PIN, DATA TAGs)

### Sheet 2: Piles Summary ⭐
- Pile ID
- Pile Number
- Type
- Expected Torque
- **Max Torque** ← محاسبه شده!
- Expected Depth
- **Final Depth** ← از دیتابیس!
- Status (با رنگ‌بندی)
- Measurements Count

### Sheet 3: Detailed Measurements
- تمام داده‌های Torque, Depth, Force, Mass
- Timestamp کامل
- آماده برای ساخت نمودار در Excel

## ⚠️ نکات مهم

### Storage Permission

اولین بار که Export می‌کنید، اندروید Permission می‌خواهد:

```
┌─────────────────────────────────────┐
│  Allow B24 Torque Monitor to       │
│  access photos, media, and files   │
│  on your device?                   │
│                                     │
│  [Deny]  [Allow]                   │
└─────────────────────────────────────┘
```

**حتماً Allow بزنید!**

### مکان فایل

فایل‌ها در **Download > B24_Reports** ذخیره می‌شوند:

1. File Manager رو باز کنید
2. به **Download** بروید
3. پوشه **B24_Reports** رو باز کنید
4. فایل Excel رو پیدا می‌کنید

### اشتراک‌گذاری

فایل رو می‌تونید از طریق:
- 📧 Email
- 💬 Telegram / WhatsApp
- ☁️ Google Drive
- 💾 USB (به کامپیوتر وصل کنید)

به اشتراک بگذارید.

## 🎯 Use Cases

### 1. گزارش روزانه
هر روز پایان کار، Export کنید و به مدیر پروژه ایمیل بزنید

### 2. Backup
هر هفته Export کنید و در Google Drive ذخیره کنید

### 3. تحلیل
فایل رو در Excel باز کنید و نمودار Torque رسم کنید

### 4. مستندسازی
فایل Excel به عنوان مستندات رسمی پروژه

## 🐛 عیب‌یابی

### ❌ Export کار نمی‌کند

**راه‌حل:**
1. Settings > Apps > B24 Torque Monitor > Permissions
2. Storage را **Allow** کنید
3. دوباره تلاش کنید

### ❌ فایل پیدا نمی‌شود

**راه‌حل:**
1. File Manager باز کنید (نه Gallery!)
2. Download > B24_Reports
3. فایل را با نام پروژه جستجو کنید

### ❌ Excel خطا می‌دهد

**راه‌حل:**
1. فایل را با Microsoft Excel یا Google Sheets باز کنید
2. مطمئن شوید فایل کامل دانلود شده
3. اگر Corrupted بود، دوباره Export کنید

## 💡 نکات برنامه‌نویسی

### API های استفاده شده:

```dart
// Excel package
import 'package:excel/excel.dart';

// Permissions
import 'package:permission_handler/permission_handler.dart';

// File operations
import 'package:path_provider/path_provider.dart';
import 'dart:io';
```

### Flow اصلی:

```
User clicks Export
    ↓
Request Storage Permission
    ↓
Create Excel workbook
    ↓
Add 3 sheets (Info, Summary, Measurements)
    ↓
Calculate Max Torque for each pile
    ↓
Save to /Download/B24_Reports/
    ↓
Show success dialog with file path
```

### Max Torque Calculation:

```dart
double maxTorque = 0;
if (measurements.isNotEmpty) {
  maxTorque = measurements
    .map((m) => m.torque.abs())
    .reduce((a, b) => a > b ? a : b);
}
```

### File Naming:

```dart
ProjectName_YYYYMMDD_HHMM.xlsx

مثال:
Tehran_Metro_Line_7_20241207_1430.xlsx
```

## ✨ ویژگی‌های حرفه‌ای

✅ **Styling**: Header آبی، Status رنگی  
✅ **Max Torque**: محاسبه خودکار  
✅ **Final Depth**: از دیتابیس  
✅ **3 Sheets**: Info + Summary + Details  
✅ **Timestamp**: در نام فایل  
✅ **Permission**: مدیریت خودکار  
✅ **Error Handling**: دیالوگ‌های خطا  
✅ **Loading**: نمایش پیشرفت  

## 🎉 نتیجه

دکمه Export با موفقیت اضافه شد و کاربر می‌تونه:
- ✅ گزارش کامل پروژه رو Export کنه
- ✅ Max Torque و Final Depth ببینه
- ✅ نمودار در Excel بسازه
- ✅ فایل رو به اشتراک بگذاره
- ✅ Backup داشته باشه

---

**نسخه**: 1.1.0  
**تاریخ**: 2024/12/07  
**توسعه‌دهنده**: B24 Torque Monitor Team
