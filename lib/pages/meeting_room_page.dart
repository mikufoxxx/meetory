import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'meeting_room_detail_page.dart';
import 'meeting_room_config_page.dart';
import 'user_management_page.dart';
import '../providers/asr_provider.dart';
import '../widgets/floating_recording_widget.dart';

class _LanRoom {
  final String name;
  final String host;
  final int port;
  const _LanRoom({required this.name, required this.host, required this.port});
}

class MeetingRoomPage extends StatefulWidget {
  const MeetingRoomPage({super.key});

  @override
  State<MeetingRoomPage> createState() => _MeetingRoomPageState();
}

class _MeetingRoomPageState extends State<MeetingRoomPage> {
  static const String _serviceType = '_wonderful-service._tcp';

  bool _scanning = false;
  final List<_LanRoom> _rooms = [];
  Timer? _refreshTimer;

  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _discoverySub;
  BonsoirBroadcast? _broadcast;

  @override
  void initState() {
    super.initState();
    // 页面加载时自动扫描一次
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scan();
    });
    // 设置定期刷新，每30秒扫描一次
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_scanning && mounted) {
        _scan();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _stopDiscovery();
    _stopBroadcast();
    super.dispose();
  }

  Future<void> _stopDiscovery() async {
    try {
      await _discoverySub?.cancel();
    } catch (_) {}
    _discoverySub = null;
    try {
      await _discovery?.stop();
    } catch (_) {}
    _discovery = null;
  }

  Future<void> _stopBroadcast() async {
    try {
      await _broadcast?.stop();
    } catch (_) {}
    _broadcast = null;
  }

  void _scan() async {
    if (_scanning) return;
    if (kIsWeb) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Web 平台暂不支持局域网发现')));
      return;
    }
    setState(() {
      _scanning = true;
      _rooms.clear();
    });

    final discovery = BonsoirDiscovery(type: _serviceType);
    _discovery = discovery;
    await discovery.ready;

    _discoverySub = discovery.eventStream!.listen((event) async {
      final service = event.service;
      if (service == null) return;
      switch (event.type) {
        case BonsoirDiscoveryEventType.discoveryServiceFound:
          try {
            await service.resolve(discovery.serviceResolver);
          } catch (_) {}
          break;
        case BonsoirDiscoveryEventType.discoveryServiceResolved:
          final json = service.toJson();
          final host =
              (json['host'] ?? json['ip'] ?? json['address'] ?? 'unknown')
                  .toString();
          final port = service.port;
          final name = service.name.isNotEmpty ? service.name : '会议室';
          setState(() {
            _rooms.removeWhere((r) => r.name == name && r.port == port);
            _rooms.add(_LanRoom(name: name, host: host, port: port));
          });
          break;
        case BonsoirDiscoveryEventType.discoveryServiceLost:
          final name = service.name;
          final port = service.port;
          setState(() {
            _rooms.removeWhere((r) => r.name == name && r.port == port);
          });
          break;
        default:
          break;
      }
    });

    await discovery.start();

    Future.delayed(const Duration(seconds: 8), () async {
      if (!mounted) return;
      await _stopDiscovery();
      if (mounted) {
        setState(() => _scanning = false);
        if (_rooms.isEmpty) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('未发现会议室')));
        }
      }
    });
  }

  void _enterRoom(_LanRoom r) {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => MeetingRoomDetailPage(
              roomName: r.name, host: r.host, port: r.port)),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return hours == '00' ? '$minutes:$seconds' : '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 800;
    return Scaffold(
      appBar: AppBar(
        title: const Text('会议室'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const UserManagementPage(),
                ),
              );
            },
            icon: const Icon(Icons.people),
            tooltip: '用户管理',
          ),
          IconButton(
            tooltip: '扫描局域网会议室',
            onPressed: _scanning ? null : _scan,
            icon: _scanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_tethering),
          )
        ],
      ),
      body: Column(
        children: [
          // 正在进行的会议区域
          Consumer<AsrProvider>(builder: (context, asr, _) {
            if (!asr.running || !FloatingRecordingOverlay.isShowing) {
              return const SizedBox.shrink();
            }

            final meetingConfig = FloatingRecordingOverlay.currentMeetingConfig;
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '正在进行会议',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          meetingConfig?.subject ?? '未知会议',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                        ),
                        Text(
                          '项目: ${meetingConfig?.project ?? '未分类'}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer
                                        .withValues(alpha: 0.7),
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatDuration(asr.recordingDuration),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonal(
                    onPressed: () {
                      // 返回到会议详情页面
                      FloatingRecordingOverlay.hide();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => MeetingRoomDetailPage(
                            roomName:
                                'Meetory #${DateTime.now().millisecondsSinceEpoch % 10000}',
                            host: '127.0.0.1',
                            port: 3030,
                            config: meetingConfig,
                          ),
                        ),
                      );
                    },
                    child: const Text('返回会议'),
                  ),
                ],
              ),
            );
          }),
          // 会议室列表
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: isWide
                  ? GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 5 / 3,
                      ),
                      itemCount: _rooms.length,
                      itemBuilder: (context, index) {
                        final r = _rooms[index];
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _enterRoom(r),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.meeting_room, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(r.name,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Expanded(
                                    child: Text(
                                      '${r.host}:${r.port}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: FilledButton.tonal(
                                      onPressed: () => _enterRoom(r),
                                      child: const Text('进入'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  : ListView.separated(
                      itemCount: _rooms.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final r = _rooms[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.meeting_room),
                            title: Text(r.name),
                            subtitle: Text('${r.host}:${r.port}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _enterRoom(r),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const MeetingRoomConfigPage(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('新建会议室'),
      ),
    );
  }
}
