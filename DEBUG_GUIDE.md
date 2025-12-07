# 🐛 Debug Guide - Advertising Packets Not Received

## 🎯 Problem
App starts broadcast monitoring but doesn't receive data from B24 device.

---

## ✅ Step-by-Step Debugging

### 1. Use Debug Page

**Location:** Login screen → Top-right bug icon 🐛

**What to do:**
1. Open app
2. Tap bug icon (top-right)
3. Tap "Start Monitoring"
4. Watch the logs in real-time

---

### 2. Check Console Logs

Run app with:
```bash
flutter run --verbose
```

**Expected Logs (GOOD):**
```
🔍 Starting B24 Broadcast Monitoring (View Mode)...
📡 This mode only listens to advertising packets - NO CONNECTION
🔎 Looking for devices starting with: B24
✅ Broadcast Monitoring started
📡 Scan Results: 3 devices found
   Device: B24-12345 (RSSI: -45)
   ✅ B24 Device Found: B24-12345
   📦 Manufacturer Data: {1219: [1, 77, 128, 108, ...]}
   🔓 Parsing advertising data...
📦 Raw Manufacturer Data (0x04C3): 01 4D 80 6C C9 A4 C9 47...
✅ B24 Data: Torque=123.456 Nm
```

**Problem Logs (BAD):**

#### A. No Devices Found
```
📡 Scan Results: 0 devices found
```
**Cause:** Bluetooth scanning not working
**Fix:** 
- Check Bluetooth permissions
- Turn Bluetooth ON
- Move closer to device

#### B. B24 Found but No Data
```
Device: B24-12345 (RSSI: -45)
✅ B24 Device Found: B24-12345
📦 Manufacturer Data: {}
⚠️ No manufacturer data in advertising packet
```
**Cause:** Device not sending manufacturer data
**Fix:**
- Press any button on B24 device to wake it up
- Check if device is in "View Mode" not "Config Mode"
- Another app might be connected (disconnect it)

#### C. Wrong Company ID
```
📦 Manufacturer Data: {1234: [1, 2, 3, ...]}
```
**Cause:** Not Mantracourt company ID (0x04C3 = 1219)
**Fix:**
- Verify device is genuine B24
- Check manual for correct company ID

---

### 3. Check Permissions

#### Android

**File:** `android/app/src/main/AndroidManifest.xml`

Must have:
```xml
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
                 android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

**Runtime Check:**
```dart
// In app
Settings → Apps → B24 Torque Monitor → Permissions
✅ Location: Allowed
✅ Nearby Devices: Allowed
```

#### iOS

**File:** `ios/Runner/Info.plist`

Must have:
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Required for B24 torque monitoring</string>
```

---

### 4. Common Issues

#### Issue 1: Device Name Doesn't Match

**Symptom:** Logs show other devices but not B24

**Check:**
```dart
// In bluetooth_service.dart
static const String DEVICE_NAME_PREFIX = "B24";
```

**Your device name:** `__________` (check device label)

**If different, change to:**
```dart
static const String DEVICE_NAME_PREFIX = "YOUR_DEVICE_PREFIX";
```

#### Issue 2: Wrong View PIN

**Symptom:** Data tags don't match after decoding

**Logs:**
```
⚠️ Data tag mismatch - decoding may be incorrect
   Expected: 33101, Got: 12345 and 67890
```

**Fix:**
```dart
// Before starting monitoring:
B24BluetoothService.instance.setViewPin("1234"); // Your actual View PIN
```

#### Issue 3: Device in Config Mode

**Symptom:** Other app disconnects when your app runs

**Fix:**
1. Close all other apps connected to B24
2. Wait 10 seconds
3. Device should return to broadcast mode
4. Restart your app

---

### 5. Test with Mock Data

If device not available, test with mock data:

**In `bluetooth_service.dart`:**
```dart
// Line ~73
bool _useMockData = true; // Change to true for testing
```

**Then:**
```dart
// In monitoring page
B24BluetoothService.instance.setMockDataEnabled(true);
```

Mock data should show:
```
🔄 Mock Data: Torque=123.456 Nm
```

---

### 6. Debug Panel Indicators

#### Green (Good):
- ✅ "B24 Data: Torque=..."
- Connected: Yes
- Mock Data: No

#### Yellow (Warning):
- ⚠️ "B24 found but no manufacturer data"
- Try pressing button on device

#### Red (Error):
- ❌ "Error parsing advertising data"
- ❌ "Data tag mismatch"
- Check View PIN

---

## 🔍 Detailed Packet Analysis

### Expected Advertising Packet Structure:

```
Company ID: 0x04C3 (1219 decimal)
├─ Format ID: 0x01
├─ Data Tag: 0xXXXX (2 bytes, little endian)
└─ Encrypted Data (11 bytes):
   ├─ Status (1 byte)
   ├─ Units (1 byte)
   ├─ Torque Value (4 bytes, IEEE 754)
   └─ Data Tag Repeat (4 bytes)
```

### XOR Decryption:

```
Encoding Array = DEFAULT_SEED XOR View PIN
Decoded = Encrypted XOR Encoding Array

DEFAULT_SEED = [0x5C, 0x6F, 0x2F, 0x41, 0x21, 0x7A, 0x26, 0x45, 0x5C, 0x6F]
View PIN = "0000" → [0x30, 0x30, 0x30, 0x30, ...]
```

### Example Packet:

```
Raw: 01 4D 80 6C C9 A4 C9 47 A2 5B F5 21 DF

Format ID: 0x01
Data Tag: 0x4D80 (33101)
Encrypted: 6C C9 A4 C9 47 A2 5B F5 21 DF

After XOR:
Decoded: 30 80 DC A9 3F 4D 80 C5 A1 4D 80

Status: 0x30
Units: 0x80
Torque: 0xDC A9 3F 4D → IEEE 754 → 123.456 Nm
Data Tag 1: 0x4D80 ✅
Data Tag 2: 0x4D80 ✅
```

---

## 📋 Checklist

Before reporting issues, check:

- [ ] Bluetooth is ON
- [ ] Location permission granted (Android)
- [ ] App has Bluetooth permission
- [ ] Device is within 10 meters
- [ ] Device name starts with "B24"
- [ ] No other app is connected
- [ ] View PIN is correct
- [ ] Console shows "Scan Results: X devices"
- [ ] Console shows "B24 Device Found"
- [ ] Manufacturer Data is not empty

---

## 🆘 Still Not Working?

### Share These Logs:

1. **Full console output** (first 50 lines after "Start Monitoring")
2. **Debug panel screenshot**
3. **Device name** (from device label)
4. **Android/iOS version**
5. **App version**

### Quick Test:

```bash
# Test 1: Check Bluetooth
flutter run
# → Open Debug page
# → Start Monitoring
# → Count devices found (should be > 0)

# Test 2: Check Permissions
flutter run --verbose | grep -i "permission"
# → Should show all permissions granted

# Test 3: Mock Data
# → Change _useMockData = true
# → Should show data immediately
```

---

## ✅ Success Indicators

When everything works:

```
✅ Logs show "B24 Device Found"
✅ Logs show "B24 Data: Torque=..."
✅ Debug panel shows hex data
✅ Torque value changes in real-time
✅ Other apps still work with device
```
