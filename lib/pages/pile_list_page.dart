import 'package:flutter/material.dart';
import '../models/project.dart';
import '../models/pile.dart';
import '../database/database_helper.dart';
import 'monitoring_page.dart';

class PileListPage extends StatefulWidget {
  final Project project;
  final String operatorCode;

  const PileListPage({
    Key? key,
    required this.project,
    required this.operatorCode,
  }) : super(key: key);

  @override
  State<PileListPage> createState() => _PileListPageState();
}

class _PileListPageState extends State<PileListPage> {
  List<Pile> _piles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPiles();
  }

  Future<void> _loadPiles() async {
    setState(() => _isLoading = true);
    
    try {
      final piles = await DatabaseHelper.instance.getPilesByProject(widget.project.id);
      setState(() {
        _piles = piles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Loading error: $e')),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'done':
      case 'completed': // ✅ Keep for backward compatibility
        return const Color(0xFF10B981);
      case 'edited':
        return const Color(0xFF8B5CF6); // Purple for edited
      case 'in_progress':
        return const Color(0xFFFBBF24);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'done':
      case 'completed': // ✅ Keep for backward compatibility
        return 'Done';
      case 'edited':
        return 'Edited';
      case 'in_progress':
        return 'In Progress';
      default:
        return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Calculate pile statistics
    final totalPiles = _piles.length;
    final completedPiles = _piles.where((p) => p.status == 'completed').length;
    final pendingPiles = _piles.where((p) => p.status == 'pending').length;
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.project.name),
            Text(
              widget.project.location,
              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _piles.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.push_pin, size: 64, color: Color(0xFF9CA3AF)),
                      SizedBox(height: 16),
                      Text('No piles found'),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // ✅ Pile Statistics Card
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatCard('Total', totalPiles, Icons.layers, const Color(0xFFFFFFFF)),
                          _buildStatCard('Completed', completedPiles, Icons.check_circle, const Color(0xFF10B981)),
                          _buildStatCard('Pending', pendingPiles, Icons.pending, const Color(0xFFFBBF24)),
                        ],
                      ),
                    ),
                    // ✅ Pile List
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _piles.length,
                        itemBuilder: (context, index) {
                          final pile = _piles[index];
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              onTap: () async {
                                // ✅ Check if pile is done and ask for edit reason
                                if (pile.status == 'done' || pile.status == 'completed') {
                                  final recordCount = await DatabaseHelper.instance.getMeasurementsByPile(pile.id);
                                  
                                  final editReasonController = TextEditingController();
                                  
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) => AlertDialog(
                                      title: const Row(
                                        children: [
                                          Icon(Icons.warning, color: Color(0xFFFBBF24), size: 28),
                                          SizedBox(width: 8),
                                          Text('Pile Already Done'),
                                        ],
                                      ),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'This pile has already been completed with the following data:',
                                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 12),
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1F2937),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFF374151)),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    const Text('Pile ID:', style: TextStyle(color: Color(0xFF9CA3AF))),
                                                    Text(pile.pileId, style: const TextStyle(fontWeight: FontWeight.bold)),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    const Text('Records:', style: TextStyle(color: Color(0xFF9CA3AF))),
                                                    Text('${recordCount.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    const Text('Final Depth:', style: TextStyle(color: Color(0xFF9CA3AF))),
                                                    Text('${pile.finalDepth?.toStringAsFixed(2) ?? "N/A"} m', style: const TextStyle(fontWeight: FontWeight.bold)),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          const Text(
                                            'Are you sure you want to work on this pile again?',
                                            style: TextStyle(fontSize: 13, color: Color(0xFFFBBF24)),
                                          ),
                                          const SizedBox(height: 12),
                                          const Text(
                                            'Please explain the reason for editing (max 50 characters):',
                                            style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                                          ),
                                          const SizedBox(height: 8),
                                          TextField(
                                            controller: editReasonController,
                                            maxLength: 50,
                                            decoration: const InputDecoration(
                                              hintText: 'e.g., Incorrect depth reading',
                                              border: OutlineInputBorder(),
                                              counterText: '',
                                            ),
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            if (editReasonController.text.trim().isEmpty) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Please provide a reason for editing'),
                                                  backgroundColor: Color(0xFFF87171),
                                                ),
                                              );
                                              return;
                                            }
                                            Navigator.of(context).pop(true);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFFBBF24),
                                            foregroundColor: const Color(0xFF1F2937),
                                          ),
                                          child: const Text('Yes, Continue'),
                                        ),
                                      ],
                                    ),
                                  );
                                  
                                  if (confirmed != true) return;
                                  
                                  // ✅ Save edit reason and change status to 'edited'
                                  final updatedPile = pile.copyWith(
                                    status: 'edited',
                                    editReason: editReasonController.text.trim(),
                                  );
                                  await DatabaseHelper.instance.updatePile(updatedPile);
                                  
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => MonitoringPage(
                                        project: widget.project,
                                        pile: updatedPile,
                                        operatorCode: widget.operatorCode,
                                      ),
                                    ),
                                  );
                                  _loadPiles();
                                  return;
                                }
                                
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => MonitoringPage(
                                      project: widget.project,
                                      pile: pile,
                                      operatorCode: widget.operatorCode,
                                    ),
                                  ),
                                );
                                _loadPiles();
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(pile.status).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        pile.status == 'completed'
                                            ? Icons.check_circle
                                            : pile.status == 'in_progress'
                                                ? Icons.play_circle
                                                : Icons.radio_button_unchecked,
                                        color: _getStatusColor(pile.status),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            pile.pileId,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'No. ${pile.pileNumber} - ${pile.pileType}',
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.speed, size: 14, color: Color(0xFF9CA3AF)),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${pile.expectedTorque} Nm',
                                                style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                                              ),
                                              const SizedBox(width: 12),
                                              const Icon(Icons.straighten, size: 14, color: Color(0xFF9CA3AF)),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${pile.expectedDepth} m',
                                                style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(pile.status).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _getStatusText(pile.status),
                                        style: TextStyle(
                                          color: _getStatusColor(pile.status),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildStatCard(String label, int count, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 8),
        Text(
          '$count',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFFE5E7EB)),
        ),
      ],
    );
  }
}