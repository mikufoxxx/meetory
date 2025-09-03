import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' hide AudioSource;
import '../models/meeting.dart';
import 'meeting_edit_page.dart';

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
      // 检查音频URL是否有效
      if (widget.meeting.audioUrl.isEmpty) {
        debugPrint('Audio URL is empty, skipping audio initialization');
        return;
      }

      // 检查文件是否存在（对于本地文件）
      if (!widget.meeting.audioUrl.startsWith('http')) {
        final file = File(widget.meeting.audioUrl);
        if (!await file.exists()) {
          debugPrint('Audio file does not exist: ${widget.meeting.audioUrl}');
          return;
        }
      }

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
    final result = await Navigator.of(context).push<Meeting>(
      PageRouteBuilder<Meeting>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            MeetingEditPage(meeting: widget.meeting),
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
    );

    if (result != null) {
      setState(() {
        // 触发页面重建以显示更新后的信息
      });
      if (mounted) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('会议信息更新成功')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1000;

        final appBar = AppBar(
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
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        MeetingDocumentPage(meeting: widget.meeting),
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
        );

        final messagesList = Expanded(
          child: Card(
            margin: const EdgeInsets.all(12),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.meeting.messages.length,
              itemBuilder: (context, index) {
                final msg = widget.meeting.messages[index];
                final isSelf = index % 2 == 0;
                return Align(
                  alignment:
                      isSelf ? Alignment.centerLeft : Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => _seekTo(msg.start),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelf
                            ? Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                            : Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      constraints: BoxConstraints(maxWidth: isWide ? 800 : 640),
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
        );

        final audioPlayer = SafeArea(child: _AudioPlayerBar(player: _player));

        if (isWide) {
          return Scaffold(
            appBar: appBar,
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  children: [
                    messagesList,
                    audioPlayer,
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: appBar,
          body: Column(
            children: [
              messagesList,
              audioPlayer,
            ],
          ),
        );
      },
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
                      value: _position.inMilliseconds
                          .clamp(0, _duration.inMilliseconds)
                          .toDouble(),
                      max: (_duration.inMilliseconds == 0
                              ? 1
                              : _duration.inMilliseconds)
                          .toDouble(),
                      onChanged: (v) {
                        widget.player.seek(Duration(milliseconds: v.toInt()));
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_fmtDuration(_position),
                            style: Theme.of(context).textTheme.bodySmall),
                        Text(_fmtDuration(_duration),
                            style: Theme.of(context).textTheme.bodySmall),
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
            Text('时间：${meeting.time}'),
            const SizedBox(height: 12),
            Wrap(
                spacing: 8,
                children:
                    meeting.tags.map((t) => Chip(label: Text(t))).toList()),
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
