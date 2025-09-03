// Web fallback: assets are served via HTTP, but native plugins like sherpa_onnx
// are not available on Web. This stub keeps the same API so code compiles.
Future<String> writeAssetToFile(String assetPath) async {
  // On Web we simply return the asset path; callers should gate usage on kIsWeb
  // and avoid passing these paths to native plugins.
  return assetPath;
}