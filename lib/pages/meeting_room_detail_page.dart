import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bonsoir/bonsoir.dart';
import '../models/meeting.dart';
import '../models/message_chunk.dart';
import '../services/meeting_service.dart';
import '../providers/asr_provider.dart';
import '../widgets/floating_recording_widget.dart';

class MeetingRoomDetailPage extends StatefulWidget {
  final String roomName;
  final String host;
  final int port;
  final MeetingConfig? config;
  
  const MeetingRoomDetailPage({
    super.key, 
    required this.roomName, 
    required this.host, 
    required this.port,
    this.config,
  });
  
  @override
  State<MeetingRoomDetailPage> createState() => _MeetingRoomDetailPageState();
}

class _MeetingRoomDetailPageState extends State<MeetingRoomDetailPage> {
  final Map<String, String> _speakerMapping = {}; // 说话人ID到用户ID的映射
  final List<MessageChunk> _messages = [];
  final ScrollController _scrollController = ScrollController();
  late final String _meetingId;
  DateTime? _meetingStartTime;
  BonsoirBroadcast? _broadcast;
  static const String _serviceType = '_wonderful-service._tcp';
  
  @override
  void initState() {
    super.initState();
    _meetingId = 'meeting_${DateTime.now().millisecondsSinceEpoch}';
    _startBroadcast();
  }

  @override
  void dispose() {
    _stopBroadcast();
    _scrollController.dispose();
    super.dispose();
  }
  
  // 启动广播服务
  Future<void> _startBroadcast() async {
    if (kIsWeb) return; // Web平台不支持Bonjour
    
    try {
      final service = BonsoirService(
        name: widget.roomName,
        type: _serviceType,
        port: widget.port,
      );
      
      _broadcast = BonsoirBroadcast(service: service);
      await _broadcast!.ready;
      await _broadcast!.start();
    } catch (e) {
      // 静默处理广播启动错误
    }
  }
  
  // 停止广播服务
  Future<void> _stopBroadcast() async {
    try {
      await _broadcast?.stop();
    } catch (_) {}
    _broadcast = null;
  }
  
  // 保存会议记录
  Future<void> _saveMeetingRecord() async {
    if (_meetingStartTime == null) return;
    
    // 获取录音文件路径
    final asrProvider = Provider.of<AsrProvider>(context, listen: false);
    final audioUrl = asrProvider.currentRecordingPath ?? '';
    
    final meeting = Meeting(
      id: _meetingId,
      projectId: widget.config?.project ?? '未分类',
      title: widget.config?.subject ?? widget.roomName,
      time: _meetingStartTime!,
      tags: widget.config?.tags ?? [],
      audioUrl: audioUrl,
      messages: _messages,
      config: widget.config,
      speakerMapping: _speakerMapping.isNotEmpty ? _speakerMapping : null,
    );
    
    try {
      await MeetingService.instance.saveMeeting(meeting);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存会议记录失败：$e')),
        );
      }
    }
  }
  
  // 保存说话人映射
  Future<void> _saveSpeakerMapping() async {
    if (_speakerMapping.isNotEmpty) {
      try {
        await MeetingService.instance.updateSpeakerMapping(_meetingId, _speakerMapping);
      } catch (e) {
        // 静默处理错误，避免影响用户体验
      }
    }
  }
  
  // 保存消息更新
  Future<void> _saveMessages() async {
    if (_messages.isNotEmpty) {
      try {
        await MeetingService.instance.updateMeetingMessages(_meetingId, _messages);
      } catch (e) {
        // 静默处理错误，避免影响用户体验
      }
    }
  }

  void _showSpeakerMappingDialog() {
    if (widget.config == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未配置会议参与者')),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => _SpeakerMappingDialog(
        config: widget.config!,
        currentMapping: _speakerMapping,
        onMappingChanged: (mapping) {
          setState(() {
            _speakerMapping.clear();
            _speakerMapping.addAll(mapping);
          });
          _saveSpeakerMapping();
        },
      ),
    );
  }
  
  String _getSpeakerDisplayName(String speakerId) {
    final userId = _speakerMapping[speakerId];
    if (userId != null && widget.config != null) {
      final user = widget.config!.participants.where((u) => u.id == userId).firstOrNull;
      if (user != null) {
        return user.name;
      }
    }
    return speakerId;
  }
  
  Color _getSpeakerColor(String speakerId) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];
    final hash = speakerId.hashCode;
    return colors[hash.abs() % colors.length];
  }
  
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final asr = context.watch<AsrProvider>();
    
    // 监听ASR输出变化，更新消息列表
    if (asr.lines.isNotEmpty) {
      // 这里应该从ASR Provider获取带说话人信息的消息
      // 暂时使用简单的转换逻辑
      final newMessages = <MessageChunk>[];
      for (int i = _messages.length; i < asr.lines.length; i++) {
        final line = asr.lines[i];
        // 解析说话人信息（假设格式为 "[S1] 文本内容"）
        final match = RegExp(r'^\[S(\d+)\]\s*(.*)').firstMatch(line);
        if (match != null) {
          final speakerId = 'S${match.group(1)}';
          final text = match.group(2) ?? '';
          newMessages.add(MessageChunk(
            speaker: speakerId,
            text: text,
            start: Duration.zero, // 实际应该从ASR获取时间戳
            end: Duration.zero,
          ));
        } else {
          newMessages.add(MessageChunk(
            speaker: 'S1',
            text: line,
            start: Duration.zero,
            end: Duration.zero,
          ));
        }
      }
      
      if (newMessages.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {
            _messages.addAll(newMessages);
          });
          _scrollToBottom();
          // 自动保存消息更新
          _saveMessages();
        });
      }
    }
    
    // ignore: deprecated_member_use
    return WillPopScope(
       onWillPop: () async {
         // 返回按钮不结束会议，如果正在录音则显示浮动窗口
         final asr = context.read<AsrProvider>();
         if (asr.running) {
           FloatingRecordingOverlay.show(
             context,
             meetingConfig: widget.config,
             onTap: () {
               FloatingRecordingOverlay.hide();
               Navigator.of(context).push(
                 PageRouteBuilder(
                   pageBuilder: (context, animation, secondaryAnimation) => MeetingRoomDetailPage(
                     roomName: widget.roomName,
                     host: widget.host,
                     port: widget.port,
                     config: widget.config,
                   ),
                   transitionsBuilder: (context, animation, secondaryAnimation, child) {
                     return FadeTransition(
                       opacity: animation,
                       child: child,
                     );
                   },
                   transitionDuration: const Duration(milliseconds: 300),
                 ),
               );
             },
           );
         }
         return true;
       },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
             icon: const Icon(Icons.arrow_back),
             onPressed: () {
               // 返回按钮不结束会议，如果正在录音则显示浮动窗口
               final asr = context.read<AsrProvider>();
               if (asr.running) {
                 FloatingRecordingOverlay.show(
                   context,
                   meetingConfig: widget.config,
                   onTap: () {
                     FloatingRecordingOverlay.hide();
                     // 使用全局导航器来避免context失效问题
                     final navigatorState = Navigator.of(context, rootNavigator: true);
                     navigatorState.push(
                       PageRouteBuilder(
                         pageBuilder: (context, animation, secondaryAnimation) => MeetingRoomDetailPage(
                           roomName: widget.roomName,
                           host: widget.host,
                           port: widget.port,
                           config: widget.config,
                         ),
                         transitionsBuilder: (context, animation, secondaryAnimation, child) {
                           return FadeTransition(
                             opacity: animation,
                             child: child,
                           );
                         },
                         transitionDuration: const Duration(milliseconds: 300),
                       ),
                     );
                   },
                 );
               }
               Navigator.of(context).pop();
             },
           ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.roomName),
            if (widget.config != null)
              Text(
                widget.config!.subject,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          if (widget.config != null)
            IconButton(
              onPressed: _showSpeakerMappingDialog,
              icon: const Icon(Icons.people),
              tooltip: '说话人映射',
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'info':
                  _showMeetingInfo();
                  break;
                case 'export':
                  _exportTranscript();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'info',
                child: ListTile(
                  leading: Icon(Icons.info),
                  title: Text('会议信息'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('导出记录'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: Consumer<AsrProvider>(builder: (context, asr, _) {
        if (!asr.running) return const SizedBox.shrink();
        return FloatingActionButton.extended(
          onPressed: () async {
            // 显示确认对话框
            final shouldEnd = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('结束会议'),
                content: const Text('确定要结束当前会议吗？会议记录将被保存。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('结束会议'),
                  ),
                ],
              ),
            );
            
            if (shouldEnd == true) {
              // 停止录音
              // ignore: use_build_context_synchronously
              context.read<AsrProvider>().stop();
              setState(() {});
              // 保存最终的会议记录
              await _saveMeetingRecord();
              // 隐藏悬浮窗口（如果存在）
              FloatingRecordingOverlay.hide();
              // 返回上一页
              if (mounted) {
                // ignore: use_build_context_synchronously
                Navigator.of(context).pop();
              }
            }
          },
          backgroundColor: Theme.of(context).colorScheme.error,
          foregroundColor: Theme.of(context).colorScheme.onError,
          icon: const Icon(Icons.stop),
          label: const Text('结束会议'),
        );
      }),
      body: Column(
        children: [
          // 控制面板
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Column(
              children: [
                if (asr.loadingModel)
                  const LinearProgressIndicator(minHeight: 3),
                if (asr.loadingModel) const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.wifi_tethering, size: 18),
                    const SizedBox(width: 6),
                    Text('${widget.host}:${widget.port}', style: Theme.of(context).textTheme.bodyMedium),
                    const Spacer(),
                    if (widget.config != null) ...[
                      Chip(
                        label: Text('${widget.config!.participants.length}人'),
                        avatar: const Icon(Icons.people, size: 16),
                      ),
                      const SizedBox(width: 8),
                    ],
                    OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('连接服务器（占位）')),
                        );
                      },
                      icon: const Icon(Icons.link),
                      label: const Text('连接'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: (asr.running || asr.loadingModel)
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final asrProvider = context.read<AsrProvider>();

                              if (kIsWeb) {
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('当前为 Web 端，暂不支持本地 ASR（sherpa_onnx）。请在 Windows/macOS/Android/iOS 运行。')),
                                );
                                return;
                              }
                              
                              // 设置说话人数量限制
                              if (widget.config != null) {
                                asrProvider.setMaxSpeakers(widget.config!.maxParticipants);
                                asrProvider.resetSpeakers(); // 重置说话人聚类
                              }
                              
                              // 预加载模型（带进度与错误状态）
                              final ok = await asrProvider.loadDefaultModelWithProgress();
                              if (!ok && asrProvider.lastError != null) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text('模型加载失败：${asrProvider.lastError}')),
                                );
                                return;
                              }
                              
                              // 记录会议开始时间并开始录音
                              setState(() {
                                _meetingStartTime = DateTime.now();
                              });
                              
                              // 开始录音到文件
                              final projectName = widget.config?.project ?? '未分类';
                              await asrProvider.startRecordingToFile(projectName, _meetingId);
                              
                              await asrProvider.start();
                              
                              // 显示悬浮录音窗口
                              if (widget.config != null) {
                                FloatingRecordingOverlay.show(
                                  // ignore: use_build_context_synchronously
                                  context,
                                  meetingConfig: widget.config,
                                  onTap: () {
                                    // 点击悬浮窗口时返回到会议详情页面
                                    FloatingRecordingOverlay.hide();
                                  },
                                );
                              }
                              
                              // 创建初始会议记录
                              await _saveMeetingRecord();
                            },
                      icon: asr.loadingModel
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.mic),
                      label: Text(asr.loadingModel ? '初始化模型…' : '开始录音'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: asr.running ? () async {
                        final asrProvider = context.read<AsrProvider>();
                        asrProvider.stop();
                        // 停止录音到文件
                        await asrProvider.stopRecordingToFile();
                        setState(() {
                        });
                        // 保存最终的会议记录
                        await _saveMeetingRecord();
                      } : null,
                      icon: const Icon(Icons.stop),
                      label: const Text('停止'),
                    ),
                  ],
                ),
                if (asr.lastError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '错误：${asr.lastError}',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
          
          // 聊天界面
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.mic_none,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '点击开始录音开始会议',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        if (widget.config != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            '已配置 ${widget.config!.participants.length} 位参与者',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final speakerColor = _getSpeakerColor(message.speaker);
                      final displayName = _getSpeakerDisplayName(message.speaker);
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: speakerColor.withValues(alpha: 0.2),
                              child: Text(
                                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                style: TextStyle(
                                  color: speakerColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        displayName,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: speakerColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        DateTime.now().toString().substring(11, 19), // 临时时间戳
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      message.text,
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
    );
  }
  
  void _showMeetingInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('会议信息'),
        content: widget.config != null
            ? SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '会议配置详情',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _InfoRow('主题', widget.config!.subject),
                            _InfoRow('项目', widget.config!.project),
                            _InfoRow('最大人数', '${widget.config!.maxParticipants}人'),
                            if (widget.config!.tags.isNotEmpty)
                              _InfoRow('标签', widget.config!.tags.join(', ')),
                          ],
                        ),
                      ),
                    ),
                    if (widget.config!.participants.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '参与者 (${widget.config!.participants.length})',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              ...widget.config!.participants.map((user) => 
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                        child: Text(
                                          user.name[0].toUpperCase(),
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        user.name,
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            : const Text('未配置会议信息'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
  
  void _exportTranscript() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('导出功能开发中...')),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  
  const _InfoRow(this.label, this.value);
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeakerMappingDialog extends StatefulWidget {
  final MeetingConfig config;
  final Map<String, String> currentMapping;
  final Function(Map<String, String>) onMappingChanged;
  
  const _SpeakerMappingDialog({
    required this.config,
    required this.currentMapping,
    required this.onMappingChanged,
  });
  
  @override
  State<_SpeakerMappingDialog> createState() => _SpeakerMappingDialogState();
}

class _SpeakerMappingDialogState extends State<_SpeakerMappingDialog> {
  late Map<String, String> _mapping;
  
  @override
  void initState() {
    super.initState();
    _mapping = Map.from(widget.currentMapping);
  }
  
  @override
  Widget build(BuildContext context) {
    // 获取已检测到的说话人
    final asr = Provider.of<AsrProvider>(context, listen: false);
    final detectedSpeakers = asr.detectedSpeakers.isNotEmpty 
        ? asr.detectedSpeakers 
        : List.generate(widget.config.participants.length, (index) => 'S${index + 1}'); // 根据实际参与者数量生成说话人选项
    
    return AlertDialog(
      title: const Text('说话人映射'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '将检测到的说话人与实际参与者进行对应',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            ...detectedSpeakers.map((speakerId) {
              final currentUserId = _mapping[speakerId];

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      speakerId,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  title: Text('说话人 $speakerId'),
                  trailing: DropdownButton<String?>(
                    value: currentUserId,
                    hint: const Text('选择用户'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('未分配'),
                      ),
                      ...widget.config.participants.map((user) {
                        return DropdownMenuItem<String?>(
                          value: user.id,
                          child: Text(user.name),
                        );
                      }),
                    ],
                    onChanged: (userId) {
                      setState(() {
                        if (userId == null) {
                          _mapping.remove(speakerId);
                        } else {
                          _mapping[speakerId] = userId;
                        }
                      });
                    },
                  ),
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            widget.onMappingChanged(_mapping);
            Navigator.of(context).pop();
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}