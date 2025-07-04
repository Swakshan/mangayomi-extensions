import '../../../../../../../model/source.dart';

Source get nexoscansSource => _nexoscansSource;
Source _nexoscansSource = Source(
  name: "Nexo Scans",
  baseUrl: "https://nexoscans.net",
  lang: "pt-br",
  isNsfw: false,
  typeSource: "madara",
  iconUrl:
      "https://raw.githubusercontent.com/kodjodevf/mangayomi-extensions/main/dart/manga/multisrc/madara/src/pt/nexoscans/icon.png",
  dateFormat: "dd/MM/yyyy",
  dateFormatLocale: "en_us",
);
