import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/asr_provider.dart';
import '../models/meeting.dart';

class FloatingRecordingWidget extends StatefulWidget {
  final MeetingConfig? meetingConfig;
  final VoidCallback? onTap;
  final VoidCallback? onClose;

  const FloatingRecordingWidget({
    super.key,
    this.meetingConfig,
    this.onTap,
    this.onClose,
  });

  @override
  State<FloatingRecordingWidget> createState() =>
      _FloatingRecordingWidgetState();
}

class _FloatingRecordingWidgetState extends State<FloatingRecordingWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _snapController;
  late Animation<Offset> _snapAnimation;
  Timer? _updateTimer;

  // 拖拽相关状态
  Offset _position = const Offset(0, 0);
  bool _isDragging = false;
  bool _isSnapping = false;
  late Size _screenSize;
  late Size _widgetSize;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _pulseController.repeat(reverse: true);

    // 初始化吸附动画控制器
    _snapController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _snapAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _snapController,
      curve: Curves.easeOutCubic,
    ));

    _snapAnimation.addListener(() {
      if (_isSnapping) {
        setState(() {
          _position = _snapAnimation.value;
        });
      }
    });

    _snapController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isSnapping = false;
        });
      }
    });

    // 添加定时器来更新录音时长显示
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });

    // 初始化屏幕尺寸和组件尺寸
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _screenSize = MediaQuery.of(context).size;
      _widgetSize = const Size(200, 60); // 估算组件大小
      _position = Offset(
        _screenSize.width - _widgetSize.width - 16,
        MediaQuery.of(context).padding.top + 16,
      );
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _snapController.dispose();
    _updateTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
  }

  // 边缘吸附逻辑（带动画）
  void _snapToEdge() {
    if (_screenSize == Size.zero) return;

    final double centerX = _position.dx + _widgetSize.width / 2;
    final double screenCenterX = _screenSize.width / 2;

    double newX;
    if (centerX < screenCenterX) {
      // 吸附到左边
      newX = 16;
    } else {
      // 吸附到右边
      newX = _screenSize.width - _widgetSize.width - 16;
    }

    // 确保Y坐标在安全区域内
    double newY = _position.dy;
    final double topPadding = MediaQuery.of(context).padding.top + 16;
    final double bottomPadding = MediaQuery.of(context).padding.bottom + 16;

    if (newY < topPadding) {
      newY = topPadding;
    } else if (newY + _widgetSize.height > _screenSize.height - bottomPadding) {
      newY = _screenSize.height - _widgetSize.height - bottomPadding;
    }

    final Offset targetPosition = Offset(newX, newY);

    // 如果位置没有变化，不需要动画
    if ((_position - targetPosition).distance < 1.0) {
      return;
    }

    // 开始吸附动画
    setState(() {
      _isSnapping = true;
    });

    _snapAnimation = Tween<Offset>(
      begin: _position,
      end: targetPosition,
    ).animate(CurvedAnimation(
      parent: _snapController,
      curve: Curves.easeOutCubic,
    ));

    _snapController.reset();
    _snapController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AsrProvider>(builder: (context, asr, child) {
      if (!asr.running) {
        return const SizedBox.shrink();
      }

      return Positioned(
        left: _position.dx,
        top: _position.dy,
        child: GestureDetector(
          onTap: _isDragging ? null : widget.onTap,
          onPanStart: (details) {
            setState(() {
              _isDragging = true;
            });
          },
          onPanUpdate: (details) {
            setState(() {
              _position += details.delta;

              // 限制在屏幕边界内
              _position = Offset(
                _position.dx.clamp(0, _screenSize.width - _widgetSize.width),
                _position.dy.clamp(
                  MediaQuery.of(context).padding.top,
                  _screenSize.height -
                      _widgetSize.height -
                      MediaQuery.of(context).padding.bottom,
                ),
              );
            });
          },
          onPanEnd: (details) {
            setState(() {
              _isDragging = false;
            });
            _snapToEdge();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Icon(
                        Icons.mic,
                        color: Theme.of(context).colorScheme.primary,
                        size: 16,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.meetingConfig?.subject ?? '会议录音中',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    Text(
                      _formatDuration(asr.recordingDuration),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer
                                .withValues(alpha: 0.7),
                          ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: widget.onTap,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.keyboard_return,
                      color: Theme.of(context).colorScheme.primary,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class FloatingRecordingOverlay {
  static OverlayEntry? _overlayEntry;
  static MeetingConfig? _currentMeetingConfig;
  static BuildContext? _originalContext;

  static void show(
    BuildContext context, {
    MeetingConfig? meetingConfig,
    VoidCallback? onTap,
  }) {
    hide();

    _currentMeetingConfig = meetingConfig;
    _originalContext = context;
    _overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        return FloatingRecordingWidget(
          meetingConfig: meetingConfig,
          onTap: () {
            // 使用原始context而不是overlayContext来确保Navigator可用
            if (_originalContext != null && _originalContext!.mounted) {
              onTap?.call();
            }
          },
          onClose: hide,
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _currentMeetingConfig = null;
    _originalContext = null;
  }

  static bool get isShowing => _overlayEntry != null;
  static MeetingConfig? get currentMeetingConfig => _currentMeetingConfig;
}
