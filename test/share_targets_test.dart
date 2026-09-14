import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:clipshield/widgets/share_target_row.dart';

/// The previous share row wired every icon to the same system chooser, so
/// tapping "Instagram" and tapping "WhatsApp" did identical things. These pin
/// that each destination is a real, distinct target carrying that brand's own
/// mark rather than a Material look-alike.
void main() {
  test('every destination has its own package list', () {
    final packages = <String>{};
    for (final target in kShareTargets) {
      expect(target.packages, isNotEmpty,
          reason: '${target.label} must name at least one Android package');
      for (final package in target.packages) {
        expect(packages.add(package), isTrue,
            reason: '$package is claimed by more than one destination');
      }
    }
  });

  test('brand marks come from Font Awesome, not Material look-alikes', () {
    const expected = {
      'WhatsApp': FontAwesomeIcons.whatsapp,
      'Instagram': FontAwesomeIcons.instagram,
      'YouTube': FontAwesomeIcons.youtube,
      'TikTok': FontAwesomeIcons.tiktok,
    };

    for (final target in kShareTargets) {
      expect(expected.containsKey(target.label), isTrue,
          reason: 'unexpected destination ${target.label}');
      expect(target.icon, expected[target.label],
          reason: '${target.label} is not using its real brand mark');
    }
  });

  test('TikTok covers both of its regional package names', () {
    final tiktok = kShareTargets.firstWhere((t) => t.label == 'TikTok');

    // TikTok ships under a different package depending on where the phone was
    // sold; checking only one reports "not installed" for half the world.
    expect(tiktok.packages, contains('com.zhiliaoapp.musically'));
    expect(tiktok.packages, contains('com.ss.android.ugc.trill'));
  });

  testWidgets('every destination plus More is rendered', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ShareTargetRow(filePaths: [])),
    ));

    for (final target in kShareTargets) {
      expect(find.text(target.label), findsOneWidget);
    }
    expect(find.text('More'), findsOneWidget);
  });

  testWidgets('the row fits a 360dp screen without overflowing', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ShareTargetRow(filePaths: [])),
    ));

    expect(tester.takeException(), isNull,
        reason: 'five destinations must fit the narrowest common phone');
  });

  testWidgets('a missing file is reported rather than shared', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ShareTargetRow(filePaths: ['/definitely/not/here.mp4']),
      ),
    ));

    await tester.tap(find.text('WhatsApp'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('no longer on the device'), findsOneWidget);
  });

  testWidgets('a real file gets as far as asking whether the app is installed',
      (tester) async {
    final tmp = Directory.systemTemp.createTempSync('cs_share');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final file = File('${tmp.path}/clip.mp4')..writeAsBytesSync([0, 1, 2, 3]);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ShareTargetRow(filePaths: [file.path])),
    ));

    await tester.tap(find.text('Instagram'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // No Android under a widget test, so the channel reports "not installed" --
    // which is exactly the message a user without Instagram should see, rather
    // than a silent no-op or a chooser they did not ask for.
    expect(find.textContaining('not installed'), findsOneWidget);
  });
}
