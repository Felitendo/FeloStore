import 'dart:async';

import 'package:animations/animations.dart';
import 'package:app_links/app_links.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:felostore/components/generated_form_modal.dart';
import 'package:felostore/custom_errors.dart';
import 'package:felostore/pages/apps.dart';
import 'package:felostore/pages/settings.dart';
import 'package:felostore/providers/apps_provider.dart';
import 'package:felostore/providers/settings_provider.dart';
import 'package:felostore/providers/source_provider.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class NavigationPageItem {
  late String title;
  late IconData icon;
  late Widget widget;

  NavigationPageItem(this.title, this.icon, this.widget);
}

class _HomePageState extends State<HomePage> {
  List<int> selectedIndexHistory = [];
  bool isReversing = false;
  int prevAppCount = -1;
  bool prevIsLoading = true;
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  bool isLinkActivity = false;

  List<NavigationPageItem> pages = [
    NavigationPageItem(tr('appsString'), Icons.apps,
        AppsPage(key: GlobalKey<AppsPageState>())),
    NavigationPageItem(tr('settings'), Icons.settings, const SettingsPage())
  ];

  @override
  void initState() {
    super.initState();
    initDeepLinks();
  }

  Future<void> initDeepLinks() async {
    _appLinks = AppLinks();

    interpretLink(Uri uri) async {
      isLinkActivity = true;
      var action = uri.host;
      var data = uri.path.length > 1 ? uri.path.substring(1) : "";
      try {
        if (action == 'app' || action == 'apps') {
          var dataStr = Uri.decodeComponent(data);
          if (await showDialog(
                  context: context,
                  builder: (BuildContext ctx) {
                    return GeneratedFormModal(
                      title: tr('importX', args: [
                        action == 'app' ? tr('app') : tr('appsString')
                      ]),
                      items: const [],
                      additionalWidgets: [
                        ExpansionTile(
                          title: const Text('Raw JSON'),
                          children: [
                            Text(
                              dataStr,
                              style: const TextStyle(fontFamily: 'monospace'),
                            )
                          ],
                        )
                      ],
                    );
                  }) !=
              null) {
            // ignore: use_build_context_synchronously
            var appsProvider = context.read<AppsProvider>();
            var result = await appsProvider.import(action == 'app'
                ? '{ "apps": [$dataStr] }'
                : '{ "apps": $dataStr }');
            // ignore: use_build_context_synchronously
            showMessage(
                tr('importedX', args: [plural('apps', result.key.length)]),
                context);
            await appsProvider
                .checkUpdates(specificIds: result.key.map((e) => e.id).toList())
                .catchError((e) {
              if (e is Map && e['errors'] is MultiAppMultiError) {
                showError(e['errors'].toString(), context);
              }
              return <App>[];
            });
          }
        } else {
          throw FeloStoreError(tr('unknown'));
        }
      } catch (e) {
        showError(e, context);
      }
    }

    // Check initial link if app was in cold state (terminated)
    final appLink = await _appLinks.getInitialLink();
    if (appLink != null) {
      await interpretLink(appLink);
    }

    // Handle link when app is in warm state (front or background)
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) async {
      await interpretLink(uri);
    });
  }

  setIsReversing(int targetIndex) {
    bool reversing = selectedIndexHistory.isNotEmpty &&
        selectedIndexHistory.last > targetIndex;
    setState(() {
      isReversing = reversing;
    });
  }

  switchToPage(int index) async {
    setIsReversing(index);
    if (index == 0) {
      while ((pages[0].widget.key as GlobalKey<AppsPageState>).currentState !=
          null) {
        // Avoid duplicate GlobalKey error
        await Future.delayed(const Duration(microseconds: 1));
      }
      setState(() {
        selectedIndexHistory.clear();
      });
    } else if (selectedIndexHistory.isEmpty ||
        (selectedIndexHistory.isNotEmpty &&
            selectedIndexHistory.last != index)) {
      setState(() {
        int existingInd = selectedIndexHistory.indexOf(index);
        if (existingInd >= 0) {
          selectedIndexHistory.removeAt(existingInd);
        }
        selectedIndexHistory.add(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    AppsProvider appsProvider = context.watch<AppsProvider>();
    SettingsProvider settingsProvider = context.watch<SettingsProvider>();

    if (!prevIsLoading &&
        prevAppCount >= 0 &&
        appsProvider.apps.length > prevAppCount &&
        selectedIndexHistory.isNotEmpty &&
        selectedIndexHistory.last == 1 &&
        !isLinkActivity) {
      switchToPage(0);
    }
    prevAppCount = appsProvider.apps.length;
    prevIsLoading = appsProvider.loadingApps;

    return WillPopScope(
        child: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: PageTransitionSwitcher(
            duration: Duration(
                milliseconds:
                    settingsProvider.disablePageTransitions ? 0 : 300),
            reverse: settingsProvider.reversePageTransitions
                ? !isReversing
                : isReversing,
            transitionBuilder: (
              Widget child,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) {
              return SharedAxisTransition(
                animation: animation,
                secondaryAnimation: secondaryAnimation,
                transitionType: SharedAxisTransitionType.horizontal,
                child: child,
              );
            },
            child: pages
                .elementAt(selectedIndexHistory.isEmpty
                    ? 0
                    : selectedIndexHistory.last)
                .widget,
          ),
          bottomNavigationBar: NavigationBar(
            destinations: pages
                .map((e) =>
                    NavigationDestination(icon: Icon(e.icon), label: e.title))
                .toList(),
            onDestinationSelected: (int index) async {
              HapticFeedback.selectionClick();
              switchToPage(index);
            },
            selectedIndex:
                selectedIndexHistory.isEmpty ? 0 : selectedIndexHistory.last,
          ),
        ),
        onWillPop: () async {
          setIsReversing(selectedIndexHistory.length >= 2
              ? selectedIndexHistory.reversed.toList()[1]
              : 0);
          if (selectedIndexHistory.isNotEmpty) {
            setState(() {
              selectedIndexHistory.removeLast();
            });
            return false;
          }
          return !(pages[0].widget.key as GlobalKey<AppsPageState>)
              .currentState
              ?.clearSelected();
        });
  }

  @override
  void dispose() {
    super.dispose();
    _linkSubscription?.cancel();
  }
}