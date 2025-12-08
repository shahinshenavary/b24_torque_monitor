# 🔧 حل مشکل Storage Permission برای Export

## ⚠️ مشکل قبلی

```
Export Failed
Failed to export project: Exception: Export failed: Exception: Storage permission denied
Please make sure storage permission is granted
```

## ✅ راه‌حل پیاده‌سازی شده

### 1️⃣ تغییر روش ذخیره‌سازی

به جای استفاده از **Public Downloads** که به Permission نیاز دارد، حالا از **App-Specific External Storage** استفاده می‌کنیم:

```
قبلاً:
/storage/emulated/0/Download/B24_Reports/  ← نیاز به Permission ✗

حالا:
/storage/emulated/0/Android/data/[app]/files/B24_Reports/  ← بدون Permission ✓
```

### 2️⃣ مزایای روش جدید

✅ **بدون نیاز به Permission**: اندروید 11+ اجازه می‌ده بدون permission فایل ذخیره کنیم  
✅ **قابل دسترسی**: فایل از طریق File Manager قابل دسترسی است  
✅ **کار می‌کنه در همه ورژن‌های اندروید**: Android 6 تا 14+  
✅ **امن**: فایل‌ها در مسیر مخصوص اپ ذخیره می‌شن  

### 3️⃣ نحوه دسترسی به فایل

#### روش 1: File Manager (توصیه می‌شود)

1. **File Manager** یا **My Files** رو باز کنید
2. به **Internal Storage** بروید
3. **Android** > **data** > **com.example.b24_torque_monitor** > **files** > **B24_Reports**
4. فایل Excel رو پیدا می‌کنید

#### روش 2: جستجو

1. File Manager رو باز کنید
2. از قسمت Search، نام پروژه رو جستجو کنید
3. فایل `.xlsx` پیدا میشه

#### روش 3: USB به کامپیوتر

1. گوشی رو با USB به کامپیوتر وصل کنید
2. **File Transfer** (MTP) رو انتخاب کنید
3. مسیر بالا رو در کامپیوتر باز کنید
4. فایل رو کپی کنید

### 4️⃣ اشتراک‌گذاری فایل

فایل رو می‌تونید از File Manager به اشتراک بگذارید:

1. فایل رو در File Manager پیدا کنید
2. Long Press روی فایل
3. گزینه **Share** یا **Send** رو بزنید
4. روش ارسال رو انتخاب کنید:
   - 📧 Gmail
   - 💬 Telegram
   - 💬 WhatsApp
   - ☁️ Google Drive
   - 📤 Bluetooth

## 🔧 تغییرات فنی

### کد قبلی (با مشکل):

```dart
// نیاز به Permission داشت
final status = await Permission.storage.request();
if (!status.isGranted) {
  throw Exception('Storage permission denied');
}

directory = Directory('/storage/emulated/0/Download');
```

### کد جدید (بدون مشکل):

```dart
// Permission اختیاری - اگر نداد، از app-specific استفاده می‌کنیم
await _requestStoragePermission(); // سعی می‌کنه بگیره، اما الزامی نیست

// استفاده از app-specific external storage
final externalDir = await getExternalStorageDirectory();
directory = Directory('${externalDir.path}/B24_Reports');
```

### تابع جدید `_requestStoragePermission()`:

```dart
Future<void> _requestStoragePermission() async {
  bool granted = false;

  // Try storage permission (Android 10-)
  var status = await Permission.storage.status;
  if (status.isGranted) {
    granted = true;
  } else if (status.isDenied) {
    status = await Permission.storage.request();
    if (status.isGranted) granted = true;
  }

  // Try manageExternalStorage (Android 11+)
  if (!granted) {
    var manageStatus = await Permission.manageExternalStorage.status;
    if (manageStatus.isGranted) {
      granted = true;
    } else if (manageStatus.isDenied) {
      manageStatus = await Permission.manageExternalStorage.request();
      if (manageStatus.isGranted) granted = true;
    }
  }

  // اگر permission نداد، مشکلی نیست - از app-specific استفاده می‌کنیم
}
```

## 📱 تست شده روی

✅ Android 11 (API 30)  
✅ Android 12 (API 31)  
✅ Android 13 (API 33)  
✅ Android 14 (API 34)  

## 🎯 نتیجه

حالا Export **بدون هیچ مشکل Permission** کار می‌کنه!

```
کاربر Export می‌زنه
    ↓
[بدون نیاز به Permission]
    ↓
فایل ذخیره می‌شه در:
/Android/data/.../files/B24_Reports/
    ↓
✅ Success! File saved
```

## 📝 راهنمای کاربر

وقتی Export موفق شد، این پیام نشون داده میشه:

```
✅ Export Successful

File saved to:
/storage/emulated/0/Android/data/com.example.b24_torque_monitor/files/B24_Reports/Tehran_Metro_20241207_1430.xlsx

How to access:
1. Open File Manager app
2. Go to "Internal Storage"
3. Navigate to Android > data > com.example.b24_torque_monitor > files > B24_Reports

Or search for the file name in your File Manager.
```

## ⚠️ نکته مهم

اگر کاربر اپ رو Uninstall کنه، فایل‌های ذخیره شده در `Android/data/[app]/files` **حذف می‌شن**.

برای Backup دائمی، کاربر باید:
1. فایل رو Export کنه
2. از File Manager فایل رو Share کنه
3. در Google Drive یا جای دیگه Backup بگیره

## 🔄 Alternative: Public Downloads (اگر کاربر Permission بده)

اگر کاربر Storage Permission بده، می‌تونیم فایل رو در Public Downloads هم ذخیره کنیم. این کار رو می‌تونیم در آینده اضافه کنیم:

```dart
if (await Permission.storage.isGranted) {
  // Save to public Downloads
  directory = Directory('/storage/emulated/0/Download/B24_Reports');
} else {
  // Save to app-specific
  directory = await getExternalStorageDirectory();
}
```

---

**نسخه**: 1.1.1  
**تاریخ**: 2024/12/07  
**وضعیت**: ✅ Fixed
