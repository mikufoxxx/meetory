import 'package:flutter/material.dart';
import '../models/meeting.dart';

class MeetingPlaybackPage extends StatefulWidget {
  final Meeting meeting;
  
  const MeetingPlaybackPage({super.key, required this.meeting});

  @override
  State<MeetingPlaybackPage> createState() => _MeetingPlaybackPageState();
}

class _MeetingPlaybackPageState extends State<MeetingPlaybackPage> {
  final ScrollController _scrollController = ScrollController();
  int _currentMessageIndex = 0;
  bool _autoScroll = true;
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToMessage(int index) {
    if (_autoScroll && _scrollController.hasClients) {
      final itemHeight = 80.0; // 估算的消息项高度
      final targetOffset = index * itemHeight;
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  String _getSpeakerDisplayName(String speakerId) {
    if (widget.meeting.speakerMapping != null) {
      final userId = widget.meeting.speakerMapping![speakerId];
      if (userId != null && widget.meeting.config != null) {
        final user = widget.meeting.config!.participants
            .where((u) => u.id == userId)
            .firstOrNull;
        if (user != null) {
          return user.name;
        }
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

  void _exportTranscript() {
    final transcript = StringBuffer();
    transcript.writeln('会议记录：${widget.meeting.title}');
    transcript.writeln('时间：${widget.meeting.time}');
    if (widget.meeting.tags.isNotEmpty) {
      transcript.writeln('标签：${widget.meeting.tags.join(', ')}');
    }
    transcript.writeln('\n--- 会议内容 ---\n');
    
    for (final message in widget.meeting.messages) {
      final speakerName = _getSpeakerDisplayName(message.speaker);
      transcript.writeln('$speakerName: ${message.text}');
    }
    
    // 这里可以实现实际的导出功能，比如保存到文件或分享
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('导出功能开发中...')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.meeting.title),
            Text(
              _formatDateTime(widget.meeting.time),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
            icon: Icon(_autoScroll ? Icons.lock : Icons.lock_open),
            tooltip: _autoScroll ? '关闭自动滚动' : '开启自动滚动',
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
      body: Column(
        children: [
          // 会议统计信息
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
            child: Row(
              children: [
                _StatCard(
                  icon: Icons.message,
                  label: '消息数',
                  value: '${widget.meeting.messages.length}',
                ),
                const SizedBox(width: 16),
                if (widget.meeting.speakerMapping != null)
                  _StatCard(
                    icon: Icons.people,
                    label: '说话人',
                    value: '${widget.meeting.speakerMapping!.length}',
                  ),
                if (widget.meeting.speakerMapping != null)
                  const SizedBox(width: 16),
                if (widget.meeting.tags.isNotEmpty)
                  _StatCard(
                    icon: Icons.label,
                    label: '标签',
                    value: '${widget.meeting.tags.length}',
                  ),
                const Spacer(),
                if (widget.meeting.messages.isNotEmpty)
                  Text(
                    '${_currentMessageIndex + 1} / ${widget.meeting.messages.length}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
              ],
            ),
          ),
          
          // 消息列表
          Expanded(
            child: widget.meeting.messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '此会议没有记录消息',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: widget.meeting.messages.length,
                    itemBuilder: (context, index) {
                      final message = widget.meeting.messages[index];
                      final speakerColor = _getSpeakerColor(message.speaker);
                      final displayName = _getSpeakerDisplayName(message.speaker);
                      final isCurrentMessage = index == _currentMessageIndex;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: isCurrentMessage
                            ? BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              )
                            : null,
                        child: Padding(
                          padding: EdgeInsets.all(isCurrentMessage ? 8 : 0),
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
                                          '#${index + 1}',
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
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      
      // 底部控制栏（如果有多条消息）
      bottomNavigationBar: widget.meeting.messages.length > 1
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _currentMessageIndex > 0
                        ? () {
                            setState(() => _currentMessageIndex--);
                            _scrollToMessage(_currentMessageIndex);
                          }
                        : null,
                    icon: const Icon(Icons.skip_previous),
                  ),
                  Expanded(
                    child: Slider(
                      value: _currentMessageIndex.toDouble(),
                      min: 0,
                      max: (widget.meeting.messages.length - 1).toDouble(),
                      divisions: widget.meeting.messages.length - 1,
                      onChanged: (value) {
                        setState(() => _currentMessageIndex = value.round());
                        _scrollToMessage(_currentMessageIndex);
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: _currentMessageIndex < widget.meeting.messages.length - 1
                        ? () {
                            setState(() => _currentMessageIndex++);
                            _scrollToMessage(_currentMessageIndex);
                          }
                        : null,
                    icon: const Icon(Icons.skip_next),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  void _showMeetingInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('会议信息'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow('标题', widget.meeting.title),
              _InfoRow('时间', _formatDateTime(widget.meeting.time)),
              _InfoRow('消息数', '${widget.meeting.messages.length}'),
              if (widget.meeting.tags.isNotEmpty)
                _InfoRow('标签', widget.meeting.tags.join(', ')),
              if (widget.meeting.config != null) ...[
                const SizedBox(height: 16),
                Text(
                  '会议配置',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                _InfoRow('主题', widget.meeting.config!.subject),
                _InfoRow('项目', widget.meeting.config!.project),
                _InfoRow('最大人数', '${widget.meeting.config!.maxParticipants}人'),
                if (widget.meeting.config!.participants.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '参与者 (${widget.meeting.config!.participants.length})',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  ...widget.meeting.config!.participants.map((user) => 
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('• ${user.name}'),
                    ),
                  ),
                ],
              ],
              if (widget.meeting.speakerMapping != null) ...[
                const SizedBox(height: 16),
                Text(
                  '说话人映射',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ...widget.meeting.speakerMapping!.entries.map((entry) {
                  final user = widget.meeting.config?.participants
                      .where((u) => u.id == entry.value)
                      .firstOrNull;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('${entry.key} → ${user?.name ?? entry.value}'),
                  );
                }),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label：',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
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