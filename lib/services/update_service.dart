import 'dart:convert';
import 'package:http/http.dart' as http;

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

  static int compareTags(String a, String b) {
    final A = _parseSemVer(a);
    final B = _parseSemVer(b);
    for (var i = 0; i < 3; i++) {
      if (A[i] != B[i]) return A[i] - B[i];
    }
    return 0;
  }
}