import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import '../services/bluetooth_service.dart';

class DebugBluetoothPage extends StatefulWidget {
  const DebugBluetoothPage({Key? key}) : super(key: key);

  @override
  State<DebugBluetoothPage> createState() => _DebugBluetoothPageState();
}

class _DebugBluetoothPageState extends State<DebugBluetoothPage> {
  final List<String> _logs = [];
  StreamSubscription<TorqueData>? _dataSubscription;
  StreamSubscription<DebugInfo>? _debugSubscription;
  StreamSubscription<DeviceDiscoveryInfo>? _discoverySubscription;
  StreamSubscription<List<fbp.ScanResult>>? _rawScanSubscription;
  
  bool _isScanning = false;
  TorqueData? _latestData;
  DebugInfo? _latestDebug;
  
  final Map<String, int> _discoveredDevices = {}; // deviceId -> count
  bool _showAllDevices = true; // Show all devices, not just B24

  @override
  void initState() {
    super.initState();
    _setupStreams();
  }

  void _setupStreams() {
    _dataSubscription = B24BluetoothService.instance.dataStream.listen((data) {
      setState(() {
        _latestData = data;
        _addLog('📊 Data: Torque=${data.torque.toStringAsFixed(2)} Nm');
      });
    });

    _debugSubscription = B24BluetoothService.instance.debugStream.listen((info) {
      setState(() {
        _latestDebug = info;
        if (info.status.isNotEmpty) _addLog('📝 ${info.status}');
        if (info.error.isNotEmpty) _addLog('❌ ${info.error}');
      });
    });
    
    _discoverySubscription = B24BluetoothService.instance.discoveryStream.listen((info) {
      _addLog('🎯 Discovery: ${info.deviceName} - TAG: 0x${info.dataTag.toRadixString(16).toUpperCase()} (RSSI: ${info.rssi})');
    });
  }

  void _addLog(String message) {
    setState(() {
      _logs.insert(0, '[${DateTime.now().toString().substring(11, 19)}] $message');
      if (_logs.length > 200) _logs.removeLast();
    });
  }

  Future<void> _startRawScan() async {
    if (_isScanning) {
      _addLog('⚠️ Already scanning');
      return;
    }

    _addLog('🔍 Starting RAW Bluetooth Scan...');
    _addLog('📡 Mode: ${_showAllDevices ? "ALL DEVICES" : "B24 ONLY"}');
    setState(() {
      _isScanning = true;
      _discoveredDevices.clear();
    });

    try {
      // Check Bluetooth support
      if (await fbp.FlutterBluePlus.isSupported == false) {
        _addLog('❌ Bluetooth not supported on this device');
        setState(() => _isScanning = false);
        return;
      }

      // Check if Bluetooth is on
      final adapterState = await fbp.FlutterBluePlus.adapterState.first;
      _addLog('📶 Bluetooth State: ${adapterState.toString()}');
      
      if (adapterState == fbp.BluetoothAdapterState.off) {
        _addLog('❌ Bluetooth is OFF - Please turn it on');
        setState(() => _isScanning = false);
        return;
      }

      _addLog('✅ Starting scan with continuousUpdates...');
      
      // Start scan
      await fbp.FlutterBluePlus.startScan(
        continuousUpdates: true,
        timeout: Duration(seconds: 30),
      );

      // Listen to raw scan results
      _rawScanSubscription = fbp.FlutterBluePlus.scanResults.listen((results) {
        _addLog('📡 Scan tick: ${results.length} devices found');
        
        for (var result in results) {
          final deviceId = result.device.remoteId.toString();
          final deviceName = result.device.platformName.isEmpty 
              ? 'Unknown' 
              : result.device.platformName;
          final rssi = result.rssi;
          
          // Count how many times we've seen this device
          _discoveredDevices[deviceId] = (_discoveredDevices[deviceId] ?? 0) + 1;
          final count = _discoveredDevices[deviceId]!;
          
          // Filter: Show all or only B24
          if (!_showAllDevices && !deviceName.startsWith('B24')) {
            continue; // Skip non-B24 devices
          }
          
          _addLog('📱 Device: $deviceName (ID: ${deviceId.substring(0, 8)}...) RSSI: $rssi dBm [#$count]');
          
          // Show manufacturer data
          if (result.advertisementData.manufacturerData.isNotEmpty) {
            result.advertisementData.manufacturerData.forEach((companyId, data) {
              final hexDump = data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
              _addLog('   📦 Mfg Data [0x${companyId.toRadixString(16).padLeft(4, '0')}]: $hexDump (${data.length} bytes)');
              
              // Highlight B24 pattern
              for (int i = 0; i < data.length - 1; i++) {
                if (data[i] == 0x4D && data[i + 1] == 0x80) {
                  _addLog('   🎯 B24 PATTERN FOUND at byte $i: 4D 80');
                }
              }
              
              // Check for Format ID 0x01 (Legacy Format)
              if (data.isNotEmpty && data[0] == 0x01 && data.length >= 3) {
                final dataTag = (data[2] << 8) | data[1];
                _addLog('   🏷️ Legacy Format: DATA TAG = $dataTag (0x${dataTag.toRadixString(16).padLeft(4, '0').toUpperCase()})');
              }
            });
          } else {
            _addLog('   ⚠️ No manufacturer data');
          }
          
          // Show service UUIDs
          if (result.advertisementData.serviceUuids.isNotEmpty) {
            _addLog('   🔧 Services: ${result.advertisementData.serviceUuids.join(", ")}');
          }
        }
      });

      _addLog('✅ Scan started - waiting for devices...');

    } catch (e) {
      _addLog('❌ Scan Error: $e');
      setState(() => _isScanning = false);
    }
  }

  Future<void> _stopScan() async {
    _addLog('🛑 Stopping scan...');
    await fbp.FlutterBluePlus.stopScan();
    _rawScanSubscription?.cancel();
    setState(() => _isScanning = false);
    _addLog('✅ Scan stopped');
    _addLog('📊 Summary: ${_discoveredDevices.length} unique devices discovered');
  }

  Future<void> _startB24Monitoring() async {
    _addLog('🔍 Starting B24 Broadcast Monitoring (using service)...');
    setState(() => _isScanning = true);
    
    try {
      B24BluetoothService.instance.clearDataTagFilter();
      await B24BluetoothService.instance.startBroadcastMonitoring();
      _addLog('✅ B24 Monitoring started');
    } catch (e) {
      _addLog('❌ Error: $e');
      setState(() => _isScanning = false);
    }
  }

  Future<void> _stopB24Monitoring() async {
    _addLog('🛑 Stopping B24 Monitoring...');
    await B24BluetoothService.instance.stopBroadcastMonitoring();
    setState(() => _isScanning = false);
    _addLog('✅ B24 Monitoring stopped');
  }

  void _clearLogs() {
    setState(() => _logs.clear());
  }

  Future<void> _checkPermissions() async {
    _addLog('🔐 Checking Bluetooth permissions...');
    
    try {
      final isSupported = await fbp.FlutterBluePlus.isSupported;
      _addLog('   Bluetooth Supported: $isSupported');
      
      final adapterState = await fbp.FlutterBluePlus.adapterState.first;
      _addLog('   Adapter State: ${adapterState.toString()}');
      
      if (adapterState == fbp.BluetoothAdapterState.on) {
        _addLog('✅ Bluetooth is ON and ready');
      } else {
        _addLog('❌ Bluetooth is OFF - Please enable it in Settings');
      }
    } catch (e) {
      _addLog('❌ Permission Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Debug Scanner'),
        actions: [
          IconButton(
            onPressed: _clearLogs,
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear Logs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Control Panel
          Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Raw Bluetooth Scan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  
                  // Filter toggle
                  SwitchListTile(
                    title: const Text('Show All Devices', style: TextStyle(fontSize: 14)),
                    subtitle: Text(_showAllDevices ? 'Showing all BLE devices' : 'Showing B24 only', 
                                   style: const TextStyle(fontSize: 12)),
                    value: _showAllDevices,
                    onChanged: (value) {
                      setState(() => _showAllDevices = value);
                      _addLog('🔄 Filter: ${value ? "ALL DEVICES" : "B24 ONLY"}');
                    },
                    dense: true,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Scan buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isScanning ? null : _startRawScan,
                          icon: const Icon(Icons.radar, size: 18),
                          label: const Text('Raw Scan', style: TextStyle(fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isScanning ? _stopScan : null,
                          icon: const Icon(Icons.stop, size: 18),
                          label: const Text('Stop', style: TextStyle(fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF87171),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // B24 Service buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isScanning ? null : _startB24Monitoring,
                          icon: const Icon(Icons.bluetooth_searching, size: 18),
                          label: const Text('B24 Monitor', style: TextStyle(fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isScanning ? _stopB24Monitoring : null,
                          icon: const Icon(Icons.stop, size: 18),
                          label: const Text('Stop B24', style: TextStyle(fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Check permissions button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _checkPermissions,
                      icon: const Icon(Icons.security, size: 18),
                      label: const Text('Check Permissions', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Status
          if (_isScanning)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: const Color(0xFF10B981),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Scanning... ${_discoveredDevices.length} devices found',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

          // Latest Data Display
          if (_latestData != null)
            Card(
              margin: const EdgeInsets.all(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Latest Torque Data',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_latestData!.torque.toStringAsFixed(2)} Nm',
                      style: const TextStyle(fontSize: 20, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 8),

          // Logs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text(
                  'Console Logs',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${_logs.length} entries',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF374151)),
              ),
              child: _logs.isEmpty
                  ? const Center(
                      child: Text(
                        'No logs yet. Start scanning to see activity.',
                        style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: SelectableText(
                            log,
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'Courier',
                              height: 1.3,
                              color: log.contains('❌')
                                  ? const Color(0xFFF87171)
                                  : log.contains('✅')
                                      ? const Color(0xFF10B981)
                                      : log.contains('⚠️')
                                          ? const Color(0xFFFBBF24)
                                          : log.contains('🎯')
                                              ? const Color(0xFF60A5FA)
                                              : log.contains('📱')
                                                  ? const Color(0xFFA78BFA)
                                                  : Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),

          // Info Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: const Color(0xFF1E3A8A),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '💡 Debug Tips:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
                SizedBox(height: 4),
                Text(
                  '• Use "Raw Scan" to see ALL Bluetooth devices nearby',
                  style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                ),
                Text(
                  '• Look for "B24" in device names and "4D 80" pattern in data',
                  style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                ),
                Text(
                  '• Make sure B24 device is powered on and transmitting',
                  style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                ),
                Text(
                  '• Check permissions if no devices appear',
                  style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _debugSubscription?.cancel();
    _discoverySubscription?.cancel();
    _rawScanSubscription?.cancel();
    fbp.FlutterBluePlus.stopScan();
    super.dispose();
  }
}
