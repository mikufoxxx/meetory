import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;

class ModelDownloadService {
  static const Map<String, List<String>> modelUrls = {
    'asr': [
      'http://gitraw.techox.cc/https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-zipformer-zh-fp16-2025-06-30.tar.bz2',
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-zipformer-zh-fp16-2025-06-30.tar.bz2'
    ],
    'speaker_segmentation': [
      'http://gitraw.techox.cc/https://github.com/k2-fsa/sherpa-onnx/releases/download/speaker-segmentation-models/sherpa-onnx-pyannote-segmentation-3-0.tar.bz2',
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/speaker-segmentation-models/sherpa-onnx-pyannote-segmentation-3-0.tar.bz2'
    ],
    'speaker_recognition': [
      'http://gitraw.techox.cc/https://github.com/k2-fsa/sherpa-onnx/releases/download/speaker-recongition-models/3dspeaker_speech_eres2net_base_sv_zh-cn_3dspeaker_16k.onnx',
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/speaker-recongition-models/3dspeaker_speech_eres2net_base_sv_zh-cn_3dspeaker_16k.onnx'
    ],
    'vad': [
      'http://gitraw.techox.cc/https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/ten-vad.onnx',
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/ten-vad.onnx'
    ],
  };

  static const Map<String, String> modelTargetDirs = {
    'asr': 'asr',
    'speaker_segmentation': 'speaker_diarization',
    'speaker_recognition': 'speaker_diarization',
    'vad': 'VAD',
  };

  /// 检查所有模型是否已下载
  static Future<bool> areAllModelsDownloaded() async {
    final appDir = await getApplicationDocumentsDirectory();
    final assetsModelsDir = Directory(path.join(appDir.path, 'assets', 'models'));
    
    // 检查每个模型目录是否存在且不为空
    for (final targetDir in modelTargetDirs.values.toSet()) {
      final modelDir = Directory(path.join(assetsModelsDir.path, targetDir));
      if (!await modelDir.exists()) return false;
      
      final files = await modelDir.list().toList();
      if (files.isEmpty) return false;
    }
    
    return true;
  }

  /// 下载单个模型
  static Future<bool> downloadModel(
    String modelKey, {
    String sourceType = 'mirror',
    String? customMirror,
    Function(double, {String? speed, String? downloadedSize, String? totalSize})? onProgress
  }) async {
    try {
      final baseUrls = modelUrls[modelKey];
      final targetDir = modelTargetDirs[modelKey];
      
      if (baseUrls == null || targetDir == null) {
        print('未知的模型类型: $modelKey');
        return false;
      }
      
      // 根据sourceType选择URL
      List<String> urls = [];
      if (sourceType == 'direct') {
        // 使用直链（GitHub原始链接）
        urls = [baseUrls[1]]; // 第二个是直链
      } else if (sourceType == 'custom' && customMirror != null && customMirror.isNotEmpty) {
        // 使用自定义镜像源
        final directUrl = baseUrls[1];
        final customUrl = directUrl.replaceFirst('https://github.com', 'http://$customMirror/https://github.com');
        urls = [customUrl, baseUrls[1]]; // 自定义镜像失败后回退到直链
      } else {
        // 默认使用镜像源
        urls = baseUrls; // 使用所有URL（镜像源优先）
      }
      
      final appDir = await getApplicationDocumentsDirectory();
      final assetsModelsDir = Directory(path.join(appDir.path, 'assets', 'models', targetDir));
      await assetsModelsDir.create(recursive: true);

      print('开始下载模型: $modelKey，使用源类型: $sourceType');
      
      // 尝试每个URL，直到成功或全部失败
        for (int i = 0; i < urls.length; i++) {
          final url = urls[i];
          try {
            print('尝试下载链接 ${i + 1}/${urls.length}: $url');
           
           final request = http.Request('GET', Uri.parse(url));
           final response = await http.Client().send(request).timeout(
             const Duration(minutes: 10),
             onTimeout: () {
               throw Exception('下载超时');
             },
           );
           
           if (response.statusCode == 200) {
             final fileName = path.basename(Uri.parse(url).path);
             final isArchive = fileName.endsWith('.tar.bz2') || fileName.endsWith('.tar.gz');
             final contentLength = response.contentLength ?? 0;
             
             final bytes = <int>[];
             int downloadedBytes = 0;
             final stopwatch = Stopwatch()..start();
             
             await for (final chunk in response.stream) {
               bytes.addAll(chunk);
               downloadedBytes += chunk.length;
               
               if (onProgress != null && contentLength > 0) {
                 final progress = downloadedBytes / contentLength;
                 final elapsedSeconds = stopwatch.elapsedMilliseconds / 1000;
                 final speed = elapsedSeconds > 0 ? (downloadedBytes / elapsedSeconds) : 0;
                 
                 String speedText = '';
                 if (speed > 1024 * 1024) {
                   speedText = '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
                 } else if (speed > 1024) {
                   speedText = '${(speed / 1024).toStringAsFixed(1)} KB/s';
                 } else {
                   speedText = '${speed.toStringAsFixed(0)} B/s';
                 }
                 
                 String downloadedText = '';
                 if (downloadedBytes > 1024 * 1024) {
                   downloadedText = '${(downloadedBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
                 } else if (downloadedBytes > 1024) {
                   downloadedText = '${(downloadedBytes / 1024).toStringAsFixed(1)} KB';
                 } else {
                   downloadedText = '$downloadedBytes B';
                 }
                 
                 String totalText = '';
                 if (contentLength > 1024 * 1024) {
                   totalText = '${(contentLength / (1024 * 1024)).toStringAsFixed(1)} MB';
                 } else if (contentLength > 1024) {
                   totalText = '${(contentLength / 1024).toStringAsFixed(1)} KB';
                 } else {
                   totalText = '$contentLength B';
                 }
                 
                 onProgress(progress, speed: speedText, downloadedSize: downloadedText, totalSize: totalText);
               }
             }
             
             if (isArchive) {
               // 解压缩文件
               await _extractArchive(Uint8List.fromList(bytes), assetsModelsDir.path, fileName);
             } else {
               // 直接保存文件
               final file = File(path.join(assetsModelsDir.path, fileName));
               await file.writeAsBytes(bytes);
             }
 
             print('模型下载完成: $modelKey');
             return true;
           } else {
             print('下载失败，状态码: ${response.statusCode}，尝试下一个链接');
           }
         } catch (e) {
           print('下载链接失败: $e');
           if (i == urls.length - 1) {
             // 最后一个链接也失败了
             print('所有下载链接都失败了');
           } else {
             print('尝试下一个链接');
           }
         }
       }
      
      print('模型下载失败: $modelKey');
      return false;
    } catch (e) {
      print('下载模型失败 $modelKey: $e');
      return false;
    }
  }

  /// 下载所有模型
  static Future<bool> downloadAllModels({
    String sourceType = 'mirror',
    String? customMirror,
    Function(String, double, {String? speed, String? downloadedSize, String? totalSize, int? fileIndex})? onProgress
  }) async {
    final models = modelUrls.keys.toList();
    
    for (int i = 0; i < models.length; i++) {
      final modelKey = models[i];
      final success = await downloadModel(
        modelKey, 
        sourceType: sourceType,
        customMirror: customMirror,
        onProgress: (progress, {String? speed, String? downloadedSize, String? totalSize}) {
          if (onProgress != null) {
            final overallProgress = (i + progress) / models.length;
            onProgress(modelKey, overallProgress, speed: speed, downloadedSize: downloadedSize, totalSize: totalSize, fileIndex: i + 1);
          }
        }
      );
      
      if (!success) {
        return false;
      }
    }
    
    return true;
  }

  /// 解压缩文件
  static Future<void> _extractArchive(Uint8List archiveBytes, String targetPath, String fileName) async {
    try {
      Archive archive;
      
      if (fileName.endsWith('.tar.bz2')) {
        // 解压 bz2
        final decompressed = BZip2Decoder().decodeBytes(archiveBytes);
        // 解压 tar
        archive = TarDecoder().decodeBytes(decompressed);
      } else if (fileName.endsWith('.tar.gz')) {
        // 解压 gzip
        final decompressed = GZipDecoder().decodeBytes(archiveBytes);
        // 解压 tar
        archive = TarDecoder().decodeBytes(decompressed);
      } else {
        throw Exception('不支持的压缩格式: $fileName');
      }

      // 提取文件
      for (final file in archive) {
        if (file.isFile) {
          final filePath = path.join(targetPath, file.name);
          final outputFile = File(filePath);
          await outputFile.create(recursive: true);
          await outputFile.writeAsBytes(file.content as List<int>);
        }
      }
    } catch (e) {
      print('解压缩失败: $e');
      rethrow;
    }
  }

  /// 从本地目录导入模型文件
  static Future<bool> importModelsFromDirectory(
    String sourceDirectory,
    {Function(String, double)? onProgress}
  ) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final models = modelUrls.keys.toList();
      
      // 检查源目录中是否包含所有必需的模型文件
      final sourceDir = Directory(sourceDirectory);
      if (!await sourceDir.exists()) {
        print('源目录不存在: $sourceDirectory');
        return false;
      }
      
      // 验证所有模型文件是否存在
      for (String modelKey in models) {
        final targetDir = modelTargetDirs[modelKey]!;
        final modelDir = Directory(path.join(sourceDirectory, targetDir));
        
        if (!await modelDir.exists()) {
          print('模型目录不存在: ${modelDir.path}');
          return false;
        }
        
        // 检查目录中是否有文件
        final files = await modelDir.list().toList();
        if (files.isEmpty) {
          print('模型目录为空: ${modelDir.path}');
          return false;
        }
      }
      
      print('开始导入模型文件...');
      
      // 复制所有模型文件
      for (int i = 0; i < models.length; i++) {
        final modelKey = models[i];
        final targetDir = modelTargetDirs[modelKey]!;
        
        if (onProgress != null) {
          onProgress(modelKey, i / models.length);
        }
        
        final sourceModelDir = Directory(path.join(sourceDirectory, targetDir));
        final targetModelDir = Directory(path.join(appDir.path, 'assets', 'models', targetDir));
        
        // 创建目标目录
        await targetModelDir.create(recursive: true);
        
        // 复制所有文件
        await for (final entity in sourceModelDir.list(recursive: true)) {
          if (entity is File) {
            final relativePath = path.relative(entity.path, from: sourceModelDir.path);
            final targetFile = File(path.join(targetModelDir.path, relativePath));
            
            // 确保目标文件的父目录存在
            await targetFile.parent.create(recursive: true);
            
            // 复制文件
            await entity.copy(targetFile.path);
            print('已复制: ${entity.path} -> ${targetFile.path}');
          }
        }
        
        print('模型 $modelKey 导入完成');
      }
      
      if (onProgress != null) {
        onProgress('完成', 1.0);
      }
      
      print('所有模型导入完成');
      return true;
      
    } catch (e) {
      print('导入模型时出错: $e');
      return false;
    }
  }

  /// 清理所有下载的模型
  static Future<void> clearAllModels() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final assetsModelsDir = Directory(path.join(appDir.path, 'assets', 'models'));
      
      if (await assetsModelsDir.exists()) {
        await assetsModelsDir.delete(recursive: true);
        await assetsModelsDir.create(recursive: true);
        
        // 重新创建子目录
        for (final targetDir in modelTargetDirs.values.toSet()) {
          final modelDir = Directory(path.join(assetsModelsDir.path, targetDir));
          await modelDir.create(recursive: true);
        }
      }
    } catch (e) {
      print('清理模型失败: $e');
    }
  }
}