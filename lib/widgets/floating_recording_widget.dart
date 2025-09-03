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
  State<FloatingRecordingWidget> createState() => _FloatingRecordingWidgetState();
}

class _FloatingRecordingWidgetState extends State<FloatingRecordingWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
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
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer<AsrProvider>(builder: (context, asr, child) {
      if (!asr.running) {
        return const SizedBox.shrink();
      }
      
      return Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        right: 16,
        child: GestureDetector(
          onTap: widget.onTap,
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
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _formatDuration(asr.recordingDuration),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                if (widget.onClose != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: widget.onClose,
                    child: Icon(
                      Icons.close,
                      color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                      size: 16,
                    ),
                  ),
                ],
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
  
  static void show(BuildContext context, {
    MeetingConfig? meetingConfig,
    VoidCallback? onTap,
  }) {
    hide();
    
    _currentMeetingConfig = meetingConfig;
    _overlayEntry = OverlayEntry(
      builder: (context) => FloatingRecordingWidget(
        meetingConfig: meetingConfig,
        onTap: onTap,
        onClose: hide,
      ),
    );
    
    Overlay.of(context).insert(_overlayEntry!);
  }
  
  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _currentMeetingConfig = null;
  }
  
  static bool get isShowing => _overlayEntry != null;
  static MeetingConfig? get currentMeetingConfig => _currentMeetingConfig;
}