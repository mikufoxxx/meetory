import 'message_chunk.dart';
import 'user.dart';

class MeetingConfig {
  final String subject;
  final List<String> tags;
  final String project;
  final int maxParticipants;
  final List<User> participants;
  
  const MeetingConfig({
    required this.subject,
    required this.tags,
    required this.project,
    required this.maxParticipants,
    required this.participants,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'subject': subject,
      'tags': tags,
      'project': project,
      'maxParticipants': maxParticipants,
      'participants': participants.map((p) => p.toJson()).toList(),
    };
  }
  
  factory MeetingConfig.fromJson(Map<String, dynamic> json) {
    return MeetingConfig(
      subject: json['subject'] as String? ?? '未命名会议',
      tags: json['tags'] != null 
          ? List<String>.from(json['tags'] as List)
          : [],
      project: json['project'] as String? ?? '未分类',
      maxParticipants: json['maxParticipants'] as int? ?? 4,
      participants: json['participants'] != null
          ? (json['participants'] as List)
              .map((p) => User.fromJson(p as Map<String, dynamic>))
              .toList()
          : [],
    );
  }
}

class Meeting {
  final String id;
  final String projectId;
  final String title;
  final DateTime time;
  final List<String> tags;
  final String audioUrl;
  final List<MessageChunk> messages;
  final MeetingConfig? config;
  final Map<String, String>? speakerMapping; // 说话人ID到用户ID的映射

  const Meeting({
    required this.id,
    required this.projectId,
    required this.title,
    required this.time,
    required this.tags,
    required this.audioUrl,
    required this.messages,
    this.config,
    this.speakerMapping,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'title': title,
      'time': time.toIso8601String(),
      'tags': tags,
      'audioUrl': audioUrl,
      'messages': messages.map((m) => m.toJson()).toList(),
      'config': config?.toJson(),
      'speakerMapping': speakerMapping,
    };
  }
  
  factory Meeting.fromJson(Map<String, dynamic> json) {
    return Meeting(
      id: json['id'] as String? ?? '',
      projectId: json['projectId'] as String? ?? '未分类',
      title: json['title'] as String? ?? '未命名会议',
      time: json['time'] != null 
          ? DateTime.parse(json['time'] as String)
          : DateTime.now(),
      tags: json['tags'] != null 
          ? List<String>.from(json['tags'] as List)
          : [],
      audioUrl: json['audioUrl'] as String? ?? '',
      messages: json['messages'] != null
          ? (json['messages'] as List)
              .map((m) => MessageChunk.fromJson(m as Map<String, dynamic>))
              .toList()
          : [],
      config: json['config'] != null 
          ? MeetingConfig.fromJson(json['config'] as Map<String, dynamic>)
          : null,
      speakerMapping: json['speakerMapping'] != null
          ? Map<String, String>.from(json['speakerMapping'] as Map)
          : null,
    );
  }
}
