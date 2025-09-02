import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
// 注意：sherpa_onnx 暂不直接在此处导入以避免 Web 构建问题。
// 后续将通过条件导入按平台接入（mobile/desktop 使用 FFI，web 使用占位或禁用）。
// import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

void main() {
  runApp(const MeetoryApp());
}

class MeetoryApp extends StatelessWidget {
  const MeetoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AsrProvider()),
      ],
      child: MaterialApp(
        title: '会忆 Meetory',
        theme: theme,
        home: const RootScaffold(),
      ),
    );
  }
}

// 响应式根框架：底部导航（窄屏）/ 侧边导航Rail（宽屏）
class RootScaffold extends StatefulWidget {
  const RootScaffold({super.key});

  @override
  State<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<RootScaffold> {
  int _index = 1; // 默认进入“会议室”

  final _pages = const [
    ProjectsPage(),
    MeetingRoomPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1000;
        final body = Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: _pages[_index],
          ),
        );

        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.folder_outlined),
                      selectedIcon: Icon(Icons.folder),
                      label: Text('项目'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.mic_none),
                      selectedIcon: Icon(Icons.mic),
                      label: Text('会议室'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: Text('设置'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          );
        }

        return Scaffold(
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: '项目'),
              NavigationDestination(icon: Icon(Icons.mic_none), selectedIcon: Icon(Icons.mic), label: '会议室'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '设置'),
            ],
          ),
        );
      },
    );
  }
}

// =============== 数据模型（示例） ===============
class Project {
  final String id;
  final String name;
  final String description;

  const Project({required this.id, required this.name, required this.description});
}

class Meeting {
  final String id;
  final String projectId;
  final String title;
  final DateTime time;
  final List<String> tags;
  final String audioUrl; // 简化：使用网络音频/本地文件路径
  final List<MessageChunk> messages;

  const Meeting({
    required this.id,
    required this.projectId,
    required this.title,
    required this.time,
    required this.tags,
    required this.audioUrl,
    required this.messages,
  });
}

class MessageChunk {
  final String speaker;
  final String text;
  final Duration start;
  final Duration end;

  const MessageChunk({required this.speaker, required this.text, required this.start, required this.end});
}

// =============== ASR Provider（占位，预留 sherpa_onnx 集成） ===============
class AsrProvider extends ChangeNotifier {
  bool _running = false;
  final List<String> _lines = [];
  Timer? _fakeTimer;

  bool get running => _running;
  List<String> get lines => List.unmodifiable(_lines);

  Future<void> start() async {
    if (_running) return;
    _running = true;
    _lines.clear();
    notifyListeners();

    // TODO: 在这里初始化 sherpa_onnx 在线识别器与麦克风PCM流
    // 示例结构：
    // final recognizer = sherpa.OnlineRecognizer(...models...);
    // micStream.listen((pcm) => recognizer.acceptWaveform(pcm));
    // recognizer.onResult = (partial, isFinal) { _lines.add(partial); notifyListeners(); };

    // 先用假数据模拟流式输出
    int i = 0;
    const samples = [
      '大家好，欢迎进入今天的例会。',
      '我们先回顾一下上周的进展。',
      '关于性能优化，有两个提案需要讨论。',
      '决定采用方案A，预计下周完成。',
    ];
    _fakeTimer = Timer.periodic(const Duration(seconds: 2), (t) {
      if (!_running) return;
      if (i < samples.length) {
        _lines.add(samples[i]);
        i++;
      } else {
        _lines.add('（持续聆听中...）');
      }
      notifyListeners();
    });
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    _fakeTimer?.cancel();
    _fakeTimer = null;
    notifyListeners();
    // TODO: 释放 sherpa_onnx 资源、关闭麦克风流
  }
}

// =============== 页面：项目列表 ===============
class ProjectsPage extends StatelessWidget {
  const ProjectsPage({super.key});

  static final List<Project> _demo = List.generate(
    8,
    (i) => Project(id: 'p$i', name: '项目 ${i + 1}', description: '这是项目 ${i + 1} 的简介'),
  );

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 800;
    final grid = isWide;

    return Scaffold(
      appBar: AppBar(title: const Text('项目 Projects')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: grid
            ? GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 5 / 3,
                ),
                itemCount: _demo.length,
                itemBuilder: (context, index) => _ProjectCard(project: _demo[index]),
              )
            : ListView.separated(
                itemCount: _demo.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _ProjectTile(project: _demo[index]),
              ),
      ),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  final Project project;
  const _ProjectTile({required this.project});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.folder),
      title: Text(project.name),
      subtitle: Text(project.description),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProjectShellPage(project: project)),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  const _ProjectCard({required this.project});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ProjectShellPage(project: project)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.folder, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(project.name, style: Theme.of(context).textTheme.titleMedium),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Text(
                  project.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.bottomRight,
                child: FilledButton.tonal(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ProjectShellPage(project: project)),
                  ),
                  child: const Text('进入'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============== 页面：项目详情（子导航：历史 / 知识库） ===============
class ProjectShellPage extends StatefulWidget {
  final Project project;
  const ProjectShellPage({super.key, required this.project});

  @override
  State<ProjectShellPage> createState() => _ProjectShellPageState();
}

class _ProjectShellPageState extends State<ProjectShellPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      ProjectHistoryPage(project: widget.project),
      ProjectKnowledgePage(project: widget.project),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(widget.project.name)),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.history), label: '会议历史'),
          NavigationDestination(icon: Icon(Icons.library_books_outlined), label: '文档/知识库'),
        ],
      ),
    );
  }
}

class ProjectHistoryPage extends StatelessWidget {
  final Project project;
  const ProjectHistoryPage({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    final meetings = _demoMeetingsFor(project.id);
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: meetings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final m = meetings[index];
        return Card(
          child: ListTile(
            title: Text(m.title),
            subtitle: Text('${m.time}  · 标签：${m.tags.join(', ')}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => MeetingDetailPage(meeting: m)),
            ),
          ),
        );
      },
    );
  }
}

class ProjectKnowledgePage extends StatelessWidget {
  final Project project;
  const ProjectKnowledgePage({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    // 占位：后续接入聚合知识/文档
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.auto_stories, size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('项目知识库（占位）', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('这里将展示该项目的聚合文档、主题、概念图谱与演进。'),
          ],
        ),
      ),
    );
  }
}

// =============== 页面：会议室（实时转写） ===============
class MeetingRoomPage extends StatelessWidget {
  const MeetingRoomPage({super.key});

  @override
  Widget build(BuildContext context) {
    final asr = context.watch<AsrProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('会议室 · 实时转写')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                FilledButton.icon(
                  onPressed: asr.running ? null : asr.start,
                  icon: const Icon(Icons.mic),
                  label: const Text('开始'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: asr.running ? asr.stop : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('停止'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: asr.lines.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(asr.lines[i]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============== 页面：设置 ===============
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _checking = false;
  String? _latestTag;
  String? _currentVersion;
  String? _currentBuild;

  @override
  void initState() {
    super.initState();
    _initVersion();
  }

  Future<void> _initVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _currentVersion = info.version;
      _currentBuild = info.buildNumber;
    });
  }

  Future<void> _checkUpdate() async {
    setState(() => _checking = true);
    try {
      final latest = await UpdateService.fetchLatestRelease();
      if (!mounted) return;
      setState(() => _latestTag = latest?.tag);

      final currentTag = 'v${_currentVersion ?? '0.0.0'}';
      final isNew = latest != null && UpdateService.compareTags(latest.tag, currentTag) > 0;

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(isNew ? '发现新版本 ${latest.tag}' : '已是最新版本'),
          content: Text(isNew
              ? '当前版本 ${_currentVersion ?? '?'}，是否前往下载？\n\n仓库：${UpdateService.owner}/${UpdateService.repo}'
              : '当前版本 ${_currentVersion ?? '?'} 已是最新。\n\n仓库：${UpdateService.owner}/${UpdateService.repo}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
            if (isNew)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _openUrl(latest.url);
                 },
                 child: const Text('前往下载'),
              ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('检查更新失败：$e')));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('无法打开链接')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('当前版本'),
            subtitle: Text(_currentBuild == null
                ? (_currentVersion ?? '读取中...')
                : '${_currentVersion ?? '读取中...'} (+$_currentBuild)'),
          ),
          ListTile(
            leading: const Icon(Icons.system_update_outlined),
            title: const Text('检查更新'),
            subtitle: Text(_latestTag == null ? '访问 GitHub Releases 获取最新版本' : '最新：$_latestTag'),
            trailing: _checking
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : null,
            onTap: _checking ? null : _checkUpdate,
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.download),
            title: Text('模型管理（占位）'),
            subtitle: Text('选择与下载 sherpa_onnx 模型'),
          ),
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('隐私模式（占位）'),
            subtitle: Text('离线优先/云端摘要开关'),
          ),
        ],
      ),
    );
  }
}

// =============== 页面：会议详情（聊天气泡 + 音频播放器 + AppBar下拉信息 + 文档按钮） ===============
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
      // 忽略资源加载失败，以确保UI可用
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
                final isSelf = index % 2 == 0; // 仅用于交错视觉
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
    // 占位：显示本次会议生成的文档
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

// =============== 示例数据：构造一个会议含音频与消息 ===============
List<Meeting> _demoMeetingsFor(String projectId) {
  final audio = 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';
  final now = DateTime.now();
  return [
    Meeting(
      id: 'm1',
      projectId: projectId,
      title: '每周例会（性能优化）',
      time: now.subtract(const Duration(days: 1)),
      tags: const ['性能', '优化', '方案A'],
      audioUrl: audio,
      messages: const [
        MessageChunk(speaker: '主持人', text: '大家好，我们开始今天的例会。', start: Duration(seconds: 2), end: Duration(seconds: 6)),
        MessageChunk(speaker: '工程师A', text: '上周我主要做了接口的延迟分析。', start: Duration(seconds: 8), end: Duration(seconds: 15)),
        MessageChunk(speaker: '工程师B', text: '我尝试了两种缓存策略，效果还不错。', start: Duration(seconds: 16), end: Duration(seconds: 25)),
        MessageChunk(speaker: '主持人', text: '我们是否可以先落地方案A？', start: Duration(seconds: 28), end: Duration(seconds: 36)),
      ],
    ),
    Meeting(
      id: 'm2',
      projectId: projectId,
      title: '需求评审（支付模块）',
      time: now.subtract(const Duration(days: 7)),
      tags: const ['评审', '支付', '风控'],
      audioUrl: audio,
      messages: const [
        MessageChunk(speaker: '产品经理', text: '这次评审主要讨论支付体验。', start: Duration(seconds: 3), end: Duration(seconds: 10)),
        MessageChunk(speaker: '后端', text: '我们计划引入异步通知机制。', start: Duration(seconds: 14), end: Duration(seconds: 22)),
      ],
    ),
  ];
}

// =============== 更新服务（GitHub Releases 检查） ===============
class UpdateInfo {
  final String tag;
  final String url;
  const UpdateInfo({required this.tag, required this.url});
}

class UpdateService {
  static const String owner = 'mikufoxxx';
  static const String repo = 'meetory';

  static Future<UpdateInfo?> fetchLatestRelease() async {
    final uri = Uri.parse('https://api.github.com/repos/$owner/$repo/releases/latest');
    final resp = await http.get(uri, headers: {
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
    });
    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final tag = (data['tag_name'] as String?) ?? '';
    final url = (data['html_url'] as String?) ?? 'https://github.com/$owner/$repo/releases';
    if (tag.isEmpty) return null;
    return UpdateInfo(tag: tag, url: url);
  }

  static List<int> _parseSemVer(String v) {
    final s = v.trim();
    final cleaned = s.startsWith('v') ? s.substring(1) : s;
    final parts = cleaned.split(RegExp(r'[.-]'));
    int p(int i) => i < parts.length ? int.tryParse(parts[i]) ?? 0 : 0;
    return [p(0), p(1), p(2)];
  }

  // > 0 表示 a > b；=0 表示相等；<0 表示 a < b
  static int compareTags(String a, String b) {
    final A = _parseSemVer(a);
    final B = _parseSemVer(b);
    for (var i = 0; i < 3; i++) {
      if (A[i] != B[i]) return A[i] - B[i];
    }
    return 0;
  }
}
