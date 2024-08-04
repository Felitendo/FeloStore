import 'package:easy_localization/easy_localization.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart';
import 'package:felostore/custom_errors.dart';
import 'package:felostore/providers/source_provider.dart';

class TelegramApp extends AppSource {
  TelegramApp() {
    hosts = ['telegram.org'];
    name = 'Telegram ${tr('app')}';
  }

  @override
  String sourceSpecificStandardizeURL(String url) {
    return 'https://${hosts[0]}';
  }

  @override
  Future<APKDetails> getLatestAPKDetails(
    String standardUrl,
    Map<String, dynamic> additionalSettings,
  ) async {
    Response res =
        await sourceRequest('https://t.me/s/TAndroidAPK', additionalSettings);
    if (res.statusCode == 200) {
      var http = parse(res.body);
      var messages =
          http.querySelectorAll('.tgme_widget_message_text.js-message_text');
      var version = messages.isNotEmpty
          ? messages.last.innerHtml.split('\n').first.trim().split(' ').first
          : null;
      if (version == null) {
        throw NoVersionError();
      }
      String? apkUrl = 'https://telegram.org/dl/android/apk';
      return APKDetails(version, getApkUrlsFromUrls([apkUrl]),
          AppNames('Telegram', 'Telegram'));
    } else {
      throw getFeloStoreHttpError(res);
    }
  }
}
