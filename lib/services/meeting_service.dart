import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import '../models/meeting.dart';
import '../models/message_chunk.dart';
import '../models/project.dart';

class MeetingService {
  static const String _meetingsKey = 'meetory_meetings';
  static MeetingService? _instance;
  
  MeetingService._();
  
  static MeetingService get instance {
    _instance ??= MeetingService._();
    return _instance!;
  }

  // 获取所有会议记录
  Future<List<Meeting>> getAllMeetings() async {
    final prefs = await SharedPreferences.getInstance();
    final meetingsJson = prefs.getString(_meetingsKey);
    if (meetingsJson == null) return [];
    
    final List<dynamic> meetingsList = json.decode(meetingsJson);
    return meetingsList.map((json) => Meeting.fromJson(json)).toList();
  }

  // 根据项目ID获取会议记录
  Future<List<Meeting>> getMeetingsByProjectId(String projectId) async {
    final allMeetings = await getAllMeetings();
    return allMeetings.where((meeting) => meeting.projectId == projectId).toList();
  }

  // 根据ID获取单个会议
  Future<Meeting?> getMeetingById(String meetingId) async {
    final allMeetings = await getAllMeetings();
    try {
      return allMeetings.firstWhere((meeting) => meeting.id == meetingId);
    } catch (e) {
      return null;
    }
  }

  // 保存会议列表
  Future<void> _saveMeetings(List<Meeting> meetings) async {
    final prefs = await SharedPreferences.getInstance();
    final meetingsJson = json.encode(meetings.map((meeting) => meeting.toJson()).toList());
    await prefs.setString(_meetingsKey, meetingsJson);
  }

  // 保存新会议
  Future<void> saveMeeting(Meeting meeting) async {
    final meetings = await getAllMeetings();
    // 检查是否已存在相同ID的会议
    final existingIndex = meetings.indexWhere((m) => m.id == meeting.id);
    if (existingIndex != -1) {
      // 更新现有会议
      meetings[existingIndex] = meeting;
    } else {
      // 添加新会议
      meetings.add(meeting);
    }
    await _saveMeetings(meetings);
    
    // 保存会议文件到data/projects文件夹
    await _saveMeetingFiles(meeting);
  }

  // 删除会议
  Future<void> deleteMeeting(String meetingId) async {
    final meetings = await getAllMeetings();
    meetings.removeWhere((meeting) => meeting.id == meetingId);
    await _saveMeetings(meetings);
  }

  // 更新会议消息（用于实时保存聊天记录）
  Future<void> updateMeetingMessages(String meetingId, List<MessageChunk> messages) async {
    final meetings = await getAllMeetings();
    final meetingIndex = meetings.indexWhere((m) => m.id == meetingId);
    if (meetingIndex != -1) {
      final updatedMeeting = Meeting(
        id: meetings[meetingIndex].id,
        projectId: meetings[meetingIndex].projectId,
        title: meetings[meetingIndex].title,
        time: meetings[meetingIndex].time,
        tags: meetings[meetingIndex].tags,
        audioUrl: meetings[meetingIndex].audioUrl,
        messages: messages,
        config: meetings[meetingIndex].config,
        speakerMapping: meetings[meetingIndex].speakerMapping,
      );
      meetings[meetingIndex] = updatedMeeting;
      await _saveMeetings(meetings);
    }
  }

  // 更新说话人映射
  Future<void> updateSpeakerMapping(String meetingId, Map<String, String> speakerMapping) async {
    final meetings = await getAllMeetings();
    final meetingIndex = meetings.indexWhere((m) => m.id == meetingId);
    if (meetingIndex != -1) {
      final updatedMeeting = Meeting(
        id: meetings[meetingIndex].id,
        projectId: meetings[meetingIndex].projectId,
        title: meetings[meetingIndex].title,
        time: meetings[meetingIndex].time,
        tags: meetings[meetingIndex].tags,
        audioUrl: meetings[meetingIndex].audioUrl,
        messages: meetings[meetingIndex].messages,
        config: meetings[meetingIndex].config,
        speakerMapping: speakerMapping,
      );
      meetings[meetingIndex] = updatedMeeting;
      await _saveMeetings(meetings);
    }
  }

  // 搜索会议（根据标题、标签等）
  Future<List<Meeting>> searchMeetings(String query) async {
    final allMeetings = await getAllMeetings();
    final lowerQuery = query.toLowerCase();
    return allMeetings.where((meeting) {
      return meeting.title.toLowerCase().contains(lowerQuery) ||
             meeting.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  // 清空所有会议记录（用于测试或重置）
  Future<void> clearAllMeetings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_meetingsKey);
  }

  // 获取所有项目（从会议中提取）
  Future<List<Project>> getAllProjects() async {
    final meetings = await getAllMeetings();
    final Map<String, Project> projectsMap = {};
    
    for (final meeting in meetings) {
      final projectName = meeting.config?.project ?? '未分类';
      if (!projectsMap.containsKey(projectName)) {
        projectsMap[projectName] = Project(
          id: projectName.toLowerCase().replaceAll(' ', '_'),
          name: projectName,
          description: '项目 $projectName 的会议记录',
          createdAt: meeting.time,
          meetings: [],
        );
      }
      // 更新项目的创建时间为最早的会议时间
      if (meeting.time.isBefore(projectsMap[projectName]!.createdAt)) {
        projectsMap[projectName] = Project(
          id: projectsMap[projectName]!.id,
          name: projectsMap[projectName]!.name,
          description: projectsMap[projectName]!.description,
          createdAt: meeting.time,
          meetings: projectsMap[projectName]!.meetings,
        );
      }
      projectsMap[projectName]!.meetings.add(meeting);
    }
    
    return projectsMap.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
  
  // 保存会议文件到data/projects文件夹
  Future<void> _saveMeetingFiles(Meeting meeting) async {
    try {
      final projectName = meeting.config?.project ?? '未分类';
      final projectDir = path.join('data', 'projects', projectName);
      final meetingDir = path.join(projectDir, meeting.id);
      
      // 创建目录
      await Directory(meetingDir).create(recursive: true);
      
      // 保存对话列表为JSON文件
      await _saveMessagesFile(meeting, meetingDir);
      
      // 保存Markdown文件
      await _saveMarkdownFile(meeting, meetingDir);
      
    } catch (e) {
      // 静默处理文件保存错误，不影响主要功能
    }
  }
  
  // 保存对话列表为JSON文件
  Future<void> _saveMessagesFile(Meeting meeting, String meetingDir) async {
    final messagesFile = File(path.join(meetingDir, 'messages.json'));
    final messagesData = {
      'meetingId': meeting.id,
      'title': meeting.title,
      'time': meeting.time.toIso8601String(),
      'messages': meeting.messages.map((msg) => msg.toJson()).toList(),
      'speakerMapping': meeting.speakerMapping ?? {},
    };
    await messagesFile.writeAsString(json.encode(messagesData));
  }
  
  // 保存Markdown文件
  Future<void> _saveMarkdownFile(Meeting meeting, String meetingDir) async {
    final markdownFile = File(path.join(meetingDir, 'transcript.md'));
    final markdown = _generateMarkdown(meeting);
    await markdownFile.writeAsString(markdown);
  }
  
  // 生成Markdown格式的会议记录
  String _generateMarkdown(Meeting meeting) {
    final buffer = StringBuffer();
    
    // 会议标题和基本信息
    buffer.writeln('# ${meeting.title}');
    buffer.writeln();
    buffer.writeln('**时间**: ${meeting.time}');
    buffer.writeln('**项目**: ${meeting.config?.project ?? '未分类'}');
    
    if (meeting.tags.isNotEmpty) {
      buffer.writeln('**标签**: ${meeting.tags.join(', ')}');
    }
    
    if (meeting.config?.participants.isNotEmpty == true) {
      buffer.writeln('**参与者**: ${meeting.config!.participants.map((user) => user.name).join(', ')}');
    }
    
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();
    
    // 会议内容
    buffer.writeln('## 会议记录');
    buffer.writeln();
    
    for (final message in meeting.messages) {
      final speakerName = _getSpeakerDisplayName(message.speaker, meeting.speakerMapping);
      final timestamp = _formatDuration(message.start);
      buffer.writeln('**$speakerName** [$timestamp]: ${message.text}');
      buffer.writeln();
    }
    
    return buffer.toString();
  }
  
  // 获取说话人显示名称
  String _getSpeakerDisplayName(String speakerId, Map<String, String>? speakerMapping) {
    if (speakerMapping != null && speakerMapping.containsKey(speakerId)) {
      return speakerMapping[speakerId]!;
    }
    return '说话人$speakerId';
  }
  
  // 格式化时长
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  // 根据项目名称获取项目
  Future<Project?> getProjectByName(String projectName) async {
    final projects = await getAllProjects();
    try {
      return projects.firstWhere((project) => project.name == projectName);
    } catch (e) {
      return null;
    }
  }

  // 获取所有项目名称列表
  Future<List<String>> getAllProjectNames() async {
    final projects = await getAllProjects();
    return projects.map((project) => project.name).toList();
  }

  // 更新项目信息（通过更新所有相关会议的项目名称）
  Future<void> updateProject(String oldProjectName, String newProjectName, String newDescription) async {
    final meetings = await getAllMeetings();
    bool hasChanges = false;
    
    for (int i = 0; i < meetings.length; i++) {
      if (meetings[i].config?.project == oldProjectName) {
        final updatedConfig = MeetingConfig(
          subject: meetings[i].config?.subject ?? '未命名会议',
          tags: meetings[i].config?.tags ?? [],
          project: newProjectName,
          maxParticipants: meetings[i].config?.maxParticipants ?? 4,
          participants: meetings[i].config?.participants ?? [],
        );
        
        meetings[i] = Meeting(
          id: meetings[i].id,
          projectId: meetings[i].projectId,
          title: meetings[i].title,
          time: meetings[i].time,
          tags: meetings[i].tags,
          audioUrl: meetings[i].audioUrl,
          messages: meetings[i].messages,
          config: updatedConfig,
          speakerMapping: meetings[i].speakerMapping,
        );
        hasChanges = true;
      }
    }
    
    if (hasChanges) {
      await _saveMeetings(meetings);
    }
  }
}