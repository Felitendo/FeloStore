import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart';
import 'package:felostore/app_sources/github.dart';
import 'package:felostore/custom_errors.dart';
import 'package:felostore/providers/source_provider.dart';

class GitHubStars implements MassAppUrlSource {
  @override
  late String name = tr('githubStarredRepos');

  @override
  late List<String> requiredArgs = [tr('uname')];

  Future<Map<String, List<String>>> getOnePageOfUserStarredUrlsWithDescriptions(
      String username, int page) async {
    Response res = await get(
        Uri.parse(
            'https://api.github.com/users/$username/starred?per_page=100&page=$page'),
        headers: await GitHub().getRequestHeaders({}));
    if (res.statusCode == 200) {
      Map<String, List<String>> urlsWithDescriptions = {};
      for (var e in (jsonDecode(res.body) as List<dynamic>)) {
        urlsWithDescriptions.addAll({
          e['html_url'] as String: [
            e['full_name'] as String,
            e['description'] != null
                ? e['description'] as String
                : tr('noDescription')
          ]
        });
      }
      return urlsWithDescriptions;
    } else {
      var gh = GitHub();
      gh.rateLimitErrorCheck(res);
      throw getFeloStoreHttpError(res);
    }
  }

  @override
  Future<Map<String, List<String>>> getUrlsWithDescriptions(
      List<String> args) async {
    if (args.length != requiredArgs.length) {
      throw FeloStoreError(tr('wrongArgNum'));
    }
    Map<String, List<String>> urlsWithDescriptions = {};
    var page = 1;
    while (true) {
      var pageUrls =
          await getOnePageOfUserStarredUrlsWithDescriptions(args[0], page++);
      urlsWithDescriptions.addAll(pageUrls);
      if (pageUrls.length < 100) {
        break;
      }
    }
    return urlsWithDescriptions;
  }
}
