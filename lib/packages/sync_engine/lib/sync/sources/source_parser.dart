import '../models/source_config.dart';

abstract class SourceParser {
  SourceType get sourceType;
  bool canParse(String url);
  Future<SourceConfig> parseUrlToSourceConfig(String url);
  String getSourceFolderName(String url);
}
