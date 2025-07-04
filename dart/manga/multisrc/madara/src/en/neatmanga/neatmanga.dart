import '../../../../../../../model/source.dart';

Source get neatmangaSource => _neatmangaSource;
Source _neatmangaSource = Source(
  name: "NeatManga",
  baseUrl: "https://neatmanga.com",
  lang: "en",
  isNsfw: false,
  typeSource: "madara",
  iconUrl:
      "https://raw.githubusercontent.com/kodjodevf/mangayomi-extensions/main/dart/manga/multisrc/madara/src/en/neatmanga/icon.png",
  dateFormat: "dd MMM yyyy",
  dateFormatLocale: "en_us",
);
