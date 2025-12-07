# 🔧 Fix: Duplicate Permissions Error

## ❌ Error Message:
```
Element uses-permission#android.permission.BLUETOOTH_SCAN duplicated
```

## 🎯 Solution: Remove Duplicate Permissions

---

## Step 1: Open Your AndroidManifest.xml

Path: `android/app/src/main/AndroidManifest.xml`

---

## Step 2: Replace ENTIRE FILE with This:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    
    <!-- Bluetooth Permissions for Android 12+ (API 31+) -->
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN"
                     android:usesPermissionFlags="neverForLocation" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
    
    <!-- Bluetooth Permissions for older Android versions -->
    <uses-permission android:name="android.permission.BLUETOOTH"
                     android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN"
                     android:maxSdkVersion="30" />
    
    <!-- Location Permission (required for BLE scanning) -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    
    <application
        android:label="b24_torque_monitor"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />
            
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
```

---

## Step 3: Clean & Rebuild

```bash
flutter clean
flutter pub get
flutter build apk --release
```

---

## ✅ What Changed?

### Before (Duplicate):
```xml
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />  <!-- ❌ Duplicate! -->
```

### After (Fixed):
```xml
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
                 android:usesPermissionFlags="neverForLocation" />  <!-- ✅ Only once! -->
```

---

## 💡 Key Points:

1. **Each permission should appear ONLY ONCE**
2. **Remove ALL old permissions before adding new ones**
3. **Don't mix old and new Bluetooth permissions for same API level**

---

## 🚀 After Fix:

Your build should succeed:
```
✓ Built build/app/outputs/flutter-apk/app-release.apk (XX.X MB)
```

---

## 📋 Complete File Location:

I've created a **clean, correct version** in:
```
/aaa/CORRECT_AndroidManifest.xml
```

**Copy this file to:**
```
D:\app2\b24_torque_monitor\android\app\src\main\AndroidManifest.xml
```

---

## ⚠️ Important Notes:

### If you added permissions manually:
- Open your current `AndroidManifest.xml`
- **Delete ALL `<uses-permission>` lines**
- **Copy ONLY the permissions from `CORRECT_AndroidManifest.xml`**
- Keep your existing `<application>` section unchanged

### If you're using flutter_blue_plus plugin:
- The plugin might auto-add some permissions
- That's why you got duplicates
- Use `android:maxSdkVersion="30"` to avoid conflicts

---

## 🔍 Quick Check:

After copying the file, search for duplicates:

```bash
# On Windows PowerShell:
cd D:\app2\b24_torque_monitor
Select-String "BLUETOOTH_SCAN" android\app\src\main\AndroidManifest.xml

# Should show ONLY 1 result!
```

---

## ✅ Ready to Test!

```bash
flutter build apk --release
flutter install
```
