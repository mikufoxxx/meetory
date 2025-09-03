import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/meeting.dart';
import '../models/user.dart';
import '../services/meeting_service.dart';
import '../services/user_service.dart';
import 'user_management_page.dart';

class MeetingEditPage extends StatefulWidget {
  final Meeting meeting;
  const MeetingEditPage({super.key, required this.meeting});

  @override
  State<MeetingEditPage> createState() => _MeetingEditPageState();
}

class _MeetingEditPageState extends State<MeetingEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _subjectController;
  late final TextEditingController _projectController;
  late final TextEditingController _maxParticipantsController;
  
  List<String> _tags = [];
  List<User> _selectedUsers = [];
  List<User> _allUsers = [];
  List<String> _availableProjects = [];
  List<String> _availableTags = [];
  
  @override
  void initState() {
    super.initState();
    _subjectController = TextEditingController(text: widget.meeting.title);
    _projectController = TextEditingController(text: widget.meeting.config?.project ?? '未分类');
    _maxParticipantsController = TextEditingController(
      text: widget.meeting.config?.maxParticipants.toString() ?? '4'
    );
    _tags = List.from(widget.meeting.tags);
    _selectedUsers = List.from(widget.meeting.config?.participants ?? []);
    _loadData();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _projectController.dispose();
    _maxParticipantsController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadUsers(),
      _loadProjects(),
      _loadTags(),
    ]);
  }

  Future<void> _loadUsers() async {
    try {
      final users = await UserService.instance.getAllUsers();
      setState(() => _allUsers = users);
    } catch (e) {
      debugPrint('Failed to load users: $e');
    }
  }

  Future<void> _loadProjects() async {
    try {
      final projects = await MeetingService.instance.getAllProjects();
      final projectNames = projects.map((p) => p.name).toList();
      if (!projectNames.contains('未分类')) {
        projectNames.insert(0, '未分类');
      }
      setState(() => _availableProjects = projectNames);
    } catch (e) {
      debugPrint('Failed to load projects: $e');
    }
  }

  Future<void> _loadTags() async {
    try {
      final meetings = await MeetingService.instance.getAllMeetings();
      final allTags = <String>{};
      for (final meeting in meetings) {
        allTags.addAll(meeting.tags);
      }
      setState(() => _availableTags = allTags.toList()..sort());
    } catch (e) {
      debugPrint('Failed to load tags: $e');
    }
  }

  void _showUserSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择参与者'),
        content: SizedBox(
          width: 400,
          height: 400,
          child: _allUsers.isEmpty
              ? const Center(child: Text('暂无用户，请先添加用户'))
              : ListView.builder(
                  itemCount: _allUsers.length,
                  itemBuilder: (context, index) {
                    final user = _allUsers[index];
                    final isSelected = _selectedUsers.any((u) => u.id == user.id);
                    return CheckboxListTile(
                      title: Text(user.name),
                      subtitle: user.email != null ? Text(user.email!) : null,
                      value: isSelected,
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            if (!_selectedUsers.any((u) => u.id == user.id)) {
                              _selectedUsers.add(user);
                            }
                          } else {
                            _selectedUsers.removeWhere((u) => u.id == user.id);
                          }
                        });
                        Navigator.of(context).pop();
                        _showUserSelectionDialog();
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }

  void _showCustomProjectDialog() {
    final customProjectController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('输入新项目名称'),
        content: TextField(
          controller: customProjectController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '请输入项目名称',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final projectName = customProjectController.text.trim();
              if (projectName.isNotEmpty) {
                setState(() {
                  _projectController.text = projectName;
                  if (!_availableProjects.contains(projectName)) {
                    _availableProjects.add(projectName);
                  }
                });
                Navigator.of(context).pop();
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showTagSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择标签'),
        content: SizedBox(
          width: 400,
          height: 400,
          child: Column(
            children: [
              // 添加新标签
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: '输入新标签',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (value) {
                        final tag = value.trim();
                        if (tag.isNotEmpty && !_tags.contains(tag)) {
                          setState(() => _tags.add(tag));
                          if (!_availableTags.contains(tag)) {
                            setState(() => _availableTags.add(tag));
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              // 现有标签列表
              Expanded(
                child: _availableTags.isEmpty
                    ? const Center(child: Text('暂无标签'))
                    : ListView.builder(
                        itemCount: _availableTags.length,
                        itemBuilder: (context, index) {
                          final tag = _availableTags[index];
                          final isSelected = _tags.contains(tag);
                          return CheckboxListTile(
                            title: Text(tag),
                            value: isSelected,
                            onChanged: (selected) {
                              setState(() {
                                if (selected == true) {
                                  if (!_tags.contains(tag)) {
                                    _tags.add(tag);
                                  }
                                } else {
                                  _tags.remove(tag);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveMeeting() async {
    if (!_formKey.currentState!.validate()) return;
    
    final maxParticipants = int.tryParse(_maxParticipantsController.text) ?? 4;
    if (_selectedUsers.length > maxParticipants) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('选择的参与者数量超过了最大人数限制')),
      );
      return;
    }
    
    try {
      final updatedConfig = MeetingConfig(
        subject: _subjectController.text.trim(),
        tags: _tags,
        project: _projectController.text.trim(),
        maxParticipants: maxParticipants,
        participants: _selectedUsers,
      );

      final updatedMeeting = Meeting(
        id: widget.meeting.id,
        projectId: widget.meeting.projectId,
        title: _subjectController.text.trim(),
        time: widget.meeting.time,
        tags: _tags,
        audioUrl: widget.meeting.audioUrl,
        messages: widget.meeting.messages,
        config: updatedConfig,
        speakerMapping: widget.meeting.speakerMapping,
      );

      await MeetingService.instance.saveMeeting(updatedMeeting);
      
      if (mounted) {
        Navigator.of(context).pop(updatedMeeting);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑会议信息'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => const UserManagementPage(),
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
              ).then((_) => _loadUsers());
            },
            icon: const Icon(Icons.people),
            tooltip: '用户管理',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 会议主题
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '会议主题',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _subjectController,
                      decoration: const InputDecoration(
                        hintText: '请输入会议主题',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入会议主题';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 项目设置
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '项目设置',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _availableProjects.contains(_projectController.text) 
                          ? _projectController.text 
                          : null,
                      decoration: const InputDecoration(
                        hintText: '选择项目',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        ..._availableProjects.map((project) {
                          return DropdownMenuItem(
                            value: project,
                            child: Text(project),
                          );
                        }),
                        const DropdownMenuItem(
                          value: '__custom__',
                          child: Text('+ 输入新项目名称'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == '__custom__') {
                          _showCustomProjectDialog();
                        } else if (value != null) {
                          _projectController.text = value;
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 参与者设置
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '参与者设置',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        Text(
                          '${_selectedUsers.length}/${_maxParticipantsController.text}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _maxParticipantsController,
                      decoration: const InputDecoration(
                        labelText: '最大参与人数',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        final num = int.tryParse(value ?? '');
                        if (num == null || num < 1) {
                          return '请输入有效的人数';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_allUsers.isEmpty)
                      Column(
                        children: [
                          const Text('暂无用户，请先添加用户'),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                PageRouteBuilder(
                                  pageBuilder: (context, animation, secondaryAnimation) => const UserManagementPage(),
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
                              ).then((_) => _loadUsers());
                            },
                            icon: const Icon(Icons.person_add),
                            label: const Text('添加用户'),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _showUserSelectionDialog,
                            icon: const Icon(Icons.people),
                            label: const Text('选择参与者'),
                          ),
                          if (_selectedUsers.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            ..._selectedUsers.map((user) {
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                    child: Text(
                                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(user.name),
                                  subtitle: user.email != null ? Text(user.email!) : null,
                                  trailing: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _selectedUsers.removeWhere((u) => u.id == user.id);
                                      });
                                    },
                                    icon: const Icon(Icons.remove_circle_outline),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 标签设置
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '标签设置',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _showTagSelectionDialog,
                      icon: const Icon(Icons.label),
                      label: const Text('选择标签'),
                    ),
                    if (_tags.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _tags.map((tag) {
                          return Chip(
                            label: Text(tag),
                            onDeleted: () {
                              setState(() => _tags.remove(tag));
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton(
                onPressed: _saveMeeting,
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}