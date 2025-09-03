import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_service.dart';

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1000;
        
        final appBar = AppBar(title: const Text('设置'));
        
        final settingsContent = Card(
          margin: const EdgeInsets.all(16),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('当前版本'),
                subtitle: Text(_currentBuild == null
                    ? (_currentVersion ?? '读取中...')
                    : '${_currentVersion ?? '读取中...'} (+$_currentBuild)'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.system_update_outlined),
                title: const Text('检查更新'),
                subtitle: Text(_latestTag == null ? '访问 GitHub Releases 获取最新版本' : '最新：$_latestTag'),
                trailing: _checking
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : null,
                onTap: _checking ? null : _checkUpdate,
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.download_done_outlined),
                title: Text('模型说明'),
                subtitle: Text('ASR 模型已内置，进入会议室时自动初始化并显示进度提示，无需手动配置'),
              ),
            ],
          ),
        );
        
        if (isWide) {
          return Scaffold(
            appBar: appBar,
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: settingsContent,
              ),
            ),
          );
        }
        
        return Scaffold(
          appBar: appBar,
          body: settingsContent,
        );
      },
    );
  }
}