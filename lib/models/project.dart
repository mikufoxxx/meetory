import 'meeting.dart';

class Project {
  final String id;
  final String name;
  final String description;
  final DateTime createdAt;
  final List<Meeting> meetings;
  
  const Project({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    this.meetings = const [],
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'meetings': meetings.map((m) => m.toJson()).toList(),
    };
  }
  
  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '未命名项目',
      description: json['description'] as String? ?? '暂无描述',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      meetings: json['meetings'] != null
          ? (json['meetings'] as List)
              .map((m) => Meeting.fromJson(m as Map<String, dynamic>))
              .toList()
          : [],
    );
  }
  
  Project copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? createdAt,
    List<Meeting>? meetings,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      meetings: meetings ?? this.meetings,
    );
  }
}