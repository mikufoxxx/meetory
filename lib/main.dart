import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import 'providers/asr_provider.dart';
import 'pages/projects_page.dart';
import 'pages/meeting_room_page.dart';
import 'pages/settings_page.dart';
import 'services/model_download_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 检查模型是否已下载，如果没有则显示下载界面
  final modelsExist = await ModelDownloadService.areAllModelsDownloaded();

  runApp(MeetoryApp(needsModelDownload: !modelsExist));
}

class MeetoryApp extends StatelessWidget {
  final bool needsModelDownload;

  const MeetoryApp({super.key, this.needsModelDownload = false});

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
        home: needsModelDownload
            ? const ModelDownloadPage()
            : const RootScaffold(),
      ),
    );
  }
}

class RootScaffold extends StatefulWidget {
  const RootScaffold({super.key});

  @override
  State<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<RootScaffold> {
  int _index = 1; // 默认会议室页

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
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.1, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  ),
                );
              },
              child: Container(
                key: ValueKey(_index),
                child: _pages[_index],
              ),
            ),
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
              NavigationDestination(
                  icon: Icon(Icons.folder_outlined),
                  selectedIcon: Icon(Icons.folder),
                  label: '项目'),
              NavigationDestination(
                  icon: Icon(Icons.mic_none),
                  selectedIcon: Icon(Icons.mic),
                  label: '会议室'),
              NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: '设置'),
            ],
          ),
        );
      },
    );
  }
}

class ModelDownloadPage extends StatefulWidget {
  const ModelDownloadPage({super.key});

  @override
  State<ModelDownloadPage> createState() => _ModelDownloadPageState();
}

class _ModelDownloadPageState extends State<ModelDownloadPage> {
  bool _isDownloading = false;
  String _currentModel = '';
  double _progress = 0.0;
  String _status = '准备下载模型文件...';
  String _downloadSpeed = '';
  String _downloadedSize = '';
  String _totalSize = '';
  int _currentFileIndex = 0;
  final int _totalFiles = 4;

  // 下载源选择
  String _selectedSource = 'mirror'; // mirror, direct, custom
  String _customMirror = 'gitraw.techox.cc';
  final TextEditingController _customMirrorController = TextEditingController();
  bool _showSourceSelection = true;

  @override
  void initState() {
    super.initState();
    _customMirrorController.text = _customMirror;
  }

  @override
  void dispose() {
    _customMirrorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.download,
                size: 80,
                color: Colors.indigo,
              ),
              const SizedBox(height: 24),
              const Text(
                '初始化模型文件',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                '首次使用需要下载AI模型文件，这可能需要几分钟时间',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // 下载源选择界面
              if (_showSourceSelection) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '选择下载源',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        RadioListTile<String>(
                          title: const Text('镜像源 (推荐)'),
                          subtitle: const Text('使用 gitraw.techox.cc 镜像，下载速度更快'),
                          value: 'mirror',
                          groupValue: _selectedSource,
                          onChanged: (value) {
                            setState(() {
                              _selectedSource = value!;
                            });
                          },
                        ),
                        RadioListTile<String>(
                          title: const Text('直链'),
                          subtitle: const Text('直接从 GitHub 下载，可能较慢'),
                          value: 'direct',
                          groupValue: _selectedSource,
                          onChanged: (value) {
                            setState(() {
                              _selectedSource = value!;
                            });
                          },
                        ),
                        RadioListTile<String>(
                          title: const Text('自定义镜像源'),
                          subtitle: const Text('使用自定义的镜像地址'),
                          value: 'custom',
                          groupValue: _selectedSource,
                          onChanged: (value) {
                            setState(() {
                              _selectedSource = value!;
                            });
                          },
                        ),
                        if (_selectedSource == 'custom') ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: _customMirrorController,
                            decoration: const InputDecoration(
                              labelText: '自定义镜像源地址',
                              hintText: 'gitraw.techox.cc',
                              border: OutlineInputBorder(),
                              helperText: '格式: 域名，如 gitraw.techox.cc',
                            ),
                            onChanged: (value) {
                              _customMirror = value;
                            },
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _startDownload,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 16,
                                  ),
                                ),
                                child: const Text('开始下载'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _startLocalImport,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 16,
                                  ),
                                ),
                                child: const Text('本地导入'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (_isDownloading) ...[
                // 下载进度界面
                LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  _status,
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                if (_currentModel.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '正在下载: $_currentModel',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                if (_currentFileIndex > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '进度: $_currentFileIndex/$_totalFiles',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                if (_downloadSpeed.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '下载速度: $_downloadSpeed',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                if (_downloadedSize.isNotEmpty && _totalSize.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '已下载: $_downloadedSize / $_totalSize',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ] else ...[
                // 下载失败后的重试界面
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _showSourceSelection = true;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: const Text('重新选择下载源'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startLocalImport() async {
    setState(() {
      _status = '选择模型文件夹...';
    });

    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory == null) {
        setState(() {
          _status = '未选择文件夹';
        });
        return;
      }

      setState(() {
        _isDownloading = true;
        _showSourceSelection = false;
        _status = '正在导入模型文件...';
        _progress = 0.0;
      });

      final success = await ModelDownloadService.importModelsFromDirectory(
        selectedDirectory,
        onProgress: (modelKey, progress) {
          setState(() {
            _currentModel = _getModelDisplayName(modelKey);
            _progress = progress;
            _status = '导入中... ${(progress * 100).toInt()}%';
          });
        },
      );

      if (success) {
        setState(() {
          _status = '导入完成！正在启动应用...';
          _progress = 1.0;
        });

        await Future.delayed(const Duration(seconds: 1));

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const RootScaffold()),
          );
        }
      } else {
        setState(() {
          _status = '导入失败，请检查文件夹中是否包含正确的模型文件';
          _isDownloading = false;
          _showSourceSelection = true;
        });
      }
    } catch (e) {
      setState(() {
        _status = '导入出错: $e';
        _isDownloading = false;
        _showSourceSelection = true;
      });
    }
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _status = '开始下载模型文件...';
      _currentFileIndex = 0;
      _showSourceSelection = false;
    });

    try {
      // 根据选择的下载源配置URL
      String? customMirror;
      if (_selectedSource == 'custom') {
        customMirror = _customMirrorController.text.trim();
        if (customMirror.isEmpty) {
          setState(() {
            _status = '请输入自定义镜像源地址';
            _isDownloading = false;
            _showSourceSelection = true;
          });
          return;
        }
      }

      final success = await ModelDownloadService.downloadAllModels(
        sourceType: _selectedSource,
        customMirror: customMirror,
        onProgress: (modelKey, progress,
            {String? speed,
            String? downloadedSize,
            String? totalSize,
            int? fileIndex}) {
          setState(() {
            _currentModel = _getModelDisplayName(modelKey);
            _progress = progress;
            _status = '下载中... ${(progress * 100).toInt()}%';
            _downloadSpeed = speed ?? '';
            _downloadedSize = downloadedSize ?? '';
            _totalSize = totalSize ?? '';
            _currentFileIndex = fileIndex ?? 0;
          });
        },
      );

      if (success) {
        setState(() {
          _status = '下载完成！正在启动应用...';
          _progress = 1.0;
          _currentFileIndex = _totalFiles;
        });

        // 等待一秒后重启应用
        await Future.delayed(const Duration(seconds: 1));

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const RootScaffold()),
          );
        }
      } else {
        setState(() {
          _status = '下载失败，请检查网络连接后重试';
          _isDownloading = false;
          _showSourceSelection = true;
        });
      }
    } catch (e) {
      setState(() {
        _status = '下载出错: $e';
        _isDownloading = false;
        _showSourceSelection = true;
      });
    }
  }

  String _getModelDisplayName(String modelKey) {
    switch (modelKey) {
      case 'asr':
        return '语音识别模型';
      case 'speaker_segmentation':
        return '说话人分割模型';
      case 'speaker_recognition':
        return '说话人识别模型';
      case 'vad':
        return '语音活动检测模型';
      default:
        return modelKey;
    }
  }
}
