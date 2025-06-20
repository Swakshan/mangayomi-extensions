import '../../../../../../../model/source.dart';

Source get housemangasSource => _housemangasSource;
Source _housemangasSource = Source(
  name: "HouseMangas",
  baseUrl: "https://housemangas.com",
  lang: "es",
  isNsfw: false,
  typeSource: "madara",
  iconUrl:
      "https://raw.githubusercontent.com/kodjodevf/mangayomi-extensions/main/dart/manga/multisrc/madara/src/es/housemangas/icon.png",
  dateFormat: "MMMM dd, yyyy",
  dateFormatLocale: "es",
);
