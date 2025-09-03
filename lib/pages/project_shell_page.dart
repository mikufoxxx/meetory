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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1000;

        final appBar = AppBar(title: Text(widget.project.name));

        final body = Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: pages[_index],
          ),
        );

        if (isWide) {
          return Scaffold(
            appBar: appBar,
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.history_outlined),
                      selectedIcon: Icon(Icons.history),
                      label: Text('会议历史'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.library_books_outlined),
                      selectedIcon: Icon(Icons.library_books),
                      label: Text('文档/知识库'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: appBar,
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.history_outlined),
                  selectedIcon: Icon(Icons.history),
                  label: '会议历史'),
              NavigationDestination(
                  icon: Icon(Icons.library_books_outlined),
                  selectedIcon: Icon(Icons.library_books),
                  label: '文档/知识库'),
            ],
          ),
        );
      },
    );
  }
}

class _MeetingCard extends StatelessWidget {
  final dynamic meeting;
  const _MeetingCard({required this.meeting});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                MeetingDetailPage(meeting: meeting),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                )),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.videocam,
                    color: Theme.of(context).colorScheme.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      meeting.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.outline,
                    size: 14,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      '${meeting.time.year}-${meeting.time.month.toString().padLeft(2, '0')}-${meeting.time.day.toString().padLeft(2, '0')} ${meeting.time.hour.toString().padLeft(2, '0')}:${meeting.time.minute.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ),
                ],
              ),
              if (meeting.tags.isNotEmpty) ...[
                const SizedBox(height: 3),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: meeting.tags.take(2).map<Widget>((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tag,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
                              fontSize: 10,
                            ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
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
              Icon(Icons.meeting_room_outlined,
                  size: 72, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text('暂无会议记录', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('在此项目下创建会议后，会议记录将显示在这里。'),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 800;

        if (isWide) {
          // 平板/桌面版本：使用网格布局
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: constraints.maxWidth > 1200 ? 3 : 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.8,
            ),
            itemCount: meetings.length,
            itemBuilder: (context, index) {
              final m = meetings[index];
              return _MeetingCard(meeting: m);
            },
          );
        }

        // 手机版本：使用列表布局
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: meetings.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final m = meetings[index];
            return _MeetingCard(meeting: m);
          },
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
            Icon(Icons.auto_stories,
                size: 72, color: Theme.of(context).colorScheme.primary),
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
