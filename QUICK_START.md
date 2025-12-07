# ⚡ Quick Start Guide

راهنمای سریع برای شروع کار با B24 Torque Monitor

---

## 🚀 نصب سریع (5 دقیقه)

### **گام 1: کپی کردن فایل‌ها**

از پوشه `/aaa/` همه فایل‌ها رو به پروژه Flutter کپی کن:

```bash
# Structure:
your_project/
├── lib/              ← کپی کن از /aaa/lib/
├── android/          ← فقط AndroidManifest.xml رو آپدیت کن
├── ios/              ← فقط Info.plist رو آپدیت کن
└── pubspec.yaml      ← کپی کن از /aaa/pubspec.yaml
```

### **گام 2: Dependencies**

```bash
flutter pub get
```

### **گام 3: Permissions**

#### **Android:**
کپی کن `CORRECT_AndroidManifest.xml` به:
```
android/app/src/main/AndroidManifest.xml
```

یا permission های لازم رو اضافه کن (خطوط 5-20 فایل CORRECT_AndroidManifest.xml)

#### **iOS:**
کپی کن این خطوط از `Info_plist_EXAMPLE.xml` به `ios/Runner/Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth to connect to B24 devices</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>Location is required for Bluetooth scanning</string>
```

### **گام 4: اجرا**

```bash
flutter run
```

---

## 🎯 اولین استفاده

### **1. Login**
- کد: **1234**

### **2. تست Bluetooth**
- بزن روی 🐛 (گوشه بالا)
- دکمه **"Check Permissions"**
- باید ببینی: `✅ Bluetooth is ON and ready`

### **3. تست Scan**
- دکمه **"Raw Scan"**
- منتظر 10 ثانیه
- باید دستگاه‌های اطراف رو ببینی

اگه دستگاهی ندیدی → `HOW_TO_DEBUG_SCAN.md` رو بخون

### **4. ایجاد پروژه**
- Back → New Project
- نام و موقعیت وارد کن
- Scan → انتخاب دستگاه B24
- Import Excel → انتخاب فایل شمع‌ها
- Save

### **5. شروع مانیتورینگ**
- انتخاب پروژه
- انتخاب شمع
- Start Monitoring
- وقتی Torque > 100 → خودکار ضبط میشه

---

## ❌ مشکل داری؟

### **Scan کار نمی‌کنه؟**
👉 `HOW_TO_DEBUG_SCAN.md`

### **Permission error?**
👉 `CORRECT_AndroidManifest.xml` و `Info_plist_EXAMPLE.xml`

### **Bluetooth OFF?**
1. Settings گوشی → Bluetooth → ON
2. App رو بسته و دوباره باز کن

### **هیچ دستگاهی پیدا نمیشه؟**
1. Debug Scanner → "Check Permissions"
2. اگه OK بود → B24 رو روشن کن
3. اگه Not OK → Settings → Permissions

---

## 📖 مستندات کامل

- `README.md` - Overview کلی
- `HOW_TO_DEBUG_SCAN.md` - رفع مشکل Scan ⭐
- `DEBUG_GUIDE_SCAN_TROUBLESHOOTING.md` - راهنمای کامل Debug
- `CHANGELOG.md` - تاریخچه تغییرات

---

## ✅ چک‌لیست

قبل از استفاده، مطمئن شو:

- [ ] `flutter pub get` اجرا شد
- [ ] AndroidManifest.xml permission ها رو داره
- [ ] Info.plist (iOS) permission ها رو داره
- [ ] Bluetooth گوشی روشن هست
- [ ] GPS/Location روشن هست (Android)
- [ ] دستگاه B24 روشن هست
- [ ] با Debug Scanner تست کردی

---

**همین! حالا آماده استفاده است 🎉**

مشکلی بود؟ → `HOW_TO_DEBUG_SCAN.md`
