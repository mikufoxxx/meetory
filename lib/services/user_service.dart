import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class UserService {
  static const String _usersKey = 'meetory_users';
  static UserService? _instance;
  
  UserService._();
  
  static UserService get instance {
    _instance ??= UserService._();
    return _instance!;
  }

  // 获取所有用户
  Future<List<User>> getAllUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString(_usersKey);
    if (usersJson == null) return [];
    
    final List<dynamic> usersList = json.decode(usersJson);
    return usersList.map((json) => User.fromJson(json)).toList();
  }

  // 保存用户列表
  Future<void> _saveUsers(List<User> users) async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = json.encode(users.map((user) => user.toJson()).toList());
    await prefs.setString(_usersKey, usersJson);
  }

  // 添加用户
  Future<void> addUser(User user) async {
    final users = await getAllUsers();
    // 检查是否已存在相同ID的用户
    if (users.any((u) => u.id == user.id)) {
      throw Exception('用户ID已存在');
    }
    // 检查是否已存在相同名称的用户
    if (users.any((u) => u.name == user.name)) {
      throw Exception('用户名已存在');
    }
    users.add(user);
    await _saveUsers(users);
  }

  // 更新用户
  Future<void> updateUser(User user) async {
    final users = await getAllUsers();
    final index = users.indexWhere((u) => u.id == user.id);
    if (index == -1) {
      throw Exception('用户不存在');
    }
    // 检查名称是否与其他用户冲突
    if (users.any((u) => u.id != user.id && u.name == user.name)) {
      throw Exception('用户名已存在');
    }
    users[index] = user;
    await _saveUsers(users);
  }

  // 删除用户
  Future<void> deleteUser(String userId) async {
    final users = await getAllUsers();
    users.removeWhere((u) => u.id == userId);
    await _saveUsers(users);
  }

  // 根据ID获取用户
  Future<User?> getUserById(String userId) async {
    final users = await getAllUsers();
    try {
      return users.firstWhere((u) => u.id == userId);
    } catch (e) {
      return null;
    }
  }

  // 根据名称搜索用户
  Future<List<User>> searchUsersByName(String name) async {
    final users = await getAllUsers();
    return users.where((u) => u.name.toLowerCase().contains(name.toLowerCase())).toList();
  }

  // 生成唯一ID
  String generateUserId() {
    return 'user_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }
}