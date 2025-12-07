# 🔵 Bluetooth Setup Guide for B24 Torque Monitor

## ⚠️ Important: Bluetooth Permissions Required

To connect to the B24 device, you need to configure Bluetooth permissions for both Android and iOS.

---

## 📱 Android Setup

### 1. Update `android/app/src/main/AndroidManifest.xml`

Add these permissions **before** the `<application>` tag:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    
    <!-- Bluetooth Permissions for Android 12+ (API 31+) -->
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN"
                     android:usesPermissionFlags="neverForLocation" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
    
    <!-- Bluetooth Permissions for older Android versions -->
    <uses-permission android:name="android.permission.BLUETOOTH" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
    
    <!-- Location Permission (required for Bluetooth scanning) -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

    <application>
        ...
    </application>
</manifest>
```

### 2. Update `android/app/build.gradle`

Make sure `minSdkVersion` is at least 21:

```gradle
android {
    defaultConfig {
        minSdkVersion 21  // ✅ Minimum Android 5.0
        targetSdkVersion 34
    }
}
```

---

## 🍎 iOS Setup

### Update `ios/Runner/Info.plist`

Add these keys inside `<dict>`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth to connect to the B24 Torque Monitor device</string>

<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app needs Bluetooth to connect to the B24 Torque Monitor device</string>
```

---

## 🔍 Testing Connection

### 1. Enable Bluetooth
- Make sure Bluetooth is **enabled** on your phone
- Turn on the **B24 device**

### 2. Check Permissions
- When you first run the app, it will ask for Bluetooth and Location permissions
- **Allow all permissions**

### 3. Monitor Debug Panel
In the Monitoring screen, you'll see a **Debug Info** card showing:
- **Connected**: Yes/No
- **Mock Data**: Yes/No (should be "No" when connected)
- **Raw Hex**: Actual data from device
- **Status**: Connection status
- **Error**: Any error messages

### 4. Expected Behavior
- **Mock Data = No** → Using real device
- **Raw Hex = (hex numbers)** → Receiving data
- **Torque value changing** → Device is working!

---

## ❌ Troubleshooting

### "No B24 devices found"
1. ✅ Check device is powered ON
2. ✅ Check Bluetooth is enabled on phone
3. ✅ Check you granted Location permission (required for BLE scanning)
4. ✅ Move closer to the device (< 5 meters)

### "Connection failed: Permission denied"
1. Go to **Settings** → **Apps** → **B24 Torque Monitor**
2. Enable **Location** and **Bluetooth** permissions
3. Restart the app

### Torque shows 0.00000
1. Check **Mock Data = No** in Debug Panel
2. Check **Raw Hex** is not empty
3. Check **Connected = Yes**
4. Try shaking or pressing buttons on the B24 device

### Mock Data = Yes
This means the app is using simulated data instead of the real device. This happens when:
- No B24 device was found during scan
- Connection failed
- You need to fix permissions and retry

---

## 🎯 Quick Command to Test

```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

---

## 📊 Debug Output

When connected, you should see logs like this:

```
🔍 Scanning for B24 devices...
✅ Found 1 B24 device(s)
✅ Connected to B24-12345
📦 Raw Manufacturer Data (0x04C3): 01 4D 80 6C C9 A4 C9 47 A2 5B F5 21 DF
✅ B24 Data: Torque=123.456 Nm, Status=0x4D, Units=0x80
```

---

## 🔧 Need Help?

If you still can't connect:
1. Take a screenshot of the **Debug Info** panel
2. Check the device name (should start with "B24")
3. Try connecting with another Bluetooth app first to verify the device works
