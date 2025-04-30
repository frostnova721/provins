import 'dart:convert';

abstract class AnimeProvider {
  /// Name of the provider
  String get providerName;

  //should provide search results with keys: name, image, alias
  Future<List<Map<String, String?>>> search(String query);

  /// Should return a list of string that is the link to get to that episode
  Future<List<Map<String, dynamic>>> getAnimeEpisodeLink(String aliasId, { bool dub = false });

  /// The link format returned in the [getAnimeEpisodeLink] method should be
  /// parsed in this method
  Future<void> getStreams(String episodeId, Function(List<VideoStream>, bool) update, { bool dub = false, String? metadata });

  /// The link format returned in the [getAnimeEpisodeLink] method should be
  /// parsed in this method
  /// 
  /// This method should return a list of [VideoStream] objects containing direct download
  /// links to the episode
  Future<void> getDownloadSources(String episodeUrl, Function(List<VideoStream>, bool) update, {bool dub = false, String? metadata});
}

class VideoStream {
  final String quality;
  final String link;
  final bool isM3u8;
  final String? subtitle;
  final String? subtitleFormat;
  final String server;
  final bool backup;
  final Map<String, String>? customHeaders;

  VideoStream({
    required this.quality,
    required this.link,
    required this.isM3u8,
    required this.server,
    required this.backup,
    this.subtitleFormat,
    this.subtitle,
    this.customHeaders,
  });

  @override
  String toString() {
    return 'VideoStream(quality: $quality, link: $link, isM3u8: $isM3u8, subtitle: $subtitle, subtitleFormat: $subtitleFormat, server: $server, backup: $backup, customHeaders: $customHeaders)';
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'quality': quality,
      'link': link,
      'isM3u8': isM3u8,
      'subtitle': subtitle,
      'subtitleFormat': subtitleFormat,
      'server': server,
      'backup': backup,
      'customHeaders': customHeaders,
    };
  }

  factory VideoStream.fromMap(Map<String, dynamic> map) {
    return VideoStream(
      quality: map['quality'] as String,
      link: map['link'] as String,
      isM3u8: map['isM3u8'] as bool,
      subtitle: map['subtitle'] != null ? map['subtitle'] as String : null,
      subtitleFormat: map['subtitleFormat'] != null ? map['subtitleFormat'] : null,
      server: map['server'] as String,
      backup: map['backup'] as bool,
      customHeaders: map['customHeaders'] != null ? Map<String, String>.from((map['customHeaders'] as Map<String, String>)) : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory VideoStream.fromJson(String source) => VideoStream.fromMap(json.decode(source) as Map<String, dynamic>);
}
