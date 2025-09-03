import 'package:flutter/material.dart';
import '../models/project.dart';
import 'meeting_detail_page.dart';

class ProjectShellPage extends StatefulWidget {
  final Project project;
  const ProjectShellPage({super.key, required this.project});

  @override
  State<ProjectShellPage> createState() => _ProjectShellPageState();
}

class _ProjectShellPageState extends State<ProjectShellPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      ProjectHistoryPage(project: widget.project),
      ProjectKnowledgePage(project: widget.project),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(widget.project.name)),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.history), label: '会议历史'),
          NavigationDestination(icon: Icon(Icons.library_books_outlined), label: '文档/知识库'),
        ],
      ),
    );
  }
}

class ProjectHistoryPage extends StatelessWidget {
  final Project project;
  const ProjectHistoryPage({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    final meetings = project.meetings;
    
    if (meetings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.meeting_room_outlined, size: 72, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text('暂无会议记录', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('在此项目下创建会议后，会议记录将显示在这里。'),
            ],
          ),
        ),
      );
    }
    
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: meetings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final m = meetings[index];
        return Card(
          child: ListTile(
            leading: Icon(
              Icons.videocam,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(m.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${m.time.year}-${m.time.month.toString().padLeft(2, '0')}-${m.time.day.toString().padLeft(2, '0')} ${m.time.hour.toString().padLeft(2, '0')}:${m.time.minute.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (m.tags.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '标签：${m.tags.join(', ')}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ],
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => MeetingDetailPage(meeting: m)),
            ),
          ),
        );
      },
    );
  }
}

class ProjectKnowledgePage extends StatelessWidget {
  final Project project;
  const ProjectKnowledgePage({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    // 占位：后续接入聚合知识/文档
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.auto_stories, size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('项目知识库（占位）', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('这里将展示该项目的聚合文档、主题、概念图谱与演进。'),
          ],
        ),
      ),
    );
  }
}