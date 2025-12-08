import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/bluetooth_service.dart';
import 'dart:async';

class BluetoothDebugPage extends StatefulWidget {
  const BluetoothDebugPage({Key? key}) : super(key: key);

  @override
  State<BluetoothDebugPage> createState() => _BluetoothDebugPageState();
}

class _BluetoothDebugPageState extends State<BluetoothDebugPage> {
  final List<DebugPacket> _packets = [];
  bool _isScanning = false;
  StreamSubscription? _debugSubscription;
  StreamSubscription? _discoverySubscription;
  int _packetsReceived = 0;
  final Set<int> _discoveredDataTags = {};

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    // Listen to debug stream
    _debugSubscription = B24BluetoothService.instance.debugStream.listen((debug) {
      if (debug.rawHex.isNotEmpty) {
        setState(() {
          _packetsReceived++;
          _packets.insert(0, DebugPacket(
            timestamp: DateTime.now(),
            rawHex: debug.rawHex,
            decodedHex: debug.decodedHex,
            status: debug.status,
            error: debug.error,
          ));
          
          // Keep only last 50 packets
          if (_packets.length > 50) {
            _packets.removeLast();
          }
        });
      }
    });

    // Listen to discovery stream
    _discoverySubscription = B24BluetoothService.instance.discoveryStream.listen((discovery) {
      setState(() {
        _discoveredDataTags.add(discovery.dataTag);
      });
    });
  }

  Future<void> _toggleScanning() async {
    if (_isScanning) {
      await B24BluetoothService.instance.stopBroadcastMonitoring();
      setState(() {
        _isScanning = false;
      });
    } else {
      try {
        setState(() {
          _packets.clear();
          _packetsReceived = 0;
          _discoveredDataTags.clear();
        });
        
        await B24BluetoothService.instance.startBroadcastMonitoring();
        
        setState(() {
          _isScanning = true;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _debugSubscription?.cancel();
    _discoverySubscription?.cancel();
    if (_isScanning) {
      B24BluetoothService.instance.stopBroadcastMonitoring();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Packet Inspector'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              setState(() {
                _packets.clear();
                _packetsReceived = 0;
                _discoveredDataTags.clear();
              });
            },
            tooltip: 'Clear',
          ),
        ],
      ),
      body: Column(
        children: [
          // Control Panel
          Container(
            color: const Color(0xFFF3F4F6),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _toggleScanning,
                        icon: Icon(_isScanning ? Icons.stop : Icons.play_arrow),
                        label: Text(_isScanning ? 'Stop Scanning' : 'Start Scanning'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isScanning ? const Color(0xFFF87171) : const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Stats
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Packets',
                        value: _packetsReceived.toString(),
                        icon: Icons.cell_tower,
                        color: const Color(0xFF3B82F6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        label: 'Devices',
                        value: _discoveredDataTags.length.toString(),
                        icon: Icons.bluetooth,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
                
                if (_discoveredDataTags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF10B981), width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.devices, size: 16, color: Color(0xFF10B981)),
                            SizedBox(width: 8),
                            Text(
                              'Discovered DATA TAGs:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _discoveredDataTags.map((tag) {
                            final hexString = tag.toRadixString(16).padLeft(4, '0').toUpperCase();
                            return GestureDetector(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: hexString));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Copied: $hexString'),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '0x$hexString',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '($tag)',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.copy, size: 14, color: Colors.white),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Packets List
          Expanded(
            child: _packets.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isScanning ? Icons.sensors : Icons.bluetooth_disabled,
                          size: 64,
                          color: const Color(0xFF9CA3AF),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isScanning ? 'Scanning for B24 devices...' : 'Press Start Scanning',
                          style: const TextStyle(color: Color(0xFF9CA3AF)),
                        ),
                        if (_isScanning) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Make sure device is active and broadcasting',
                            style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _packets.length,
                    itemBuilder: (context, index) {
                      final packet = _packets[index];
                      return _PacketCard(packet: packet, packetNumber: _packetsReceived - index);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}

class _PacketCard extends StatelessWidget {
  final DebugPacket packet;
  final int packetNumber;

  const _PacketCard({required this.packet, required this.packetNumber});

  @override
  Widget build(BuildContext context) {
    final hasError = packet.error.isNotEmpty;
    
    // Parse RAW packet
    final rawBytes = packet.rawHex.split(' ');
    final decodedBytes = packet.decodedHex.split(' ');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.all(16),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: hasError ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              hasError ? Icons.error : Icons.check_circle,
              color: hasError ? const Color(0xFFF87171) : const Color(0xFF10B981),
              size: 20,
            ),
          ),
          title: Text(
            'Packet #$packetNumber',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          subtitle: Text(
            _formatTime(packet.timestamp),
            style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${rawBytes.length}B',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
          children: [
            // RAW Manufacturer Data
            _buildSectionHeader('📦 RAW MANUFACTURER DATA', rawBytes.length),
            const SizedBox(height: 8),
            _buildHexGrid(rawBytes, 'RAW'),
            
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            
            // Decoded Data
            _buildSectionHeader('🔓 DECODED DATA (After XOR)', decodedBytes.length),
            const SizedBox(height: 8),
            _buildHexGrid(decodedBytes, 'DECODED'),
            
            if (packet.status.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info, size: 18, color: Color(0xFF065F46)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        packet.status,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF065F46), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            if (hasError) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, size: 18, color: Color(0xFF991B1B)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        packet.error,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                        text: 'Packet #$packetNumber\nTime: ${_formatTime(packet.timestamp)}\n\nRAW: ${packet.rawHex}\n\nDECODED: ${packet.decodedHex}\n\nStatus: ${packet.status}\n\nError: ${packet.error}',
                      ));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Packet data copied to clipboard'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy All', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int byteCount) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$byteCount bytes',
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildHexGrid(List<String> bytes, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hex String (selectable)
          SelectableText(
            bytes.join(' '),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Byte-by-byte grid
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(bytes.length, (index) {
              // Color coding based on byte position
              Color bgColor;
              Color textColor;
              String? byteLabel;
              
              if (label == 'RAW') {
                // Try to detect pattern position
                bool isPattern = false;
                if (index > 0 && bytes[index - 1] == '4D' && bytes[index] == '80') {
                  isPattern = true;
                } else if (index < bytes.length - 1 && bytes[index] == '4D' && bytes[index + 1] == '80') {
                  isPattern = true;
                }
                
                if (isPattern) {
                  bgColor = const Color(0xFFFEF3C7);
                  textColor = const Color(0xFF92400E);
                  byteLabel = 'TAG';
                } else if (index >= bytes.length - 6) {
                  // Last 6 bytes are encrypted data
                  bgColor = const Color(0xFFFED7AA);
                  textColor = const Color(0xFF9A3412);
                  byteLabel = 'ENC';
                } else {
                  bgColor = const Color(0xFFE0E7FF);
                  textColor = const Color(0xFF3730A3);
                }
              } else {
                // DECODED packet structure
                if (index == 0) {
                  bgColor = const Color(0xFFE9D5FF);
                  textColor = const Color(0xFF6B21A8);
                  byteLabel = 'STS';
                } else if (index == 1) {
                  bgColor = const Color(0xFFBBF7D0);
                  textColor = const Color(0xFF166534);
                  byteLabel = 'UNT';
                } else if (index >= 2 && index <= 5) {
                  bgColor = const Color(0xFFBFDBFE);
                  textColor = const Color(0xFF1E3A8A);
                  byteLabel = 'D${index - 2}';
                } else {
                  bgColor = const Color(0xFFF3F4F6);
                  textColor = const Color(0xFF374151);
                }
              }
              
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: textColor.withOpacity(0.3)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '[$index]',
                      style: TextStyle(
                        fontSize: 8,
                        color: textColor.withOpacity(0.7),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      bytes[index],
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (byteLabel != null)
                      Text(
                        byteLabel,
                        style: TextStyle(
                          fontSize: 7,
                          color: textColor.withOpacity(0.7),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}.${time.millisecond.toString().padLeft(3, '0')}';
  }
}

class DebugPacket {
  final DateTime timestamp;
  final String rawHex;
  final String decodedHex;
  final String status;
  final String error;

  DebugPacket({
    required this.timestamp,
    required this.rawHex,
    required this.decodedHex,
    required this.status,
    required this.error,
  });
}