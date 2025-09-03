import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:mic_stream/mic_stream.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;
import 'package:path/path.dart' as path;
import '../utils/asset_file_io.dart'
    if (dart.library.html) '../utils/asset_file_web.dart';

// Simple data class for diarization UI
class DiarizationSegment {
  final double start;
  final double end;
  final int speaker;
  const DiarizationSegment(
      {required this.start, required this.end, required this.speaker});
}

class AsrProvider extends ChangeNotifier {
  bool _running = false;
  final List<String> _lines = [];
  // Removed unused _fakeTimer
  StreamSubscription<List<int>>? _micSub; // mobile mic_stream
  
  // Recording duration tracking
  DateTime? _recordingStartTime;
  Duration get recordingDuration {
    if (_recordingStartTime == null || !_running) {
      return Duration.zero;
    }
    return DateTime.now().difference(_recordingStartTime!);
  }

  // Desktop/web recording
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _recordSub;

  // Audio file recording
  String? _currentRecordingPath;
  IOSink? _audioFileSink;
  final BytesBuilder _audioFileBuffer = BytesBuilder(copy: false);

  // Buffered PCM bytes to ensure enough frames before feeding the recognizer
  final BytesBuilder _pcmBuf = BytesBuilder(copy: false);
  // Minimum samples to push each time to avoid feature assertion (about 0.5s @16k)
  static const int _minSamplesPerPush = 8000; // 0.5s
  Timer? _decodeTimer;

  // ===== Lightweight energy-based VAD (real-time segmentation) =====
  final bool _enableEnergyVad = true; // 可通过对外方法开放开关
  final int _vadFrameSize = 160; // 10ms @ 16kHz
  final int _vadTriggerFrames = 5; // 连续 50ms 超阈值判定为起音
  final int _vadReleaseFrames = 12; // 连续 120ms 低于阈值判定为端点
  final double _vadEnergyThreshold = 0.008; // 能量阈值，可调
  bool _vadInSpeech = false;
  int _vadSpeechCount = 0;
  int _vadSilenceCount = 0;
  final List<double> _vadCarry = []; // 缓冲不足一帧的样本
  bool _pendingVadFinalize = false; // 提醒解码线程做定稿

  // ===== Real-time speaker diarization (per-utterance) =====
  // Accumulate current utterance audio in float32
  final List<double> _uttBuf = [];
  // Online incremental clustering over speaker embeddings
  final List<Float32List> _speakerCentroids = [];
  // Adjustable threshold for cosine similarity; larger -> fewer speakers
  final double _spkThreshold = 0.65;
  // Maximum number of speakers (0 = unlimited)
  int _maxSpeakers = 0;
  // Embedding extractor (loaded on demand)
  sherpa_onnx.SpeakerEmbeddingExtractor? _embedder;

  // sherpa_onnx recognizer (optional until configured)
  sherpa_onnx.OnlineRecognizer? _recognizer;
  sherpa_onnx.OnlineStream? _stream;
  String _lastPartial = '';
  // Ensure sherpa_onnx native bindings are initialized exactly once
  bool _sherpaInitialized = false;
  // UI state: model loading indicator and last error
  bool _loadingModel = false;
  String? _lastError;
  bool get loadingModel => _loadingModel;
  String? get lastError => _lastError;
  void _ensureSherpaInitialized() {
    if (_sherpaInitialized) return;
    // initBindings is required before creating any sherpa_onnx objects
    sherpa_onnx.initBindings();
    _sherpaInitialized = true;
  }

  // Lazily load speaker embedding extractor from assets
  Future<void> _ensureEmbedderLoaded() async {
    if (_embedder != null) return;
    _ensureSherpaInitialized();
    try {
      final embModel = await writeAssetToFile(
        'assets/models/speaker_diarization/3dspeaker_speech_eres2net_base_sv_zh-cn_3dspeaker_16k.onnx',
      );
      final embCfg =
          sherpa_onnx.SpeakerEmbeddingExtractorConfig(model: embModel);
      _embedder = sherpa_onnx.SpeakerEmbeddingExtractor(config: embCfg);
    } catch (e) {
      // If embedding extractor fails to load, diarization is disabled gracefully
      _lastError = '加载说话人嵌入模型失败：$e';
      notifyListeners();
    }
  }

  bool get running => _running;
  List<String> get lines => List.unmodifiable(_lines);
  String? get currentRecordingPath => _currentRecordingPath;
  
  // Get current detected speakers
  List<String> get detectedSpeakers {
    final speakers = <String>[];
    for (int i = 0; i < _speakerCentroids.length; i++) {
      speakers.add('S${i + 1}');
    }
    return speakers;
  }

  // Start recording audio to file
  Future<void> startRecordingToFile(String projectName, String meetingId) async {
    if (kIsWeb) return; // Web platform doesn't support file I/O
    
    try {
      // Create project directory if it doesn't exist
      final projectDir = Directory(path.join('data', 'projects', projectName));
      if (!await projectDir.exists()) {
        await projectDir.create(recursive: true);
      }
      
      // Create meeting directory
      final meetingDir = Directory(path.join(projectDir.path, meetingId));
      if (!await meetingDir.exists()) {
        await meetingDir.create(recursive: true);
      }
      
      // Create audio file path
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = path.join(meetingDir.path, 'recording_$timestamp.wav');
      
      // Create WAV file with header
      final audioFile = File(_currentRecordingPath!);
      _audioFileSink = audioFile.openWrite();
      
      // Write WAV header (will be updated when recording stops)
      _writeWavHeader(_audioFileSink!, 0);
      _audioFileBuffer.clear();
    } catch (e) {
      _lastError = '创建录音文件失败：$e';
      notifyListeners();
    }
  }

  // Stop recording audio to file
  Future<void> stopRecordingToFile() async {
    if (_audioFileSink == null || _currentRecordingPath == null) return;
    
    try {
      // Close the file sink
      await _audioFileSink!.close();
      _audioFileSink = null;
      
      // Update WAV header with correct file size
      final audioFile = File(_currentRecordingPath!);
      if (await audioFile.exists()) {
        final fileSize = await audioFile.length();
        final randomAccessFile = await audioFile.open(mode: FileMode.write);
        
        // Update file size in WAV header
        await randomAccessFile.setPosition(4);
        await randomAccessFile.writeFrom(_int32ToBytes(fileSize - 8));
        await randomAccessFile.setPosition(40);
        await randomAccessFile.writeFrom(_int32ToBytes(fileSize - 44));
        
        await randomAccessFile.close();
      }
      
      _currentRecordingPath = null;
      _audioFileBuffer.clear();
    } catch (e) {
      _lastError = '保存录音文件失败：$e';
      notifyListeners();
    }
  }

  // Write audio data to file
  void _writeAudioDataToFile(Uint8List data) {
    if (_audioFileSink == null || kIsWeb) return;
    
    try {
      _audioFileBuffer.add(data);
      _audioFileSink!.add(data);
    } catch (e) {
      _lastError = '写入录音数据失败：$e';
      // Don't notify listeners here to avoid excessive UI updates
    }
  }

  // Write WAV file header
  void _writeWavHeader(IOSink sink, int dataSize) {
    final header = BytesBuilder();
    
    // RIFF header
    header.add('RIFF'.codeUnits);
    header.add(_int32ToBytes(36 + dataSize)); // File size - 8
    header.add('WAVE'.codeUnits);
    
    // Format chunk
    header.add('fmt '.codeUnits);
    header.add(_int32ToBytes(16)); // Format chunk size
    header.add(_int16ToBytes(1)); // Audio format (PCM)
    header.add(_int16ToBytes(1)); // Number of channels
    header.add(_int32ToBytes(16000)); // Sample rate
    header.add(_int32ToBytes(32000)); // Byte rate (sample rate * channels * bits per sample / 8)
    header.add(_int16ToBytes(2)); // Block align (channels * bits per sample / 8)
    header.add(_int16ToBytes(16)); // Bits per sample
    
    // Data chunk
    header.add('data'.codeUnits);
    header.add(_int32ToBytes(dataSize)); // Data size
    
    sink.add(header.takeBytes());
  }

  // Helper methods for byte conversion
  Uint8List _int32ToBytes(int value) {
    return Uint8List.fromList([
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ]);
  }

  Uint8List _int16ToBytes(int value) {
    return Uint8List.fromList([
      value & 0xFF,
      (value >> 8) & 0xFF,
    ]);
  }
  
  // Set maximum number of speakers (0 = unlimited)
  void setMaxSpeakers(int maxSpeakers) {
    _maxSpeakers = maxSpeakers;
    // If current speakers exceed the limit, truncate the list
    if (_maxSpeakers > 0 && _speakerCentroids.length > _maxSpeakers) {
      _speakerCentroids.removeRange(_maxSpeakers, _speakerCentroids.length);
    }
  }
  
  // Get current maximum speakers setting
  int get maxSpeakers => _maxSpeakers;
  
  // Reset speaker clustering (useful when starting a new meeting)
  void resetSpeakers() {
    _speakerCentroids.clear();
    _uttBuf.clear();
  }

  // Configure recognizer with model paths. Call this before start() if you want real ASR.
  Future<void> configureParaformer({
    required String tokens,
    required String encoder,
    required String decoder,
    int sampleRate = 16000,
    int featDim = 80,
    bool useVad = false,
  }) async {
    // Dispose existing
    try {
      _stream = null;
    } catch (_) {}
    try {
      _recognizer = null;
    } catch (_) {}

    _ensureSherpaInitialized();

    final onlineModel = sherpa_onnx.OnlineModelConfig(
      tokens: tokens,
      paraformer: sherpa_onnx.OnlineParaformerModelConfig(
        encoder: encoder,
        decoder: decoder,
      ),
    );
    final cfg = sherpa_onnx.OnlineRecognizerConfig(
      feat: sherpa_onnx.FeatureConfig(
          sampleRate: sampleRate, featureDim: featDim),
      model: onlineModel,
      // decoding
      decodingMethod: 'greedy_search',
      maxActivePaths: 4,
      // endpoint detection
      enableEndpoint: true,
      rule1MinTrailingSilence: 2.4,
      rule2MinTrailingSilence: 1.2,
      rule3MinUtteranceLength: 20.0,
      // hotwords (optional)
      hotwordsFile: '',
    );
    _recognizer = sherpa_onnx.OnlineRecognizer(cfg);
  }

  // Convenience: Configure streaming Zipformer model from bundled assets
  // Defaults to Chinese streaming zipformer under assets/models/asr/
  Future<void> configureZipformerFromAssets({
    String baseDir =
        'assets/models/asr/sherpa-onnx-streaming-zipformer-zh-fp16-2025-06-30',
    int sampleRate = 16000,
    int featDim = 80,
  }) async {
    try {
      _stream = null;
    } catch (_) {}
    try {
      _recognizer = null;
    } catch (_) {}

    _ensureSherpaInitialized();

    // Asset paths inside the bundle
    final tokensAsset = '$baseDir/tokens.txt';
    final encoderAsset = '$baseDir/encoder.fp16.onnx';
    final decoderAsset = '$baseDir/decoder.fp16.onnx';
    final joinerAsset = '$baseDir/joiner.fp16.onnx';

    // On native platforms copy to a real file path; on Web, return asset path
    final tokens = await writeAssetToFile(tokensAsset);
    final encoder = await writeAssetToFile(encoderAsset);
    final decoder = await writeAssetToFile(decoderAsset);
    final joiner = await writeAssetToFile(joinerAsset);

    final onlineModel = sherpa_onnx.OnlineModelConfig(
      tokens: tokens,
      transducer: sherpa_onnx.OnlineTransducerModelConfig(
        encoder: encoder,
        decoder: decoder,
        joiner: joiner,
      ),
    );

    final cfg = sherpa_onnx.OnlineRecognizerConfig(
      feat: sherpa_onnx.FeatureConfig(
          sampleRate: sampleRate, featureDim: featDim),
      model: onlineModel,
      decodingMethod: 'greedy_search',
      maxActivePaths: 4,
      enableEndpoint: true,
      rule1MinTrailingSilence: 2.4,
      rule2MinTrailingSilence: 1.2,
      rule3MinUtteranceLength: 20.0,
      hotwordsFile: '',
    );

    _recognizer = sherpa_onnx.OnlineRecognizer(cfg);
  }

  // Load default Zipformer model with a provider-level progress indicator
  Future<bool> loadDefaultModelWithProgress() async {
    if (_loadingModel) return false;
    _loadingModel = true;
    _lastError = null;
    notifyListeners();
    try {
      // 让出一帧，先渲染进度条/禁用按钮，再开始重活
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await configureZipformerFromAssets();
      return true;
    } catch (e) {
      _lastError = '$e';
      _lines.add('模型加载失败：$e');
      return false;
    } finally {
      _loadingModel = false;
      notifyListeners();
    }
  }

  Future<void> start() async {
    if (_running) return;
    _running = true;
    _recordingStartTime = DateTime.now();
    _lines.clear();
    _lastPartial = '';
    _pcmBuf.clear();
    
    // Start audio file recording (will be called from meeting room page with proper parameters)
    // await startRecordingToFile();

    // Auto-configure default model if missing
    if (_recognizer == null) {
      try {
        _lines.add('正在加载默认模型…');
        notifyListeners();
        // 让出一帧，避免 UI 不刷新
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await configureZipformerFromAssets();
      } catch (e) {
        _running = false;
        _lines.add('模型加载失败：$e');
        notifyListeners();
        return;
      }
    }

    notifyListeners();

    // Setup periodic decoder to avoid heavy work inside audio callbacks
    _decodeTimer?.cancel();
    _decodeTimer = Timer.periodic(const Duration(milliseconds: 60), (_) {
      if (!_running) return;
      if (_recognizer == null || _stream == null) return;
      try {
        // If VAD thinks we just ended an utterance, finalize current partial immediately
        if (_pendingVadFinalize) {
          _finalizeUtteranceByVad();
          _pendingVadFinalize = false;
        }
        _decodeAndUpdate();
      } catch (e) {
        _lines.add('解码出错：$e');
        notifyListeners();
      }
    });

    // Mobile path: Android/iOS via mic_stream
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        _running = false;
        _lines.add('麦克风权限被拒绝，无法开始聆听');
        notifyListeners();
        return;
      }
      try {
        final micStream = MicStream.microphone(
          sampleRate: 16000,
          audioFormat: AudioFormat.ENCODING_PCM_16BIT,
          channelConfig: ChannelConfig.CHANNEL_IN_MONO,
          audioSource: AudioSource.MIC,
        );
        if (_recognizer != null) {
          _stream = _recognizer!.createStream();
          _lines.add('麦克风已打开，开始识别...');
        } else {
          _lines.add('麦克风已打开（占位），未配置 ASR 模型');
        }
        notifyListeners();
        _micSub = micStream.listen((chunk) {
          if (!_running) return;
          if (_recognizer == null || _stream == null) {
            return; // no-op until configured
          }
          try {
            // Write raw audio data to file
            final audioData = Uint8List.fromList(chunk);
            _writeAudioDataToFile(audioData);
            
            // Accumulate raw bytes; only feed when we have enough samples
            _pcmBuf.add(audioData);
            final minBytes = _minSamplesPerPush * 2; // int16
            if (_pcmBuf.length >= minBytes) {
              final bytes = _pcmBuf.takeBytes();
              final float32 = _pcm16leBytesToFloat32(bytes);
              if (float32.isNotEmpty) {
                _stream!.acceptWaveform(samples: float32, sampleRate: 16000);
                // Also append to current utterance buffer for diarization
                _uttBuf.addAll(float32);
                // Feed VAD to segment utterances in real time
                _processVadOnSamples(float32);
                // Accumulate only when in speech (or if VAD disabled)
                if (!_enableEnergyVad || _vadInSpeech) {
                  _uttBuf.addAll(float32);
                }
              }
            }
          } catch (e) {
            _lines.add('音频处理出错（mobile）：$e');
            notifyListeners();
          }
        }, onError: (e) {
          if (!_running) return;
          _lines.add('麦克风采集出错：$e');
          notifyListeners();
        }, cancelOnError: false);
      } catch (e) {
        _lines.add('无法打开麦克风：$e');
        notifyListeners();
      }
      return;
    }

    // Desktop/Web: Prefer record for cross-platform streaming (Windows/macOS/Linux/Web)
    if (!_running) return;
    try {
      final hasPerm = await _recorder.hasPermission();
      if (!hasPerm) {
        _running = false;
        _lines.add('没有录音权限，无法开始聆听');
        notifyListeners();
        return;
      }
      final stream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ));
      if (_recognizer != null) {
        _stream = _recognizer!.createStream();
        _lines.add('麦克风已打开（桌面），开始识别...');
      } else {
        _lines.add('麦克风已打开（桌面），未配置 ASR 模型');
      }
      notifyListeners();
      _recordSub = stream.listen((data) {
        if (!_running) return;
        if (_recognizer == null || _stream == null) {
          return; // no-op
        }
        try {
          // Write raw audio data to file
          _writeAudioDataToFile(data);
          
          // Accumulate bytes; feed in bigger chunks to avoid feature underflow
          _pcmBuf.add(data);
          final minBytes = _minSamplesPerPush * 2; // int16
          if (_pcmBuf.length >= minBytes) {
            final bytes = _pcmBuf.takeBytes();
            final float32 = _pcm16leBytesToFloat32(bytes);
            if (float32.isNotEmpty) {
              _stream!.acceptWaveform(samples: float32, sampleRate: 16000);
              // Also append to current utterance buffer for diarization
              _uttBuf.addAll(float32);
              // Feed VAD to segment utterances in real time
              _processVadOnSamples(float32);
              // Accumulate only when in speech (or if VAD disabled)
              if (!_enableEnergyVad || _vadInSpeech) {
                _uttBuf.addAll(float32);
              }
            }
          }
        } catch (e) {
          _lines.add('音频处理出错（desktop）：$e');
          notifyListeners();
        }
      }, onError: (e) {
        if (!_running) return;
        _lines.add('录音流出错：$e');
        notifyListeners();
      }, cancelOnError: false);
    } catch (e) {
      _lines.add('无法开始录音：$e');
      notifyListeners();
      return;
    }
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    _recordingStartTime = null;
    
    // Stop audio file recording
    await stopRecordingToFile();
    
    try {
      await _micSub?.cancel();
    } catch (_) {}
    _micSub = null;
    try {
      await _recordSub?.cancel();
    } catch (_) {}
    _recordSub = null;
    try {
      _stream = null;
    } catch (_) {}
    try {
      _decodeTimer?.cancel();
    } catch (_) {}
    _decodeTimer = null;
    _pcmBuf.clear();
    _uttBuf.clear();
    _speakerCentroids.clear();
    // reset VAD state
    _vadInSpeech = false;
    _vadSpeechCount = 0;
    _vadSilenceCount = 0;
    _vadCarry.clear();
    _pendingVadFinalize = false;
    notifyListeners();
  }

  // Run offline speaker diarization (stub implementation for now)
  Future<List<DiarizationSegment>> diarizeWav({
    required String wavPath,
    String? segmentationModelPath,
    String? embeddingModelPath,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Web 平台暂不支持离线说话人日记');
    }

    // 确保原生绑定已初始化
    _ensureSherpaInitialized();

    try {
      // 解析模型与音频路径（支持从 assets 复制到临时文件再使用）
      final segModel = segmentationModelPath ??
          await writeAssetToFile(
              'assets/models/speaker_diarization/sherpa-onnx-pyannote-segmentation-3-0/model.onnx');
      final embModel = embeddingModelPath ??
          await writeAssetToFile(
              'assets/models/speaker_diarization/3dspeaker_speech_eres2net_base_sv_zh-cn_3dspeaker_16k.onnx');

      final resolvedWavPath = wavPath.startsWith('assets/')
          ? await writeAssetToFile(wavPath)
          : wavPath;

      // 构建配置
      final segmentationConfig =
          sherpa_onnx.OfflineSpeakerSegmentationModelConfig(
        pyannote: sherpa_onnx.OfflineSpeakerSegmentationPyannoteModelConfig(
          model: segModel,
        ),
      );

      final embeddingConfig = sherpa_onnx.SpeakerEmbeddingExtractorConfig(
        model: embModel,
      );

      // 自动估计说话人数（numClusters = -1），也可通过 threshold 调节聚类数量
      final clusteringConfig = sherpa_onnx.FastClusteringConfig(
        numClusters: -1,
        threshold: 0.5,
      );

      final config = sherpa_onnx.OfflineSpeakerDiarizationConfig(
        segmentation: segmentationConfig,
        embedding: embeddingConfig,
        clustering: clusteringConfig,
        minDurationOn: 0.2,
        minDurationOff: 0.5,
      );

      final sd = sherpa_onnx.OfflineSpeakerDiarization(config);

      // 读取波形并校验采样率
      final waveData = sherpa_onnx.readWave(resolvedWavPath);
      if (sd.sampleRate != waveData.sampleRate) {
        throw StateError(
            '期望采样率: ${sd.sampleRate}, 实际: ${waveData.sampleRate}。请先将音频重采样到 ${sd.sampleRate}Hz');
      }

      // 处理（带回调可用于显示进度，当前返回 0 表示继续）
      final segments = sd.processWithCallback(
        samples: waveData.samples,
        callback: (int processed, int total) {
          // 如需进度：double p = 100.0 * processed / total; 可在外层通过通知进度
          return 0;
        },
      );

      // 映射为简化的 UI 数据结构
      final results = <DiarizationSegment>[];
      for (final s in segments) {
        results.add(DiarizationSegment(
          start: s.start,
          end: s.end,
          speaker: s.speaker,
        ));
      }
      return results;
    } catch (e) {
      _lastError = '$e';
      notifyListeners();
      rethrow;
    }
  }

  // Decode and produce partial/final results with speaker-first processing
  void _decodeAndUpdate() {
    final r = _recognizer;
    final s = _stream;
    if (r == null || s == null) return;
    
    // 仅在足够帧可用时解码，避免特征帧不足触发内部断言
    while (r.isReady(s)) {
      r.decode(s);
    }
    
    final isEndpoint = r.isEndpoint(s);
    final result = r.getResult(s);
    final text = result.text;
    
    if (isEndpoint) {
      if (text.isNotEmpty) {
        // 近实时处理：先进行说话人识别，再处理语音转文字结果
        final speakerInfo = _processSpeakerFirst();
        final labeled = speakerInfo != null ? '[$speakerInfo] $text' : text;
        
        // 如果存在未终止的临时行，则在原位"定稿"，避免产生重复气泡
        if (_lastPartial.isNotEmpty && _lines.isNotEmpty) {
          _lines[_lines.length - 1] = labeled;
        } else {
          _lines.add(labeled);
        }
        _lastPartial = '';
        // reset utterance buffer after finalizing this segment
        _uttBuf.clear();
        notifyListeners();
      }
      r.reset(s);
    } else {
      // 对于部分结果，也尝试进行说话人识别（如果有足够的音频数据）
      if (text != _lastPartial) {
        _lastPartial = text;
        String displayText = text;
        
        // 如果有足够的音频数据，尝试进行说话人识别
        if (_uttBuf.length > 8000) { // 至少0.5秒的音频
          final speakerInfo = _processSpeakerFirst();
          if (speakerInfo != null) {
            displayText = '[$speakerInfo] $text';
          }
        }
        
        if (_lines.isEmpty) {
          _lines.add(displayText);
        } else {
          _lines[_lines.length - 1] = displayText;
        }
        notifyListeners();
      }
    }
  }
  
  // Process speaker identification first (near real-time)
  String? _processSpeakerFirst() {
    // If no embedder, try to load once (non-blocking best-effort)
    if (_embedder == null) {
      _ensureEmbedderLoaded();
      return null;
    }
    
    try {
      if (_uttBuf.isNotEmpty) {
        // Convert to Float32List
        final samples = Float32List.fromList(_uttBuf);
        // Create stream, feed samples, and compute embedding
        final stream = _embedder!.createStream();
        stream.acceptWaveform(sampleRate: 16000, samples: samples);
        stream.inputFinished();
        final emb = _embedder!.compute(stream);
        final spk = _assignSpeaker(emb);
        return 'S${spk + 1}';
      }
    } catch (e) {
      // Swallow errors and return null to avoid breaking ASR flow
      _lastError = '实时说话人识别失败：$e';
      // Don't notify listeners here to avoid excessive UI updates
    }
    return null;
  }

  int _assignSpeaker(Float32List emb) {
    final e = _l2Normalize(emb);
    if (_speakerCentroids.isEmpty) {
      _speakerCentroids.add(e);
      return 0;
    }
    // find best match
    double best = -1.0;
    int bestIdx = -1;
    for (var i = 0; i < _speakerCentroids.length; i++) {
      final sim = _cosineSim(e, _speakerCentroids[i]);
      if (sim > best) {
        best = sim;
        bestIdx = i;
      }
    }
    if (best >= _spkThreshold && bestIdx >= 0) {
      // update centroid as moving average
      final c = _speakerCentroids[bestIdx];
      for (var i = 0; i < c.length; i++) {
        c[i] = 0.9 * c[i] + 0.1 * e[i];
      }
      _speakerCentroids[bestIdx] = _l2Normalize(c);
      return bestIdx;
    } else {
      // Check if we can add a new speaker (respect max speakers limit)
      if (_maxSpeakers > 0 && _speakerCentroids.length >= _maxSpeakers) {
        // Force assign to the best matching existing speaker
        return bestIdx >= 0 ? bestIdx : 0;
      }
      _speakerCentroids.add(e);
      return _speakerCentroids.length - 1;
    }
  }

  Float32List _l2Normalize(Float32List v) {
    double sum = 0.0;
    for (var i = 0; i < v.length; i++) {
      sum += v[i] * v[i];
    }
    final norm = sum <= 0 ? 1.0 : math.sqrt(sum);
    final out = Float32List(v.length);
    for (var i = 0; i < v.length; i++) {
      out[i] = v[i] / norm;
    }
    return out;
  }

  double _cosineSim(Float32List a, Float32List b) {
    final n = math.min(a.length, b.length);
    double dot = 0.0;
    double na = 0.0;
    double nb = 0.0;
    for (var i = 0; i < n; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    if (na <= 0 || nb <= 0) return 0.0;
    return dot / (math.sqrt(na) * math.sqrt(nb));
  }

  // VAD helper methods
  void _processVadOnSamples(List<double> samples) {
    if (!_enableEnergyVad) return;

    // Simple energy-based VAD
    for (int i = 0; i < samples.length; i += _vadFrameSize) {
      final end = math.min(i + _vadFrameSize, samples.length);
      final frame = samples.sublist(i, end);

      // Compute energy
      double energy = 0.0;
      for (final sample in frame) {
        energy += sample * sample;
      }
      energy /= frame.length;

      // VAD decision
      if (energy > _vadEnergyThreshold) {
        if (!_vadInSpeech) {
          _vadSpeechCount++;
          if (_vadSpeechCount >= _vadTriggerFrames) {
            _vadInSpeech = true;
            _vadSilenceCount = 0;
          }
        } else {
          _vadSilenceCount = 0;
        }
      } else {
        if (_vadInSpeech) {
          _vadSilenceCount++;
          if (_vadSilenceCount >= _vadReleaseFrames) {
            _vadInSpeech = false;
            _vadSpeechCount = 0;
            _pendingVadFinalize = true;
          }
        } else {
          _vadSpeechCount = 0;
        }
      }
    }
  }

  void _finalizeUtteranceByVad() {
    if (_uttBuf.isNotEmpty) {
      // Force finalize current utterance for speaker diarization
      _pendingVadFinalize = false;
    }
  }

  // Convert PCM16LE bytes to float32 [-1, 1]
  static Float32List _pcm16leBytesToFloat32(Uint8List input) {
    // Ensure byte alignment: offset must be multiple of 2 and length must be even
    Uint8List bytes;
    if (input.offsetInBytes % 2 != 0) {
      // Re-copy to a new buffer starting at offset 0
      bytes = Uint8List.fromList(input);
    } else {
      bytes = input;
    }
    // Some platforms provide views over a larger buffer with non-zero offset
    // Normalize to a fresh buffer to guarantee offset 0 for safety
    if (bytes.offsetInBytes != 0) {
      bytes = Uint8List.fromList(bytes);
    }
    final evenLength = bytes.lengthInBytes & ~1; // make even
    if (evenLength <= 0) return Float32List(0);
    if (evenLength != bytes.lengthInBytes) {
      bytes = bytes.sublist(0, evenLength);
    }

    final int16 = Int16List.view(bytes.buffer, 0, evenLength >> 1);
    final float32 = Float32List(int16.length);
    for (var i = 0; i < int16.length; i++) {
      float32[i] = int16[i] / 32768.0;
    }
    return float32;
  }
}
