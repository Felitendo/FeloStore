import 'package:easy_localization/easy_localization.dart';
import 'package:felostore/app_sources/html.dart';
import 'package:felostore/providers/source_provider.dart';

class DirectAPKLink extends AppSource {
  HTML html = HTML();

  DirectAPKLink() {
    neverAutoSelect = true;
    name = tr('directAPKLink');
    additionalSourceAppSpecificSettingFormItems = html
        .additionalSourceAppSpecificSettingFormItems
        .where((element) => element
            .where((element) => element.key == 'requestHeader')
            .isNotEmpty)
        .toList();
    excludeCommonSettingKeys = [
      'versionExtractionRegEx',
      'matchGroupToUse',
      'versionDetection',
      'useVersionCodeAsOSVersion',
      'apkFilterRegEx',
      'autoApkFilterByArch'
    ];
  }

  @override
  Future<Map<String, String>?> getRequestHeaders(
      Map<String, dynamic> additionalSettings,
      {bool forAPKDownload = false}) {
    return html.getRequestHeaders(additionalSettings,
        forAPKDownload: forAPKDownload);
  }

  @override
  Future<APKDetails> getLatestAPKDetails(
    String standardUrl,
    Map<String, dynamic> additionalSettings,
  ) async {
    var additionalSettingsNew =
        getDefaultValuesFromFormItems(html.combinedAppSpecificSettingFormItems);
    for (var s in additionalSettings.keys) {
      if (additionalSettingsNew.containsKey(s)) {
        additionalSettingsNew[s] = additionalSettings[s];
      }
    }
    additionalSettingsNew['defaultPseudoVersioningMethod'] = 'partialAPKHash';
    additionalSettingsNew['directAPKLink'] = true;
    additionalSettings['versionDetection'] = false;
    return html.getLatestAPKDetails(standardUrl, additionalSettingsNew);
  }
}
