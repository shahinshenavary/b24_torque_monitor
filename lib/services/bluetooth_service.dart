import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;

class TorqueData {
  final double torque;
  final double force;
  final double mass;
  final int timestamp;

  TorqueData({
    required this.torque,
    required this.force,
    required this.mass,
    required this.timestamp,
  });
}

class DebugInfo {
  final String rawHex;
  final String decodedHex;
  final String status;
  final String error;
  final bool isConnected;
  final bool isMockData;

  DebugInfo({
    required this.rawHex,
    required this.decodedHex,
    required this.status,
    required this.error,
    required this.isConnected,
    required this.isMockData,
  });
}

// 🆕 Device Discovery Info for scanning
class DeviceDiscoveryInfo {
  final int dataTag;
  final String deviceName;
  final int rssi;
  final int timestamp;

  DeviceDiscoveryInfo({
    required this.dataTag,
    required this.deviceName,
    required this.rssi,
    required this.timestamp,
  });
}

class B24BluetoothService {
  static final B24BluetoothService instance = B24BluetoothService._init();
  B24BluetoothService._init();

  fbp.BluetoothDevice? _connectedDevice;
  fbp.BluetoothCharacteristic? _dataCharacteristic;
  final StreamController<TorqueData> _dataController = StreamController<TorqueData>.broadcast();
  final StreamController<DebugInfo> _debugController = StreamController<DebugInfo>.broadcast();
  
  // 🆕 New stream specifically for device discovery
  final StreamController<DeviceDiscoveryInfo> _discoveryController = StreamController<DeviceDiscoveryInfo>.broadcast();
  
  Stream<TorqueData> get dataStream => _dataController.stream;
  Stream<DebugInfo> get debugStream => _debugController.stream;
  Stream<DeviceDiscoveryInfo> get discoveryStream => _discoveryController.stream;
  bool get isConnected => _connectedDevice != null;

  // B24 Configuration
  static const String DEVICE_NAME_PREFIX = "B24";
  
  // Service UUIDs
  static const String configServiceUUID = "a970fd30-a0e8-11e6-bdf4-0800200c9a66";
  static const String dataServiceUUID = "a9712440-a0e8-11e6-bdf4-0800200c9a66";
  
  // Characteristic UUIDs
  static const String configPinUUID = "a970fd39-a0e8-11e6-bdf4-0800200c9a66";
  static const String statusUUID = "a9712441-a0e8-11e6-bdf4-0800200c9a66";
  static const String dataValueUUID = "a9712442-a0e8-11e6-bdf4-0800200c9a66";
  static const String dataUnitsUUID = "a9712443-a0e8-11e6-bdf4-0800200c9a66";

  // Mantracourt Company ID
  static const int COMPANY_ID = 0x04C3;
  
  // XOR Encryption
  static const List<int> DEFAULT_SEED = [0x5C, 0x6F, 0x2F, 0x41, 0x21, 0x7A, 0x26, 0x45, 0x5C, 0x6F];
  String viewPin = "0000"; // Default View PIN
  
  // Mock data generator (for testing without real device)
  Timer? _mockDataTimer;
  bool _useMockData = false; // Set to false when using real device
  final Random _random = Random();
  double _currentMockTorque = 0.0;

  // Advertising scan
  StreamSubscription<List<fbp.ScanResult>>? _scanSubscription;
  bool _isScanning = false;
  
  // Project-specific DATA TAG filtering
  List<int> _allowedDataTags = []; // Only accept packets with these DATA TAGs
  
  // 🆕 Track discovered devices during scan (to avoid duplicates in discovery stream)
  final Set<int> _discoveredDataTags = {};
  
  /// Set allowed DATA TAGs for current project
  void setAllowedDataTags(List<int> tags) {
    _allowedDataTags = tags;
    print("🔐 Allowed DATA TAGs set: ${tags.map((t) => '0x${t.toRadixString(16).toUpperCase()}').join(', ')}");
  }
  
  /// Clear DATA TAG filter (accept all)
  void clearDataTagFilter() {
    _allowedDataTags = [];
    print("🔓 DATA TAG filter cleared - accepting all devices");
  }

  /// Start continuous scanning for B24 devices (Broadcast Mode - NO CONNECTION)
  /// This allows multiple apps to receive data simultaneously
  Future<void> startBroadcastMonitoring() async {
    if (_isScanning) {
      print("⚠️ Already scanning");
      return;
    }

    if (await fbp.FlutterBluePlus.isSupported == false) {
      throw Exception("Bluetooth not supported");
    }

    // Check if Bluetooth is on
    final adapterState = await fbp.FlutterBluePlus.adapterState.first;
    if (adapterState == fbp.BluetoothAdapterState.off) {
      throw Exception("Bluetooth is off - please enable it");
    }

    print("🔍 Starting B24 Broadcast Monitoring (View Mode)...");
    print("📡 This mode only listens to advertising packets - NO CONNECTION");
    print("🔎 Looking for devices starting with: $DEVICE_NAME_PREFIX");
    
    _isScanning = true;
    _discoveredDataTags.clear(); // Reset discovered devices

    // CRITICAL: continuousUpdates allows real-time advertising data updates!
    await fbp.FlutterBluePlus.startScan(
      continuousUpdates: true,  // ⚡ This is the key!
    );

    _scanSubscription = fbp.FlutterBluePlus.scanResults.listen((results) {
      if (results.isEmpty) {
        print("📡 Scan Results: 0 devices found");
      } else {
        print("📡 Scan Results: ${results.length} devices found");
      }
      
      for (var result in results) {
        final deviceName = result.device.platformName;
        print("   Device: $deviceName (RSSI: ${result.rssi})");
        
        // Filter B24 devices
        if (deviceName.startsWith(DEVICE_NAME_PREFIX)) {
          print("   ✅ B24 Device Found: $deviceName");
          
          // Process ALL manufacturer data (not just company ID 0x04C3)
          if (result.advertisementData.manufacturerData.isNotEmpty) {
            print("   📦 Manufacturer Data Keys: ${result.advertisementData.manufacturerData.keys.toList()}");
            
            // Parse manufacturer data from all sources
            _parseAdvertisingData(
              result.advertisementData.manufacturerData, 
              deviceName: deviceName,
              rssi: result.rssi,
            );
          } else {
            print("   ⚠️ No manufacturer data in advertising packet");
            
            // Send status to debug stream
            _debugController.add(DebugInfo(
              rawHex: "",
              decodedHex: "",
              status: "⚠️ B24 found but no manufacturer data",
              error: "Device: $deviceName - Try pressing a button on the device",
              isConnected: false,
              isMockData: false,
            ));
          }
        }
      }
    });
    
    print("✅ Broadcast Monitoring started");
  }

  /// Stop scanning
  Future<void> stopBroadcastMonitoring() async {
    print("🛑 Stopping B24 Broadcast Monitoring");
    _isScanning = false;
    await fbp.FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    _discoveredDataTags.clear();
  }

  Future<List<fbp.BluetoothDevice>> scanDevices() async {
    List<fbp.BluetoothDevice> devices = [];
    
    if (await fbp.FlutterBluePlus.isSupported == false) {
      throw Exception("Bluetooth not supported");
    }

    await fbp.FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    _scanSubscription = fbp.FlutterBluePlus.scanResults.listen((results) {
      for (var result in results) {
        // Filter B24 devices
        if (result.device.platformName.startsWith(DEVICE_NAME_PREFIX)) {
          if (!devices.contains(result.device)) {
            devices.add(result.device);
          }
        }
        
        // Try to decode advertising data
        if (result.advertisementData.manufacturerData.isNotEmpty) {
          _parseAdvertisingData(
            result.advertisementData.manufacturerData,
            deviceName: result.device.platformName,
            rssi: result.rssi,
          );
        }
      }
    });

    await Future.delayed(const Duration(seconds: 10));
    await fbp.FlutterBluePlus.stopScan();

    return devices;
  }
  
  void _parseAdvertisingData(
    Map<int, List<int>> manufacturerData, {
    String deviceName = 'Unknown',
    int rssi = 0,
  }) {
    // Process ALL manufacturer data (search for B24 pattern in any company ID)
    manufacturerData.forEach((companyId, data) {
      final hexDump = data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      print("📦 Raw Manufacturer Data (0x${companyId.toRadixString(16).padLeft(4, '0')}): $hexDump");
      print("   Length: ${data.length} bytes");
      
      // Search for B24 pattern: 0x4D 0x80 (Tag Head + Tag Tail)
      for (int i = 0; i < data.length - 1; i++) {
        if (data[i] == 0x4D && data[i + 1] == 0x80) {
          print("   🎯 Found B24 pattern at byte $i: 0x4D 0x80");
          
          int dataStartIndex = i + 2; // Data starts after 4D 80
          
          // Need at least 6 bytes after the pattern
          if (dataStartIndex + 6 <= data.length) {
            print("   ✅ Sufficient data after pattern (${data.length - dataStartIndex} bytes)");
            _decodeAndEmit(data, dataStartIndex);
            return; // Found and processed, exit
          } else {
            print("   ⚠️ Insufficient data after pattern (${data.length - dataStartIndex} bytes, need 6)");
          }
        }
      }
      
      // If no pattern found, try legacy parsing (for 0x04C3)
      if (companyId == COMPANY_ID) {
        print("   🔄 No pattern found, trying legacy format...");
        _parseLegacyFormat(data, deviceName: deviceName, rssi: rssi);
      }
    });
  }
  
  void _parseLegacyFormat(
    List<int> data, {
    String deviceName = 'Unknown',
    int rssi = 0,
  }) {
    // Legacy format: Format ID + Data Tag + Encoded Data
    final hexDump = data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
    
    // Validate packet length (minimum 14 bytes)
    if (data.length < 14) {
      print("⚠️ Packet too short: ${data.length} bytes (expected >= 14)");
      return;
    }
    
    try {
      // Extract fields
      final formatId = data[0];
      print("   Format ID: 0x${formatId.toRadixString(16).padLeft(2, '0')}");
      
      if (formatId != 0x01) {
        print("⚠️ Unknown format ID: $formatId (expected 0x01)");
        return;
      }
      
      final dataTag = (data[2] << 8) | data[1];
      final hexString = dataTag.toRadixString(16).padLeft(4, '0').toUpperCase();
      print("   Data Tag: $dataTag (0x$hexString)");
      
      // 🆕 Emit device discovery event (only once per device during scan)
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
      
      // 🔐 CRITICAL: Check if this DATA TAG is allowed for current project
      if (_allowedDataTags.isNotEmpty && !_allowedDataTags.contains(dataTag)) {
        print("   🚫 DATA TAG $dataTag (0x${dataTag.toRadixString(16).toUpperCase()}) not in allowed list - IGNORING");
        print("   📋 Allowed: ${_allowedDataTags.map((t) => '0x${t.toRadixString(16).toUpperCase()}').join(', ')}");
        return; // Ignore this device!
      }
      
      if (_allowedDataTags.isNotEmpty) {
        print("   ✅ DATA TAG $dataTag matches project - ACCEPTING");
      }
      
      // Decode encrypted fields (Status, Units, Data, repeated Data Tags)
      final encodedData = data.sublist(3); // From byte 3 onwards
      final encodedHex = encodedData.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      print("   Encoded Data: $encodedHex");
      
      final decodedData = _decodeData(encodedData);
      final decodedHex = decodedData.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      print("   Decoded Data: $decodedHex");
      
      if (decodedData.length < 11) {
        print("⚠️ Decoded data too short: ${decodedData.length} bytes (expected >= 11)");
        return;
      }
      
      final status = decodedData[0];
      final units = decodedData[1];
      final torqueBytes = decodedData.sublist(2, 6);
      final dataTag1 = (decodedData[7] << 8) | decodedData[6];
      final dataTag2 = (decodedData[9] << 8) | decodedData[8];
      
      print("   Status: 0x${status.toRadixString(16).padLeft(2, '0')}");
      print("   Units: 0x${units.toRadixString(16).padLeft(2, '0')}");
      print("   Data Tag 1: $dataTag1, Data Tag 2: $dataTag2 (expected: $dataTag)");
      
      // Verify data tag repetition
      if (dataTag1 != dataTag || dataTag2 != dataTag) {
        print("⚠️ Data tag mismatch - decoding may be incorrect");
        print("   Expected: $dataTag, Got: $dataTag1 and $dataTag2");
        return;
      }
      
      // Parse IEEE 754 float (MSB first based on Table 5)
      final torque = _bytesToFloat(torqueBytes);
      
      print("✅ B24 Data: Torque=$torque Nm, Status=0x${status.toRadixString(16)}, Units=0x${units.toRadixString(16)}");
      print("");
      
      // Send to stream
      _dataController.add(TorqueData(
        torque: torque,
        force: torque * 9.80665, // Convert to Newtons (from Units table)
        mass: torque / 9.80665, // Approximate mass in kg
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
      
      // Send debug info to stream
      _debugController.add(DebugInfo(
        rawHex: hexDump,
        decodedHex: decodedHex,
        status: "✅ B24 Data: Torque=$torque Nm, Status=0x${status.toRadixString(16)}, Units=0x${units.toRadixString(16)}",
        error: "",
        isConnected: true,
        isMockData: false,
      ));
    } catch (e) {
      print("❌ Error parsing legacy format: $e");
    }
  }

  void _decodeAndEmit(List<int> rawPacket, int startIndex) {
    try {
      // Extract 6 bytes after 4D 80 pattern
      List<int> encodedBytes = rawPacket.sublist(startIndex, startIndex + 6);
      final encodedHex = encodedBytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      print("   Encoded Bytes: $encodedHex");
      
      // Apply XOR decryption
      List<int> decoded = [];
      final viewPinBytes = viewPin.codeUnits;
      
      for (int j = 0; j < 6; j++) {
        int encryptedByte = encodedBytes[j];
        // Formula: Encrypted ^ (Seed ^ PIN)
        int key = DEFAULT_SEED[j] ^ viewPinBytes[j % viewPinBytes.length];
        decoded.add(encryptedByte ^ key);
      }
      
      final decodedHex = decoded.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      print("   Decoded Bytes: $decodedHex");
      
      // Extract fields
      int status = decoded[0];      // Byte 0: Status
      int unitByte = decoded[1];    // Byte 1: Unit Code
      
      // Bytes 2-5: Torque Value (IEEE 754 Float, Big Endian)
      Uint8List floatBytes = Uint8List.fromList(decoded.sublist(2, 6));
      double torque = ByteData.sublistView(floatBytes).getFloat32(0, Endian.big);
      
      print("   Status: 0x${status.toRadixString(16).padLeft(2, '0')}");
      print("   Unit: 0x${unitByte.toRadixString(16).padLeft(2, '0')}");
      print("✅ B24 Data: Torque=$torque Nm");
      print("");
      
      // Send to stream
      _dataController.add(TorqueData(
        torque: torque,
        force: torque * 9.80665,
        mass: torque / 9.80665,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
      
      // Send debug info
      _debugController.add(DebugInfo(
        rawHex: encodedHex,
        decodedHex: decodedHex,
        status: "✅ B24 Data: Torque=$torque Nm",
        error: "",
        isConnected: true,
        isMockData: false,
      ));
    } catch (e) {
      print("❌ Error decoding B24 data: $e");
      
      _debugController.add(DebugInfo(
        rawHex: "",
        decodedHex: "",
        status: "",
        error: "❌ Error decoding: $e",
        isConnected: true,
        isMockData: false,
      ));
    }
  }

  List<int> _decodeData(List<int> encoded) {
    // Build encoding array from Default Seed XOR View PIN
    final viewPinBytes = viewPin.codeUnits;
    final encodingArray = List<int>.generate(10, (i) {
      final seed = DEFAULT_SEED[i];
      final pin = viewPinBytes[i % viewPinBytes.length];
      return seed ^ pin;
    });
    
    // Decode by XOR with encoding array
    final decoded = List<int>.generate(encoded.length, (i) {
      return encoded[i] ^ encodingArray[i % encodingArray.length];
    });
    
    return decoded;
  }

  double _bytesToFloat(List<int> bytes) {
    if (bytes.length != 4) return 0.0;
    
    // IEEE 754 Float - MSB First (Big Endian) per B24 Manual Table 5
    // Example from manual: 0x40 0x22 0x8F 0x5C = 2.54
    final buffer = Uint8List.fromList(bytes);
    final byteData = ByteData.sublistView(buffer);
    return byteData.getFloat32(0, Endian.big);
  }

  Future<void> connectToDevice(fbp.BluetoothDevice device, {int configPin = 0}) async {
    try {
      await device.connect(timeout: const Duration(seconds: 15));
      _connectedDevice = device;

      List<fbp.BluetoothService> services = await device.discoverServices();
      
      // Find data service
      fbp.BluetoothService? dataService;
      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == dataServiceUUID.toLowerCase()) {
          dataService = service;
          break;
        }
      }
      
      if (dataService == null) {
        throw Exception("B24 Data Service not found");
      }
      
      // Find data value characteristic
      for (var characteristic in dataService.characteristics) {
        if (characteristic.uuid.toString().toLowerCase() == dataValueUUID.toLowerCase()) {
          _dataCharacteristic = characteristic;
          
          // Enable notifications
          await characteristic.setNotifyValue(true);
          
          // Listen to data updates
          characteristic.lastValueStream.listen((value) {
            if (value.isNotEmpty && value.length >= 4) {
              final torque = _bytesToFloat(value);
              _dataController.add(TorqueData(
                torque: torque,
                force: torque * 9.80665,
                mass: torque / 9.80665,
                timestamp: DateTime.now().millisecondsSinceEpoch,
              ));
            }
          });
          
          break;
        }
      }
      
      // Write Configuration PIN (must be done within 5 seconds)
      await _writeConfigurationPin(services, configPin);
      
      print("✅ Connected to B24 device: ${device.platformName}");
      
    } catch (e) {
      // If connection fails, use mock data for testing
      if (_useMockData) {
        print("⚠️ Using mock data for testing (device connection failed: $e)");
        _startMockDataGeneration();
      } else {
        throw Exception("Failed to connect: $e");
      }
    }
  }

  Future<void> _writeConfigurationPin(List<fbp.BluetoothService> services, int pin) async {
    try {
      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == configServiceUUID.toLowerCase()) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == configPinUUID.toLowerCase()) {
              // Write Configuration PIN as Uint32 (4 bytes, little endian)
              final pinBytes = Uint8List(4);
              final byteData = ByteData.sublistView(pinBytes);
              byteData.setUint32(0, pin, Endian.little);
              
              await characteristic.write(pinBytes.toList(), withoutResponse: false);
              print("✅ Configuration PIN written");
              return;
            }
          }
        }
      }
    } catch (e) {
      print("⚠️ Failed to write Configuration PIN: $e");
    }
  }

  void _startMockDataGeneration() {
    print("🔄 Starting mock data generation...");
    _mockDataTimer?.cancel();
    
    _mockDataTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      // Simulate torque changes
      final change = _random.nextDouble();
      
      if (change < 0.3) {
        _currentMockTorque += _random.nextDouble() * 20 + 5;
      } else if (change < 0.6) {
        _currentMockTorque -= _random.nextDouble() * 15;
      } else {
        _currentMockTorque += (_random.nextDouble() - 0.5) * 10;
      }

      // Keep torque in reasonable range (0-250)
      _currentMockTorque = _currentMockTorque.clamp(0.0, 250.0);

      // Add realistic variation
      final torqueWithNoise = _currentMockTorque + (_random.nextDouble() - 0.5) * 2;
      final force = torqueWithNoise * 0.8 + _random.nextDouble() * 10;
      final mass = torqueWithNoise * 0.5 + _random.nextDouble() * 5;

      _dataController.add(TorqueData(
        torque: torqueWithNoise,
        force: force,
        mass: mass,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
      
      // Send debug info to stream
      _debugController.add(DebugInfo(
        rawHex: "",
        decodedHex: "",
        status: "🔄 Mock Data: Torque=$torqueWithNoise Nm, Force=$force N, Mass=$mass kg",
        error: "",
        isConnected: false,
        isMockData: true,
      ));
    });
  }

  Future<void> disconnect() async {
    _mockDataTimer?.cancel();
    _scanSubscription?.cancel();
    
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
      _dataCharacteristic = null;
    }
  }

  void dispose() {
    _mockDataTimer?.cancel();
    _scanSubscription?.cancel();
    _dataController.close();
    _debugController.close();
    _discoveryController.close();
  }

  // Set View PIN for decoding advertising data
  void setViewPin(String pin) {
    if (pin.length <= 8) {
      viewPin = pin;
      print("🔐 View PIN set to: $pin");
    }
  }

  /// Scan for a specific DATA TAG to verify device exists
  /// Returns true if device with this DATA TAG is found broadcasting
  Future<bool> scanForDataTag(int targetDataTag, {Duration timeout = const Duration(seconds: 3)}) async {
    print("🔍 Scanning for DATA TAG: 0x${targetDataTag.toRadixString(16).toUpperCase()}");
    
    bool deviceFound = false;
    StreamSubscription? scanSubscription;
    
    try {
      if (await fbp.FlutterBluePlus.isSupported == false) {
        throw Exception("Bluetooth not supported");
      }

      final adapterState = await fbp.FlutterBluePlus.adapterState.first;
      if (adapterState == fbp.BluetoothAdapterState.off) {
        throw Exception("Bluetooth is off");
      }

      // Listen to discovery stream
      scanSubscription = discoveryStream.listen((discovery) {
        if (discovery.dataTag == targetDataTag) {
          print("✅ Found device with DATA TAG 0x${targetDataTag.toRadixString(16).toUpperCase()}: ${discovery.deviceName}");
          deviceFound = true;
        }
      });

      // Start scanning
      await startBroadcastMonitoring();
      
      // Wait for timeout
      await Future.delayed(timeout);
      
      // Stop scanning
      await stopBroadcastMonitoring();
      await scanSubscription.cancel();
      
      if (deviceFound) {
        print("✅ Device with DATA TAG 0x${targetDataTag.toRadixString(16).toUpperCase()} found");
      } else {
        print("❌ No device found with DATA TAG 0x${targetDataTag.toRadixString(16).toUpperCase()}");
      }
      
      return deviceFound;
      
    } catch (e) {
      print("❌ Scan error: $e");
      await scanSubscription?.cancel();
      await stopBroadcastMonitoring();
      return false;
    }
  }

  // Enable/disable mock data
  void setMockDataEnabled(bool enabled) {
    _useMockData = enabled;
    if (enabled && !_dataController.isClosed) {
      _startMockDataGeneration();
    } else {
      _mockDataTimer?.cancel();
    }
  }
}