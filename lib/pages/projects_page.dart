import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/project.dart';
import '../models/pile.dart';
import '../database/database_helper.dart';
import 'add_project_page.dart';
import 'pile_list_page.dart';

class ProjectsPage extends StatefulWidget {
  final String operatorCode;

  const ProjectsPage({Key? key, required this.operatorCode}) : super(key: key);

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  List<Project> _projects = [];
  Map<String, int> _pileCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoading = true);
    
    try {
      final projects = await DatabaseHelper.instance.getAllProjects();
      final Map<String, int> counts = {};
      
      for (var project in projects) {
        final piles = await DatabaseHelper.instance.getPilesByProject(project.id);
        counts[project.id] = piles.length;
      }
      
      setState(() {
        _projects = projects;
        _pileCounts = counts;
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

  Future<void> _deleteProject(Project project) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف پروژه'),
        content: Text('آیا مطمئن هستید که می‌خواهید "${project.name}" را حذف کنید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('لغو'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFF87171)),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteProject(project.id);
      _loadProjects();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('پروژه‌ها'),
            Text(
              'اپراتور: ${widget.operatorCode}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _projects.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_off, size: 64, color: Colors.grey[600]),
                      const SizedBox(height: 16),
                      const Text('هیچ پروژه‌ای وجود ندارد'),
                      const SizedBox(height: 8),
                      const Text(
                        'برای شروع، یک پروژه جدید ایجاد کنید',
                        style: TextStyle(color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadProjects,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _projects.length,
                    itemBuilder: (context, index) {
                      final project = _projects[index];
                      final pileCount = _pileCounts[project.id] ?? 0;
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => PileListPage(
                                  project: project,
                                  operatorCode: widget.operatorCode,
                                ),
                              ),
                            );
                            _loadProjects();
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
                                    color: const Color(0xFF2563EB).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.folder, color: Color(0xFF2563EB)),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        project.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on, size: 14, color: Color(0xFF9CA3AF)),
                                          const SizedBox(width: 4),
                                          Text(
                                            project.location,
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        DateFormat('yyyy/MM/dd HH:mm').format(
                                          DateTime.fromMillisecondsSinceEpoch(project.createdAt),
                                        ),
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '$pileCount شمع',
                                        style: const TextStyle(
                                          color: Color(0xFF10B981),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Color(0xFFF87171)),
                                      onPressed: () => _deleteProject(project),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AddProjectPage(operatorCode: widget.operatorCode),
            ),
          );
          _loadProjects();
        },
        icon: const Icon(Icons.add),
        label: const Text('پروژه جدید'),
      ),
    );
  }
}
