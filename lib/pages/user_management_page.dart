import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/user_service.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final UserService _userService = UserService.instance;
  List<User> _users = [];
  bool _loading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final users = await _userService.getAllUsers();
      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载用户失败: $e')),
        );
      }
    }
  }

  List<User> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;
    return _users.where((user) => 
      user.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      (user.email?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
    ).toList();
  }

  Future<void> _showAddUserDialog([User? editUser]) async {
    final nameController = TextEditingController(text: editUser?.name ?? '');
    final emailController = TextEditingController(text: editUser?.email ?? '');
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(editUser == null ? '添加用户' : '编辑用户'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '姓名',
                hintText: '请输入用户姓名',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: '邮箱（可选）',
                hintText: '请输入邮箱地址',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入用户姓名')),
                );
                return;
              }
              
              try {
                final user = User(
                  id: editUser?.id ?? _userService.generateUserId(),
                  name: name,
                  email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                  createdAt: editUser?.createdAt ?? DateTime.now(),
                );
                
                if (editUser == null) {
                  await _userService.addUser(user);
                } else {
                  await _userService.updateUser(user);
                }
                
                // ignore: use_build_context_synchronously
                Navigator.of(context).pop(true);
              } catch (e) {
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('操作失败: $e')),
                );
              }
            },
            child: Text(editUser == null ? '添加' : '保存'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      _loadUsers();
    }
  }

  Future<void> _deleteUser(User user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除用户「${user.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await _userService.deleteUser(user.id);
        _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已删除用户「${user.name}」')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('用户管理'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索用户姓名或邮箱',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        icon: const Icon(Icons.clear),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _filteredUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _searchQuery.isEmpty ? Icons.people_outline : Icons.search_off,
                        size: 64,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty ? '暂无用户' : '未找到匹配的用户',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      if (_searchQuery.isEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '点击右下角按钮添加用户',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    // 响应式网格布局
                    int crossAxisCount;
                    double childAspectRatio;
                    
                    if (constraints.maxWidth > 1200) {
                      crossAxisCount = 4;
                      childAspectRatio = 1.2;
                    } else if (constraints.maxWidth > 800) {
                      crossAxisCount = 3;
                      childAspectRatio = 1.1;
                    } else if (constraints.maxWidth > 600) {
                      crossAxisCount = 2;
                      childAspectRatio = 1.0;
                    } else {
                      crossAxisCount = 1;
                      childAspectRatio = 2.5;
                    }
                    
                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: childAspectRatio,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = _filteredUsers[index];
                        return _UserCard(
                          user: user,
                          onEdit: () => _showAddUserDialog(user),
                          onDelete: () => _deleteUser(user),
                        );
                      },
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddUserDialog(),
        child: const Icon(Icons.person_add),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final User user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  
  const _UserCard({
    required this.user,
    required this.onEdit,
    required this.onDelete,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 用户头像
              CircleAvatar(
                radius: 32,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // 用户姓名
              Text(
                user.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              
              // 用户邮箱
              if (user.email != null) ...[
                const SizedBox(height: 4),
                Text(
                  user.email!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              
              const SizedBox(height: 12),
              
              // 操作按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: '编辑',
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                      foregroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: '删除',
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}