import 'package:flutter/material.dart';
import '../models/project.dart';
import '../services/meeting_service.dart';
import 'project_shell_page.dart';

// =============== 页面：项目列表 ===============
class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  void _refreshProjects() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('项目 Projects')),
      body: FutureBuilder<List<Project>>(
        future: MeetingService.instance.getAllProjects(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('加载项目失败: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshProjects,
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          }
          
          final projects = snapshot.data ?? [];
          
          if (projects.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('暂无项目'),
                  SizedBox(height: 8),
                  Text('创建会议时会自动生成项目', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          
          final isWide = MediaQuery.sizeOf(context).width >= 800;
          final grid = isWide;
          
          return Padding(
            padding: const EdgeInsets.all(16),
            child: grid
                ? GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 5 / 3,
                    ),
                    itemCount: projects.length,
                    itemBuilder: (context, index) => _ProjectCard(
                      project: projects[index],
                      onProjectUpdated: _refreshProjects,
                    ),
                  )
                : ListView.separated(
                    itemCount: projects.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _ProjectTile(
                      project: projects[index],
                      onProjectUpdated: _refreshProjects,
                    ),
                  ),
          );
        },
      ),
    );
  }
}

// 显示编辑项目对话框
Future<void> _showEditProjectDialog(BuildContext context, Project project, VoidCallback onProjectUpdated) async {
  final nameController = TextEditingController(text: project.name);
  final descriptionController = TextEditingController(text: project.description);
  
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('编辑项目'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '项目名称',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: '项目描述',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              final newDescription = descriptionController.text.trim();
              
              if (newName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('项目名称不能为空')),
                );
                return;
              }
              
              try {
                await MeetingService.instance.updateProject(
                  project.name,
                  newName,
                  newDescription,
                );
                
                if (context.mounted) {
                  Navigator.of(context).pop();
                  onProjectUpdated();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('项目更新成功')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('更新失败: $e')),
                  );
                }
              }
            },
            child: const Text('保存'),
          ),
        ],
      );
    },
  );
}

class _ProjectTile extends StatelessWidget {
  final Project project;
  final VoidCallback onProjectUpdated;
  const _ProjectTile({required this.project, required this.onProjectUpdated});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => ProjectShellPage(project: project),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.folder, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      project.description,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.meeting_room,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${project.meetings.length} 个会议',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showEditProjectDialog(context, project, onProjectUpdated),
                    tooltip: '编辑项目',
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  final VoidCallback onProjectUpdated;
  const _ProjectCard({required this.project, required this.onProjectUpdated});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => ProjectShellPage(project: project),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.folder, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(project.name, style: Theme.of(context).textTheme.titleMedium),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () => _showEditProjectDialog(context, project, onProjectUpdated),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.description,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          Icons.meeting_room,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${project.meetings.length} 个会议',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.bottomRight,
                child: FilledButton.tonal(
                onPressed: () => Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => ProjectShellPage(project: project),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
                child: const Text('进入'),
              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}