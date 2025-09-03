import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user.dart';
import '../models/meeting.dart';
import '../services/user_service.dart';
import '../services/meeting_service.dart';
import 'meeting_room_detail_page.dart';
import 'user_management_page.dart';

class MeetingRoomConfigPage extends StatefulWidget {
  const MeetingRoomConfigPage({super.key});

  @override
  State<MeetingRoomConfigPage> createState() => _MeetingRoomConfigPageState();
}

class _MeetingRoomConfigPageState extends State<MeetingRoomConfigPage> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _tagController = TextEditingController();
  final _maxParticipantsController = TextEditingController(text: '4');

  final _projectController = TextEditingController();

  final List<String> _tags = [];
  List<User> _availableUsers = [];
  List<User> _selectedUsers = [];
  bool _loadingUsers = false;

  List<String> _availableProjects = [];
  bool _loadingProjects = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadProjects();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _tagController.dispose();
    _maxParticipantsController.dispose();
    _projectController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
    try {
      final users = await UserService.instance.getAllUsers();
      setState(() {
        _availableUsers = users;
        _loadingUsers = false;
      });
    } catch (e) {
      setState(() => _loadingUsers = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载用户失败: $e')),
        );
      }
    }
  }

  Future<void> _loadProjects() async {
    setState(() => _loadingProjects = true);
    try {
      final projectNames = await MeetingService.instance.getAllProjectNames();
      setState(() {
        _availableProjects = projectNames;
        _loadingProjects = false;
      });
    } catch (e) {
      setState(() => _loadingProjects = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载项目失败: $e')),
        );
      }
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  void _showUserSelectionDialog() async {
    final result = await showDialog<List<User>>(
      context: context,
      builder: (context) => _UserSelectionDialog(
        availableUsers: _availableUsers,
        selectedUsers: _selectedUsers,
        maxParticipants: int.tryParse(_maxParticipantsController.text) ?? 4,
      ),
    );

    if (result != null) {
      setState(() {
        _selectedUsers = result;
      });
    }
  }

  void _createMeetingRoom() {
    if (!_formKey.currentState!.validate()) return;

    final maxParticipants = int.tryParse(_maxParticipantsController.text) ?? 4;
    if (_selectedUsers.length > maxParticipants) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('选择的参与者数量超过了最大人数限制')),
      );
      return;
    }

    final config = MeetingConfig(
      subject: _subjectController.text.trim(),
      tags: _tags,
      project: _projectController.text.trim(),
      maxParticipants: maxParticipants,
      participants: _selectedUsers,
    );

    // 生成会议室名称
    final roomName =
        'Meetory #${DateTime.now().millisecondsSinceEpoch % 10000}';

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            MeetingRoomDetailPage(
          roomName: roomName,
          host: '127.0.0.1',
          port: 3030,
          config: config,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 1.0),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('创建会议室'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context)
                  .push(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const UserManagementPage(),
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
                  )
                  .then((_) => _loadUsers());
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

            // 项目名称
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '项目名称',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _loadingProjects
                        ? const Center(child: CircularProgressIndicator())
                        : DropdownButtonFormField<String>(
                            value: _projectController.text.isEmpty
                                ? null
                                : _projectController.text,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: '选择或输入项目名称',
                            ),
                            items: [
                              ..._availableProjects
                                  .map((project) => DropdownMenuItem(
                                        value: project,
                                        child: Text(project),
                                      )),
                              const DropdownMenuItem(
                                value: '__custom__',
                                child: Text('+ 输入新项目名称'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == '__custom__') {
                                _showCustomProjectDialog();
                              } else if (value != null) {
                                setState(() {
                                  _projectController.text = value;
                                });
                              }
                            },
                            validator: (value) {
                              if (_projectController.text.trim().isEmpty) {
                                return '请选择或输入项目名称';
                              }
                              return null;
                            },
                          ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 标签
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '标签',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _tagController,
                            decoration: const InputDecoration(
                              hintText: '添加标签',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _addTag(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _addTag,
                          child: const Text('添加'),
                        ),
                      ],
                    ),
                    if (_tags.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _tags.map((tag) {
                          return Chip(
                            label: Text(tag),
                            deleteIcon: const Icon(Icons.close, size: 18),
                            onDeleted: () => _removeTag(tag),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 最大人数
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '最大人数',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _maxParticipantsController,
                      decoration: const InputDecoration(
                        hintText: '请输入最大参与人数',
                        border: OutlineInputBorder(),
                        suffixText: '人',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入最大参与人数';
                        }
                        final num = int.tryParse(value);
                        if (num == null || num < 1 || num > 20) {
                          return '人数必须在1-20之间';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 参与者选择
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '参与者',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        Text(
                          '${_selectedUsers.length}/${_maxParticipantsController.text}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_loadingUsers)
                      const Center(child: CircularProgressIndicator())
                    else if (_availableUsers.isEmpty)
                      Column(
                        children: [
                          Text(
                            '暂无可选用户',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context)
                                  .push(
                                    PageRouteBuilder(
                                      pageBuilder: (context, animation,
                                              secondaryAnimation) =>
                                          const UserManagementPage(),
                                      transitionsBuilder: (context, animation,
                                          secondaryAnimation, child) {
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
                                      transitionDuration:
                                          const Duration(milliseconds: 300),
                                    ),
                                  )
                                  .then((_) => _loadUsers());
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
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  child: Text(
                                    user.name.isNotEmpty
                                        ? user.name[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer,
                                    ),
                                  ),
                                ),
                                title: Text(user.name),
                                subtitle: user.email != null
                                    ? Text(user.email!)
                                    : null,
                                trailing: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedUsers.remove(user);
                                    });
                                  },
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                contentPadding: EdgeInsets.zero,
                              );
                            }),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // 创建按钮
            FilledButton(
              onPressed: _createMeetingRoom,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('创建会议室'),
            ),
          ],
        ),
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
}

class _UserSelectionDialog extends StatefulWidget {
  final List<User> availableUsers;
  final List<User> selectedUsers;
  final int maxParticipants;

  const _UserSelectionDialog({
    required this.availableUsers,
    required this.selectedUsers,
    required this.maxParticipants,
  });

  @override
  State<_UserSelectionDialog> createState() => _UserSelectionDialogState();
}

class _UserSelectionDialogState extends State<_UserSelectionDialog> {
  late List<User> _selectedUsers;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedUsers = List.from(widget.selectedUsers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<User> get _filteredUsers {
    if (_searchQuery.isEmpty) return widget.availableUsers;
    return widget.availableUsers
        .where((user) =>
            user.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (user.email?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
                false))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('选择参与者 (${_selectedUsers.length}/${widget.maxParticipants})'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: '搜索用户',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredUsers.length,
                itemBuilder: (context, index) {
                  final user = _filteredUsers[index];
                  final isSelected = _selectedUsers.contains(user);
                  final canSelect = isSelected ||
                      _selectedUsers.length < widget.maxParticipants;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    title: Text(user.name),
                    subtitle: user.email != null ? Text(user.email!) : null,
                    trailing: Checkbox(
                      value: isSelected,
                      onChanged: canSelect
                          ? (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedUsers.add(user);
                                } else {
                                  _selectedUsers.remove(user);
                                }
                              });
                            }
                          : null,
                    ),
                    onTap: canSelect
                        ? () {
                            setState(() {
                              if (isSelected) {
                                _selectedUsers.remove(user);
                              } else {
                                _selectedUsers.add(user);
                              }
                            });
                          }
                        : null,
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
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selectedUsers),
          child: const Text('确定'),
        ),
      ],
    );
  }
}
