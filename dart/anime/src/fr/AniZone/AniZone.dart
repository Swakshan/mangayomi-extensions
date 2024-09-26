import 'package:mangayomi/bridge_lib.dart';
import 'dart:convert';

class AniZone extends MProvider {
  AniZone({required this.source});

  final MSource source;
  final Client client = Client(source);

  @override
  bool get supportsLatest => true;

  @override
  Map<String, String> get headers => {};

  // Constants for the xpath
  static const String urlXpath =
      '//*[contains(@class,"flw-item item-qtip")]/div[@class="film-poster"]/a/@href';
  static const String nameXpath =
      '//*[contains(@class,"flw-item item-qtip")]/div[@class="film-detail"]/h3/text()';
  static const String imageXpath =
      '//*[contains(@class,"flw-item item-qtip")]/div[@class="film-poster"]/img/@data-src';

  // Methods for fetching the manga list (popular, latest & search)
  Future<MPages> _getMangaList(String url) async {
    final doc = (await client.get(Uri.parse(url))).body;
    List<MManga> animeList = [];

    final urls = xpath(doc, urlXpath);
    final names = xpath(doc, nameXpath);
    final images = xpath(doc, imageXpath);

    if (urls.isEmpty || names.isEmpty || images.isEmpty) {
      return MPages([], false);
    }

    for (var i = 0; i < names.length; i++) {
      MManga anime = MManga();
      anime.name = names[i];
      anime.imageUrl = images[i];
      anime.link = urls[i];
      animeList.add(anime);
    }

    return MPages(animeList, urls.isNotEmpty);
  }

  @override
  Future<MPages> getPopular(int page) async {
    return _getMangaList("${source.baseUrl}/most-popular/?page=$page");
  }

  @override
  Future<MPages> getLatestUpdates(int page) async {
    return _getMangaList("${source.baseUrl}/recently-added/?page=$page");
  }

  @override
  Future<MPages> search(String query, int page, FilterList filterList) async {
    String baseUrl = "${source.baseUrl}/filter?keyword=$query";

    Map<String, List<String>> filterMap = {
      "type": [],
      "status": [],
      "season": [],
      "lang": [],
      "genre": []
    };

    // Regroupement des filtres avec une logique générique
    final filterHandlers = {
      "TypeFilter": "type",
      "LanguageFilter": "lang",
      "SaisonFilter": "season",
      "StatusFilter": "status",
      "GenreFilter": "genre"
    };

    for (var filter in filterList.filters) {
      if (filterHandlers.containsKey(filter.type)) {
        var key = filterHandlers[filter.type]!;
        for (var stateItem in filter.state as List) {
          if (stateItem.state == true) {
            filterMap[key]?.add(stateItem.value as String);
          }
        }
      }
    }

    //add filters to the url dynamically
    for (var entry in filterMap.entries) {
      List<String> values = entry.value;
      if (values.isNotEmpty) {
        baseUrl += '&${entry.key}=${values.join("%2C")}';
      }
    }

    return _getMangaList("$baseUrl&page=$page");
  }

  Future<MManga> getDetail(String url) async {
    MManga anime = MManga();
    try {
      final doc = (await client.get(Uri.parse(url))).body;
      final description = xpath(doc, '//p[contains(@class,"short")]/text()');
      anime.description = description.isNotEmpty ? description.first : "";

      final statusList = xpath(doc,
          '//div[contains(@class,"col2")]//div[contains(@class,"item")]//div[contains(@class,"item-content")]/text()');
      if (statusList.isNotEmpty) {
        if (statusList[0] == "Terminer") {
          anime.status = MStatus.completed;
        } else if (statusList[0] == "En cours") {
          anime.status = MStatus.ongoing;
        } else {
          anime.status = MStatus.unknown;
        }
      } else {
        anime.status = MStatus.unknown;
      }

      anime.genre = xpath(doc,
          '//div[contains(@class,"item")]//div[contains(@class,"item-content")]//a[contains(@href,"genre")]/text()');

      final regex = RegExp(r'(\d+)$');
      final match = regex.firstMatch(url);

      if (match == null) {
        throw Exception('Numéro de l\'épisode non trouvé dans l\'URL.');
      }

      final res = (await client.get(Uri.parse(
              "${source.baseUrl}/ajax/episode/list/${match.group(1)}")))
          .body;

      final titles = xpath(res.replaceAll(r'\', ' '),
          '//div[contains(@class,"ss-list")]//a/@title');
      final urls = xpath(res.replaceAll(r'\', ' '),
          '//div[contains(@class,"ss-list")]//a/@href');

      List<MChapter> episodesList = [];

      // Associer chaque titre à son URL et récupérer les vidéos
      for (int i = 0; i < titles.length; i++) {
        MChapter episode = MChapter();
        episode.name = titles[i];

        List<Map<String, String>> videoList = [];

        final videoMatch = regex.firstMatch(urls[i]);
        if (videoMatch == null) {
          throw Exception(
              'Numéro de l\'épisode non trouvé dans l\'URL pour les vidéos.');
        }

        final videoRes = (await client.get(
          Uri.parse(
              "${source.baseUrl}/ajax/episode/servers?episodeId=${videoMatch.group(1)}"),
          headers: {'Referer': "${source.baseUrl}/${urls[i]}"},
        ))
            .body;

        final lang = xpath(videoRes.replaceAll(r'\', ''),
            '//div[contains(@class,"item server-item")]/@data-type');
        final links = xpath(videoRes.replaceAll(r'\', ''),
            '//div[contains(@class,"item server-item")]/@data-id');
        final name_players = xpath(videoRes.replaceAll(r'\', ''),
            '//div[contains(@class,"item server-item")]/text()');

        for (int j = 0; j < links.length; j++) {
          // schema of players https://v1.animesz.xyz/ajax/episode/servers?episodeId=(id_episode)
          // schema or url https://v1.animesz.xyz/ajax/episode/sources?id=(player_id)&epid=(id_episode)
          if (name_players.isNotEmpty && name_players[j] == "sibnet") {
            final playerUrl =
                "https://video.sibnet.ru/shell.php?videoid=${links[j]}";
            videoList.add({"lang": lang[j], "player": playerUrl});
          } else if (name_players.isNotEmpty && name_players[j] == "sendvid") {
            final playerUrl = "https://sendvid.com/embed/${links[j]}";
            videoList.add({"lang": lang[j], "player": playerUrl});
          } else if (name_players.isNotEmpty && name_players[j] == "VidCDN") {
            final playerUrl =
                "https://r.vidcdn.xyz/v1/api/get_sources/${links[j].replaceFirst(RegExp(r'vidcdn$'), '')}";
            videoList.add({"lang": lang[j], "player": playerUrl});
          } else if (name_players.isNotEmpty && name_players[j] == "Voe") {
            final playerUrl = "https://voe.sx/e/${links[j]}";
            videoList.add({"lang": lang[j], "player": playerUrl});
          } else if (name_players.isNotEmpty && name_players[j] == "Fmoon") {
            final playerUrl =
                "https://filemoon.sx/e/${links[j]}&data-realid=${links[j]}&epid=${videoMatch.group(1)}";
            videoList.add({"lang": lang[j], "player": playerUrl});
          }
        }
        episode.url = json.encode(videoList);
        episodesList.add(episode);
      }

      anime.chapters = episodesList.reversed.toList();

      return anime;
    } catch (e) {
      throw Exception('Erreur lors de la récupération des détails: $e');
    }
  }

  @override
  Future<List<MVideo>> getVideoList(String url) async {
    final players = json.decode(url);
    List<MVideo> videos = [];
    for (var player in players) {
      String lang = (player["lang"] as String).toUpperCase();
      String playerUrl = player["player"];
      List<MVideo> a = [];
      if (playerUrl.contains("sendvid")) {
        a = await sendVidExtractorr(playerUrl, "$lang ");
      } else if (playerUrl.contains("sibnet.ru")) {
        a = await sibnetExtractor(playerUrl, lang);
      } else if (playerUrl.contains("voe.sx")) {
        a = await voeExtractor(playerUrl, lang);
      } else if (playerUrl.contains("vidcdn")) {
        a = await vidcdnExtractor(playerUrl, lang);
      } else if (playerUrl.contains("filemoon")) {
        a = await filemoonExtractor(playerUrl, lang, "");
      }
      videos.addAll(a);
    }

    return sortVideos(videos, source.id);
  }

  @override
  Future<List<String>> getPageList(String url) async {
    // TODO: implement
  }

  @override
  List<dynamic> getFilterList() {
    return [
      GroupFilter("TypeFilter", "Type", [
        CheckBoxFilter("Film", "1"),
        CheckBoxFilter("Anime", "2"),
        CheckBoxFilter("OVA", "3"),
        CheckBoxFilter("ONA", "4"),
        CheckBoxFilter("Special", "5"),
        CheckBoxFilter("Music", "6"),
      ]),
      GroupFilter("LanguageFilter", "Langue", [
        CheckBoxFilter("VF", "3"),
        CheckBoxFilter("VOSTFR", "4"),
        CheckBoxFilter("Multicc", "2"),
        CheckBoxFilter("EN", "1"),
      ]),
      GroupFilter("SaisonFilter", "Saison", [
        CheckBoxFilter("Printemps", "1"),
        CheckBoxFilter("Été", "2"),
        CheckBoxFilter("Automne", "3"),
        CheckBoxFilter("Hiver", "4"),
      ]),
      GroupFilter("StatusFilter", "Statut", [
        CheckBoxFilter("Terminés", "1"),
        CheckBoxFilter("En cours", "2"),
        CheckBoxFilter("Pas encore diffusés", "3"),
      ]),
      GroupFilter("GenreFilter", "Genre", [
        CheckBoxFilter("Action", "1"),
        CheckBoxFilter("Aventure", "2"),
        CheckBoxFilter("Voitures", "3"),
        CheckBoxFilter("Comédie", "4"),
        CheckBoxFilter("Démence", "5"),
        CheckBoxFilter("Démons", "6"),
        CheckBoxFilter("Drame", "8"),
        CheckBoxFilter("Ecchi", "9"),
        CheckBoxFilter("Fantastique", "10"),
        CheckBoxFilter("Jeu", "11"),
        CheckBoxFilter("Harem", "35"),
        CheckBoxFilter("Historique", "13"),
        CheckBoxFilter("Horreur", "14"),
        CheckBoxFilter("Isekai", "44"),
        CheckBoxFilter("Josei", "43"),
        CheckBoxFilter("Enfants", "25"),
        CheckBoxFilter("Magie", "16"),
        CheckBoxFilter("Arts martiaux", "17"),
        CheckBoxFilter("Mecha", "18"),
        CheckBoxFilter("Militaire", "38"),
        CheckBoxFilter("Musique", "19"),
        CheckBoxFilter("Mystère", "7"),
        CheckBoxFilter("Parodie", "20"),
        CheckBoxFilter("Police", "39"),
        CheckBoxFilter("Psychologique", "40"),
        CheckBoxFilter("Romance", "22"),
        CheckBoxFilter("Samouraï", "21"),
        CheckBoxFilter("École", "23"),
        CheckBoxFilter("Science-Fiction", "24"),
        CheckBoxFilter("Seinen", "42"),
        CheckBoxFilter("Shoujo Ai", "26"),
        CheckBoxFilter("Shoujo", "25"),
        CheckBoxFilter("Shounen Ai", "28"),
        CheckBoxFilter("Tranche de vie", "36"),
        CheckBoxFilter("Shounen", "27"),
        CheckBoxFilter("Espace", "29"),
        CheckBoxFilter("Sports", "30"),
        CheckBoxFilter("Super Pouvoir", "31"),
        CheckBoxFilter("Surnaturel", "37"),
        CheckBoxFilter("Vampire", "32"),
        CheckBoxFilter("Yaoi", "33"),
        CheckBoxFilter("Yuri", "34"),
      ])
    ];
  }

  @override
  List<dynamic> getSourcePreferences() {
    return [
      ListPreference(
          key: "preferred_quality",
          title: "Qualité préférée",
          summary: "",
          valueIndex: 0,
          entries: ["1080p", "720p", "480p", "360p"],
          entryValues: ["1080", "720", "480", "360"]),
      ListPreference(
          key: "voices_preference",
          title: "Préférence des voix",
          summary: "",
          valueIndex: 0,
          entries: ["Préférer VOSTFR", "Préférer VF"],
          entryValues: ["vostfr", "vf"]),
    ];
  }

  List<MVideo> sortVideos(List<MVideo> videos, int sourceId) {
    String quality = getPreferenceValue(sourceId, "preferred_quality");
    String voice = getPreferenceValue(sourceId, "voices_preference");

    videos.sort((MVideo a, MVideo b) {
      int qualityMatchA = 0;
      if (a.quality.contains(quality) &&
          a.quality.toLowerCase().contains(voice)) {
        qualityMatchA = 1;
      }
      int qualityMatchB = 0;
      if (b.quality.contains(quality) &&
          b.quality.toLowerCase().contains(voice)) {
        qualityMatchB = 1;
      }
      if (qualityMatchA != qualityMatchB) {
        return qualityMatchB - qualityMatchA;
      }

      final regex = RegExp(r'(\d+)p');
      final matchA = regex.firstMatch(a.quality);
      final matchB = regex.firstMatch(b.quality);
      final int qualityNumA = int.tryParse(matchA?.group(1) ?? '0') ?? 0;
      final int qualityNumB = int.tryParse(matchB?.group(1) ?? '0') ?? 0;
      return qualityNumB - qualityNumA;
    });
    return videos;
  }

  Future<List<MVideo>> sendVidExtractorr(String url, String prefix) async {
    final res = (await client.get(Uri.parse(url))).body;
    final document = parseHtml(res);
    final masterUrl = document.selectFirst("source#video_source")?.attr("src");
    print(masterUrl);
    if (masterUrl == null) return [];
    final masterHeaders = {
      "Accept": "*/*",
      "Host": Uri.parse(masterUrl).host,
      "Origin": "https://${Uri.parse(url).host}",
      "Referer": "https://${Uri.parse(url).host}/",
    };
    List<MVideo> videos = [];
    if (masterUrl.contains(".m3u8")) {
      final masterPlaylistRes = (await client.get(Uri.parse(masterUrl))).body;

      for (var it in substringAfter(masterPlaylistRes, "#EXT-X-STREAM-INF:")
          .split("#EXT-X-STREAM-INF:")) {
        final quality =
            "${substringBefore(substringBefore(substringAfter(substringAfter(it, "RESOLUTION="), "x"), ","), "\n")}p";

        String videoUrl = substringBefore(substringAfter(it, "\n"), "\n");

        if (!videoUrl.startsWith("http")) {
          videoUrl =
              "${masterUrl.split("/").sublist(0, masterUrl.split("/").length - 1).join("/")}/$videoUrl";
        }
        final videoHeaders = {
          "Accept": "*/*",
          "Host": Uri.parse(videoUrl).host,
          "Origin": "https://${Uri.parse(url).host}",
          "Referer": "https://${Uri.parse(url).host}/",
        };
        var video = MVideo();
        video
          ..url = videoUrl
          ..originalUrl = videoUrl
          ..quality = prefix + "Sendvid:$quality"
          ..headers = videoHeaders;
        videos.add(video);
      }
    } else {
      var video = MVideo();
      video
        ..url = masterUrl
        ..originalUrl = masterUrl
        ..quality = prefix + "Sendvid:default"
        ..headers = masterHeaders;
      videos.add(video);
    }

    return videos;
  }

  Future<List<MVideo>> vidcdnExtractor(String url, String prefix) async {
    final res = await client.get(Uri.parse(url));
    if (res.statusCode != 200) {
      print("Erreur lors de la récupération de la page : ${res.statusCode}");
      return [];
    }
    final jsonResponse = jsonDecode(res.body);

    String masterUrl = jsonResponse['sources'][0]['file'] ?? '';
    final quality = jsonResponse['quality'] ?? '';

    List<MVideo> videos = [];

    final masterPlaylistRes = await client.get(Uri.parse(masterUrl));
    if (masterPlaylistRes.statusCode != 200) {
      print(
          "Error lors de la récupération de la playlist M3U8 : ${masterPlaylistRes.statusCode}");
      return [];
    }

    final masterPlaylistBody = masterPlaylistRes.body;

    final playlistLines = masterPlaylistBody.split("\n");

    for (int i = 0; i < playlistLines.length; i++) {
      final line = playlistLines[i];
      if (line.startsWith("#EXT-X-STREAM-INF")) {
        final resolutionLine = line.split("RESOLUTION=").last;
        final resolution = resolutionLine.split(",").first;
        final width = int.parse(resolution.split("x").first);
        final height = int.parse(resolution.split("x").last);

        String videoQuality;
        if (height >= 1080) {
          videoQuality = "1080p";
        } else if (height >= 720) {
          videoQuality = "720p";
        } else if (height >= 480) {
          videoQuality = "480p";
        } else if (height >= 360) {
          videoQuality = "360p";
        } else {
          videoQuality = "${height}p";
        }

        String videoUrl = playlistLines[i + 1].trim();

        if (!videoUrl.startsWith("http")) {
          videoUrl =
              "${masterUrl.substring(0, masterUrl.lastIndexOf('/'))}/$videoUrl";
        }

        var video = MVideo();
        video
          ..url = masterUrl
          ..originalUrl = masterUrl
          ..quality = "$prefix VidCDN:$videoQuality";
        videos.add(video);
      }
    }
    return videos;
  }
}

AniZone main(MSource source) {
  return AniZone(source: source);
}
