import '../../../../../../../model/source.dart';

Source get globalblogingSource => _globalblogingSource;
Source _globalblogingSource = Source(
  name: "Global Bloging",
  baseUrl: "https://globalbloging.com",
  lang: "en",
  isNsfw: false,
  typeSource: "madara",
  iconUrl:
      "https://raw.githubusercontent.com/kodjodevf/mangayomi-extensions/main/dart/manga/multisrc/madara/src/en/globalbloging/icon.png",
  dateFormat: "dd MMMM yyyy",
  dateFormatLocale: "en_us",
);
