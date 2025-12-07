# B24 Bluetooth Implementation Guide

## 📡 Overview

The B24 Torque Monitor app now supports **full B24 Bluetooth protocol** based on the official Mantracourt Technical Manual.

---

## 🔧 How B24 Bluetooth Works

### **Two Operating Modes:**

#### 1️⃣ **Advertising Mode** (Current Implementation)
- B24 broadcasts data to multiple devices simultaneously
- No connection required
- Lower power consumption
- **Default mode in this app**

#### 2️⃣ **Connected Mode** (Available)
- Point-to-point connection
- Access to configuration parameters
- Requires Configuration PIN (default: 0)

---

## 📋 Current Implementation Status

### ✅ **Implemented:**
- [x] Advertising packet scanning
- [x] XOR decryption with View PIN
- [x] IEEE 754 Float parsing
- [x] Data validation (Data Tag verification)
- [x] Mock data generator for testing
- [x] Connected mode support

### ⚙️ **Configuration:**

```dart
// In bluetooth_service.dart

// Enable real B24 device
_useMockData = false;  // Line 63

// Set View PIN (if changed from default "0000")
B24BluetoothService.instance.setViewPin("1234");

// Connect with Configuration PIN
await B24BluetoothService.instance.connectToDevice(
  device,
  configPin: 0,  // Default is 0
);
```

---

## 🔐 Encryption Details

### **Default Seed:**
```dart
[0x5C, 0x6F, 0x2F, 0x41, 0x21, 0x7A, 0x26, 0x45, 0x5C, 0x6F]
```

### **View PIN:**
- Default: `"0000"`
- Can be changed via connected mode
- Used to encrypt advertising data

### **Decoding Process:**
```
Encoding Array[i] = Default Seed[i] XOR View PIN[i % PIN_length]
Decoded Byte[i] = Encoded Byte[i] XOR Encoding Array[i % 10]
```

---

## 📦 Advertising Packet Structure

```
Byte  | Field              | Description
------|--------------------|---------------------------------
0     | Length             | 0x10 (fixed)
1     | Advert Type        | 0xFF (Manufacturer Specific)
2-3   | Company ID         | 0x04C3 (Mantracourt)
4     | Format ID          | 0x01
5-6   | Data Tag           | Module ID (plain)
7     | Status             | Status byte (ENCODED)
8     | Units              | Unit type (ENCODED)
9-12  | Data               | IEEE 754 Float (ENCODED)
13-14 | Data Tag           | Repeated (ENCODED)
15-16 | Data Tag           | Repeated again (ENCODED)
```

### **Status Byte (Byte 7):**
```
Bit 7: Reserved
Bit 6: Digital Input Active
Bit 5: Low Battery Warning
Bit 4: Fast Mode
Bit 3: Over Range
Bit 2: Not Gross (Tare applied)
Bit 1: Sensor Integrity Error
Bit 0: Shunt Cal Active
```

### **Units (Byte 8):**
From Appendix B - Units table:
- `0x96` = Newton meter (N m) - Torque
- `0x41` = Newton (N) - Force
- `0x2D` = Kilogram (kg) - Mass

---

## 🔌 Service & Characteristic UUIDs

### **Services:**
```dart
Configuration Service: a970fd30-a0e8-11e6-bdf4-0800200c9a66
Data Service:          a9712440-a0e8-11e6-bdf4-0800200c9a66
```

### **Important Characteristics:**
```dart
Configuration PIN:  a970fd39-a0e8-11e6-bdf4-0800200c9a66
Status:            a9712441-a0e8-11e6-bdf4-0800200c9a66
Data Value:        a9712442-a0e8-11e6-bdf4-0800200c9a66
Data Units:        a9712443-a0e8-11e6-bdf4-0800200c9a66
Data Rate:         a970fd31-a0e8-11e6-bdf4-0800200c9a66
View PIN:          a970fd34-a0e8-11e6-bdf4-0800200c9a66
```

---

## 🧪 Testing Guide

### **With Mock Data (Current Default):**
```bash
flutter run
```
- App automatically generates simulated torque data
- Good for testing UI and recording logic

### **With Real B24 Device:**

1. **Disable Mock Data:**
   ```dart
   // In bluetooth_service.dart, line 63:
   bool _useMockData = false;
   ```

2. **Ensure B24 is Powered On:**
   - Device should be broadcasting (LED blinking)
   - Name should start with "B24"

3. **Run App:**
   ```bash
   flutter run
   ```

4. **Connection Process:**
   - App scans for B24 devices
   - Automatically decodes advertising packets
   - OR connects in connected mode with PIN

5. **Verify Data:**
   - Check console for: `📡 B24 Data: Torque=X.XXXXX Nm`
   - Torque value should match physical reading

---

## 🐛 Troubleshooting

### **Problem: No data received (shows 0.00000)**

**Solution 1: Check Mock Data**
```dart
_useMockData = false;  // Disable if using real device
```

**Solution 2: Verify View PIN**
```dart
// If B24 View PIN was changed from default
B24BluetoothService.instance.setViewPin("YOUR_PIN");
```

**Solution 3: Check Bluetooth Permissions**
```xml
<!-- Android: AndroidManifest.xml -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

**Solution 4: Check Device Name**
- B24 device name must start with "B24"
- Check with BLE scanner app (nRF Connect)

### **Problem: Data Tag Mismatch Warning**

**Cause:** Incorrect View PIN or corrupted packet

**Solution:**
1. Verify View PIN matches B24 configuration
2. Check signal strength (move closer to device)
3. Verify Company ID is 0x04C3

---

## 🔄 Switching Between Modes

### **Advertising Mode (Default):**
```dart
// Automatically enabled during scan
await B24BluetoothService.instance.scanDevices();
```

### **Connected Mode:**
```dart
// For configuration and direct data access
await B24BluetoothService.instance.connectToDevice(
  device,
  configPin: 0,  // Your Configuration PIN
);
```

**⚠️ Important:** When connected, advertising stops. Disconnect to resume broadcasting.

---

## 📚 References

- **B24 Technical Manual:** Document 517-944 v02.02
- **Manufacturer:** Mantracourt Electronics Limited
- **Company ID:** 0x04C3
- **Bluetooth SIG:** For BLE specification details

---

## 🎯 Next Steps

If you encounter issues with real B24 device:
1. Test with **nRF Connect** app to verify advertising packets
2. Share advertising packet hex dump
3. Verify Data Tag matches label on B24 device
4. Check if View PIN was changed from default "0000"

---

**Version:** 1.0  
**Last Updated:** December 6, 2024
