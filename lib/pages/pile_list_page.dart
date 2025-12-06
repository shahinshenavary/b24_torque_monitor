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
          SnackBar(content: Text('خطا در بارگذاری: $e')),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF10B981);
      case 'in_progress':
        return const Color(0xFFFBBF24);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'completed':
        return 'تکمیل شده';
      case 'in_progress':
        return 'در حال انجام';
      default:
        return 'در انتظار';
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      Text('هیچ شمعی وجود ندارد'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _piles.length,
                  itemBuilder: (context, index) {
                    final pile = _piles[index];
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () async {
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
                                      'شماره ${pile.pileNumber} - ${pile.pileType}',
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
    );
  }
}
