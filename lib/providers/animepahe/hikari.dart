import 'dart:convert';

import 'package:http/http.dart';
import 'package:provins/classes.dart';

import 'package:html/parser.dart' as html;

class StreamWish {
  Future<List<VideoStream>> extract(String streamUrl, {String? label, Map<String, String>? headersOverrides}) async {
    if (streamUrl.isEmpty) {
      throw Exception("ERROR: INVALID STREAM LINK");
    }

    final serverName = label ?? "streamwish";
    final res = await get(Uri.parse(streamUrl));
    final doc = html.parse(res);
    String streamLink = '';
    String? subtitles;
    String unpackedData = "";
    doc.querySelectorAll('script').forEach((element) {
      if (streamLink.isEmpty) {
        try {
          final regex = RegExp(r'file:\s*"(.*?)"');
          final link = regex.allMatches(element.innerHtml);
          if (link.isNotEmpty) {
            unpackedData = element.innerHtml;
            // print(unpackedData);
            streamLink = link.firstOrNull?[1].toString() ?? '';
          } else {
            throw new Exception("WRONG FORMAT!");
          }
        } catch (err) {
          // final regex = RegExp(r'eval\(function\(p,a,c,k,e,d\)');
          // final html = element.innerHtml;
          // final matched = regex.firstMatch(html);
          // if (matched != null) {
          //   final String data = JsUnpack(html).unpack();
          //   // print(data);
          //   unpackedData = data;
          //   final dataMatch = RegExp(r'sources:\s*\[([\s\S]*?)\]').allMatches(data).firstOrNull?[1] ?? '';
          //   streamLink = dataMatch.replaceAll(RegExp(r'{|}|\"|file:'), '');
          // }
        } finally {
          final subtitleData = RegExp(r'tracks:\[([\s\S]*?)\]').allMatches(unpackedData).firstOrNull;
          if (subtitleData != null) {
            subtitles = _extractEnglishSubtitleLink(subtitleData[1] ?? "");
          }
          final uri = Uri.tryParse(streamLink);
          if (uri == null || !uri.hasScheme) {
            final variables = streamLink.split("||");
            final extracted = _extractLinksObject(unpackedData);
            for (final variable in variables) {
              final parts = variable.split(".");
              if (parts.length == 2 && parts[0].trim() == 'links') {
                final key = parts[1].trim();
                final resolved = extracted[key];
                if (resolved != null)
                  streamLink = resolved;
                else
                  streamLink = "";
              }
            }
          }
        }
      }
    });
    if (streamLink.isEmpty) throw new Exception("Couldnt get any $serverName streams");
    return [
      VideoStream(
        server: serverName,
        link: streamLink,
        quality: "multi-quality",
        backup: false,
        isM3u8: streamLink.contains('.m3u8'),
        subtitle: subtitles,
        subtitleFormat:
            subtitles != null
                ? subtitles!.endsWith(".vtt")
                    ? "vtt"
                    : "ass"
                : null,
        customHeaders: headersOverrides ?? {"Referer": streamUrl, "Origin": "https://${Uri.parse(streamUrl).host}"},
      ),
    ];
  }

  String? _extractEnglishSubtitleLink(String input) {
    final regex = RegExp(
      r'\{[^}]*file\s*:\s*"([^"]+)"[^}]*label\s*:\s*"English"[^}]*kind\s*:\s*"captions"',
      caseSensitive: false,
      multiLine: true,
    );
    final match = regex.firstMatch(input);
    return match?.group(1);
  }

  Map<String, String> _extractLinksObject(String input) {
    final regex = RegExp(r'var\s+links\s*=\s*\{([\s\S]*?)\};');
    final match = regex.firstMatch(input);

    if (match == null) return {};

    final objectBody = match.group(1)!;
    final entries = RegExp(
      r'"?(\w+)"?\s*:\s*"((?:\\.|[^"\\])*)"',
    ).allMatches(objectBody).map((m) => MapEntry(m.group(1)!, m.group(2)!));

    return Map.fromEntries(entries);
  }
}

class Hikari extends AnimeProvider {
  @override
  String get providerName => "hikari";

  final apiUrl = "https://api.hikari.gg/api";

  @override
  Future<List<Map<String, String?>>> search(String query) async {
    // basically an anilist search
    final searchApi = "$apiUrl/anime/?sort=created_at&order=asc&page=1&search=$query";
    final response = await get(Uri.parse(searchApi));
    final json = jsonDecode(response.body);
    final List<Map<String, dynamic>> results = (json['results'] as List).cast();
    final List<Map<String, String?>> sr = [];
    for (final item in results) {
      final id = item['uid'];
      final cover = item['ani_poster'];
      final title = item['ani_name'];
      sr.add({'alias': "$id", 'imageUrl': cover, 'name': title});
    }
    return sr;
  }

  @override
  Future<List<Map<String, dynamic>>> getAnimeEpisodeLink(String aliasId, {bool dub = false}) async {
    final infoApi = "$apiUrl/episode/uid/$aliasId";
    final apiRes = await get(Uri.parse(infoApi));
    final List<Map<String, dynamic>> jsoned = (jsonDecode(apiRes.body) as List).cast();
    final eps = <Map<String, dynamic>>[];
    for (int i = 0; i < jsoned.length; i++) {
      final it = jsoned[i];
      final epNum = it['ep_id_name'];
      final title = it['ep_name'];
      eps.add({'episodeNumber': int.tryParse(epNum ?? '0'), 'episodeLink': "$aliasId+$epNum", 'episodeTitle': title});
    }
    return eps;
  }

  @override
  Future<void> getStreams(
    String episodeId,
    Function(List<VideoStream> p1, bool p2) update, {
    bool dub = false,
    String? metadata,
  }) async {
    final embedApi = "$apiUrl/embed/${episodeId.split('+').join('/')}"; // in $apiurl/$id/epNum form
    final resp = await get(Uri.parse(embedApi));
    final List<Map<String, dynamic>> jsoned = (jsonDecode(resp.body) as List).cast();

    final totalStreams = jsoned.length;
    int streamsPushed = 0;

    final sw = StreamWish();

    for (final stream in jsoned) {
      if ((stream['embed_name'] as String? ?? "").toLowerCase() == "playerx") {
        // cus we dont have its extractor!
        streamsPushed++;
        continue;
      }
      final embedLink = stream['embed_frame'] as String;
      switch (stream['embed_name'].toLowerCase()) {
        case 'sv':
          {
            sw
                .extract(
                  embedLink,
                  label: "SV",
                  headersOverrides: {
                    'Referer': embedLink,
                    'Origin': "https://${Uri.parse(embedLink).host}",
                    'Accept': "*/*",
                  },
                )
                .then((val) => update(val, streamsPushed == totalStreams));
            break;
          }
        case 'streamwish':
          sw.extract(embedLink, label: "StreamWish").then((val) => update(val, streamsPushed == totalStreams));
          break;
        // case
      }
    }
  }

  @override
  Future<void> getDownloadSources(
    String episodeUrl,
    Function(List<VideoStream> p1, bool p2) update, {
    bool dub = false,
    String? metadata,
  }) {
    // TODO: implement getDownloadSources
    throw UnimplementedError();
  }
}
