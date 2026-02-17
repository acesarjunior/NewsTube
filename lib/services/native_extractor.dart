import 'package:flutter/services.dart';

class NativeExtractor {
  static const _ch = MethodChannel('newstube/extractor');

  static Future<List<Map<String, dynamic>>> searchVideos(String query) async {
    final res = await _ch.invokeMethod('searchVideos', {'query': query});
    final list = (res as List).cast<dynamic>();
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<List<Map<String, dynamic>>> searchChannels(String query) async {
    final res = await _ch.invokeMethod('searchChannels', {'query': query});
    final list = (res as List).cast<dynamic>();
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<List<Map<String, dynamic>>> getChannelVideos({
    required String channelUrl,
    int limit = 30,
  }) async {
    final res = await _ch.invokeMethod('getChannelVideos', {
      'channelUrl': channelUrl,
      'limit': limit,
    });
    final list = (res as List).cast<dynamic>();
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<Map<String, dynamic>> getCaptions({
    required String url,
    String preferLang = 'pt',
  }) async {
    final res = await _ch.invokeMethod('getCaptions', {
      'url': url,
      'preferLang': preferLang,
    });
    return Map<String, dynamic>.from(res as Map);
  }
}
