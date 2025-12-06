import 'dart:async';
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

class B24BluetoothService {
  static final B24BluetoothService instance = B24BluetoothService._init();
  B24BluetoothService._init();

  fbp.BluetoothDevice? _connectedDevice;
  fbp.BluetoothCharacteristic? _dataCharacteristic;
  final StreamController<TorqueData> _dataController = StreamController<TorqueData>.broadcast();
  
  Stream<TorqueData> get dataStream => _dataController.stream;
  bool get isConnected => _connectedDevice != null;

  // UUIDs - جایگزین با UUIDهای واقعی دستگاه B24
  static const String serviceUUID = "0000ffe0-0000-1000-8000-00805f9b34fb";
  static const String characteristicUUID = "0000ffe1-0000-1000-8000-00805f9b34fb";

  Future<List<fbp.BluetoothDevice>> scanDevices() async {
    List<fbp.BluetoothDevice> devices = [];
    
    if (await fbp.FlutterBluePlus.isSupported == false) {
      throw Exception("Bluetooth not supported");
    }

    await fbp.FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    var subscription = fbp.FlutterBluePlus.scanResults.listen((results) {
      for (var result in results) {
        if (!devices.contains(result.device)) {
          devices.add(result.device);
        }
      }
    });

    await Future.delayed(const Duration(seconds: 10));
    await fbp.FlutterBluePlus.stopScan();
    subscription.cancel();

    return devices;
  }

  Future<void> connectToDevice(fbp.BluetoothDevice device) async {
    try {
      await device.connect(timeout: const Duration(seconds: 15));
      _connectedDevice = device;

      List<fbp.BluetoothService> services = await device.discoverServices();
      
      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == serviceUUID.toLowerCase()) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == characteristicUUID.toLowerCase()) {
              _dataCharacteristic = characteristic;
              
              await characteristic.setNotifyValue(true);
              
              characteristic.lastValueStream.listen((value) {
                _parseData(value);
              });
              
              break;
            }
          }
        }
      }
    } catch (e) {
      throw Exception("Failed to connect: $e");
    }
  }

  void _parseData(List<int> value) {
    if (value.length >= 12) {
      final torque = _bytesToDouble(value.sublist(0, 4));
      final force = _bytesToDouble(value.sublist(4, 8));
      final mass = _bytesToDouble(value.sublist(8, 12));
      
      _dataController.add(TorqueData(
        torque: torque,
        force: force,
        mass: mass,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
    }
  }

  double _bytesToDouble(List<int> bytes) {
    if (bytes.length != 4) return 0.0;
    
    int value = (bytes[3] << 24) | (bytes[2] << 16) | (bytes[1] << 8) | bytes[0];
    return value / 100.0;
  }

  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
      _dataCharacteristic = null;
    }
  }

  void dispose() {
    _dataController.close();
  }
}
