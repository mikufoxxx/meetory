import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' hide AudioSource;
import '../models/meeting.dart';
import '../models/user.dart';
import '../services/meeting_service.dart';

class MeetingDetailPage extends StatefulWidget {
  final Meeting meeting;
  const MeetingDetailPage({super.key, required this.meeting});

  @override
  State<MeetingDetailPage> createState() => _MeetingDetailPageState();
}

class _MeetingDetailPageState extends State<MeetingDetailPage> {
  late final AudioPlayer _player;
  bool _showInfo = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _init();
  }

  Future<void> _init() async {
    try {
      await _player.setUrl(widget.meeting.audioUrl);
    } catch (e) {
      debugPrint('Failed to load audio: $e');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _seekTo(Duration position) {
    if (_player.playerState.playing || _player.duration != null) {
      _player.seek(position);
    }
  }

  Future<void> _showEditMeetingDialog(BuildContext context) async {
    final titleController = TextEditingController(text: widget.meeting.title);
    final projectController = TextEditingController(text: widget.meeting.config?.project ?? '');
    final maxParticipantsController = TextEditingController(
      text: widget.meeting.config?.maxParticipants.toString() ?? '4'
    );
    final tagsController = TextEditingController(
      text: widget.meeting.tags.join(', ')
    );
    final participantsController = TextEditingController(
      text: widget.meeting.config?.participants.join(', ') ?? ''
    );

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('编辑会议信息'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: '会议标题',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: projectController,
                    decoration: const InputDecoration(
                      labelText: '项目名称',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: maxParticipantsController,
                    decoration: const InputDecoration(
                      labelText: '最大参与人数',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: tagsController,
                    decoration: const InputDecoration(
                      labelText: '标签 (用逗号分隔)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: participantsController,
                    decoration: const InputDecoration(
                      labelText: '参会人员 (用逗号分隔)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final newTitle = titleController.text.trim();
                final newProject = projectController.text.trim();
                final newMaxParticipants = int.tryParse(maxParticipantsController.text.trim()) ?? 4;
                final newTags = tagsController.text
                    .split(',')
                    .map((tag) => tag.trim())
                    .where((tag) => tag.isNotEmpty)
                    .toList();
                final newParticipants = participantsController.text
                    .split(',')
                    .map((participant) => participant.trim())
                    .where((participant) => participant.isNotEmpty)
                    .map((name) => User(id: name.toLowerCase().replaceAll(' ', '_'), name: name, createdAt: DateTime.now()))
                    .toList();

                if (newTitle.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('会议标题不能为空')),
                  );
                  return;
                }

                try {
                  final updatedConfig = MeetingConfig(
                    subject: newTitle,
                    tags: newTags,
                    project: newProject.isEmpty ? '未分类' : newProject,
                    maxParticipants: newMaxParticipants,
                    participants: newParticipants,
                  );

                  final updatedMeeting = Meeting(
                    id: widget.meeting.id,
                    projectId: widget.meeting.projectId,
                    title: newTitle,
                    time: widget.meeting.time,
                    tags: newTags,
                    audioUrl: widget.meeting.audioUrl,
                    messages: widget.meeting.messages,
                    config: updatedConfig,
                    speakerMapping: widget.meeting.speakerMapping,
                  );

                  await MeetingService.instance.saveMeeting(updatedMeeting);

                  if (context.mounted) {
                    Navigator.of(context).pop();
                    setState(() {
                      // 触发页面重建以显示更新后的信息
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('会议信息更新成功')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => setState(() => _showInfo = !_showInfo),
          child: Text(widget.meeting.title),
        ),
        actions: [
          IconButton(
            tooltip: '编辑会议',
            onPressed: () => _showEditMeetingDialog(context),
            icon: const Icon(Icons.edit),
          ),
          IconButton(
            tooltip: '查看文档',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MeetingDocumentPage(meeting: widget.meeting),
                ),
              );
            },
            icon: const Icon(Icons.description_outlined),
          )
        ],
        bottom: _showInfo
            ? PreferredSize(
                preferredSize: const Size.fromHeight(80),
                child: _InfoBar(meeting: widget.meeting),
              )
            : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: widget.meeting.messages.length,
              itemBuilder: (context, index) {
                final msg = widget.meeting.messages[index];
                final isSelf = index % 2 == 0;
                return Align(
                  alignment: isSelf ? Alignment.centerLeft : Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => _seekTo(msg.start),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelf
                            ? Theme.of(context).colorScheme.surfaceContainerHighest
                            : Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            msg.speaker,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(msg.text),
                          const SizedBox(height: 4),
                          Text(
                            _fmtDuration(msg.start),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(child: _AudioPlayerBar(player: _player)),
        ],
      ),
    );
  }
}

class _InfoBar extends StatelessWidget {
  final Meeting meeting;
  const _InfoBar({required this.meeting});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: meeting.tags.map((t) => Chip(label: Text(t))).toList(),
          ),
          const SizedBox(height: 6),
          Text('时间：${meeting.time}')
        ],
      ),
    );
  }
}

class _AudioPlayerBar extends StatefulWidget {
  final AudioPlayer player;
  const _AudioPlayerBar({required this.player});

  @override
  State<_AudioPlayerBar> createState() => _AudioPlayerBarState();
}

class _AudioPlayerBarState extends State<_AudioPlayerBar> {
  late StreamSubscription<Duration> _posSub;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _posSub = widget.player.positionStream.listen((pos) {
      setState(() => _position = pos);
    });
    widget.player.durationStream.listen((d) {
      if (d != null) setState(() => _duration = d);
    });
  }

  @override
  void dispose() {
    _posSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              StreamBuilder<PlayerState>(
                stream: widget.player.playerStateStream,
                builder: (context, snap) {
                  final playing = snap.data?.playing ?? false;
                  return IconButton.filledTonal(
                    onPressed: () async {
                      if (playing) {
                        await widget.player.pause();
                      } else {
                        await widget.player.play();
                      }
                    },
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                  );
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Slider(
                      value: _position.inMilliseconds.clamp(0, _duration.inMilliseconds).toDouble(),
                      max: (_duration.inMilliseconds == 0 ? 1 : _duration.inMilliseconds).toDouble(),
                      onChanged: (v) {
                        widget.player.seek(Duration(milliseconds: v.toInt()));
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_fmtDuration(_position), style: Theme.of(context).textTheme.bodySmall),
                        Text(_fmtDuration(_duration), style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _fmtDuration(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = two(d.inHours);
  final m = two(d.inMinutes.remainder(60));
  final s = two(d.inSeconds.remainder(60));
  return h == '00' ? '$m:$s' : '$h:$m:$s';
}

class MeetingDocumentPage extends StatelessWidget {
  final Meeting meeting;
  const MeetingDocumentPage({super.key, required this.meeting});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('会议文档')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text(meeting.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text('时间：${meeting.time}')
            ,
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: meeting.tags.map((t) => Chip(label: Text(t))).toList()),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text('文档内容（示例）'),
            const SizedBox(height: 8),
            const Text('· 议题1：’\n· 结论：’\n· 待办：……'),
          ],
        ),
      ),
    );
  }
}