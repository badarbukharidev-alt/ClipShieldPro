import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clipshield/models/app_modes.dart';
import 'package:clipshield/models/clip_model.dart';
import 'package:clipshield/models/project_model.dart';
import 'package:clipshield/models/source_metadata.dart';
import 'package:clipshield/screens/results_screen.dart';
import 'package:clipshield/theme/app_theme.dart';

const _meta = SourceMetadata(
  videoId: 'abc12345678',
  title: 'The Real Source Title',
  author: 'Some Channel',
  description: 'A description that should be copyable.',
  keywords: ['alpha', 'beta', 'gamma'],
  thumbnailUrl: '',
  thumbnailMaxResUrl: '',
  durationSeconds: 742,
);

late Directory _tmp;
late File _clipFile;

ProjectItem _readyProject({bool withMeta = true}) {
  final clip = ClipItem(
    id: 'c1',
    title: 'Clip',
    duration: '10s',
    startTime: 0,
    endTime: 10,
    score: 90,
    tag: 'Shielded',
    outputPath: _clipFile.path,
    isRendered: true,
  );
  return ProjectItem(
    id: 'proj',
    mode: AppMode.transformAndProtect,
    title: 'Project',
    sourceUrlOrPath: 'https://youtu.be/abc12345678',
    sourceType: SourceType.youtubeUrl,
    status: ProjectStatus.done,
    clips: [clip],
    outputPaths: [_clipFile.path],
    settings: withMeta ? {'sourceMeta': _meta.toMap()} : null,
  );
}

Future<void> _pump(WidgetTester tester, ProjectItem project) async {
  tester.view.physicalSize = const Size(411 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme,
    home: ResultsScreen(
      project: project,
      renderedClips: project.clips,
    ),
  ));
  await tester.pump();
}

void main() {
  setUpAll(() {
    _tmp = Directory.systemTemp.createTempSync('clipshield_results_test');
    // _isGenuinelyReady requires a real artifact on disk.
    _clipFile = File('${_tmp.path}/clip.mp4')
      ..writeAsBytesSync(List<int>.filled(4096, 7));
  });

  tearDownAll(() {
    try {
      _tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  testWidgets('source metadata is shown inline on the ready screen',
      (WidgetTester tester) async {
    await _pump(tester, _readyProject());

    expect(find.text('SOURCE VIDEO METADATA'), findsOneWidget);
    expect(find.text('The Real Source Title'), findsOneWidget);
    expect(find.text('DESCRIPTION'), findsOneWidget);
    expect(find.text('KEYWORDS (3)'), findsOneWidget);
    expect(find.text('Download Full HD Thumbnail'), findsOneWidget);
  });

  testWidgets('metadata sits alongside the sharing options, not behind a button',
      (WidgetTester tester) async {
    await _pump(tester, _readyProject());

    // The old design hid all of this behind a disclosure button.
    expect(find.text('Source title, description, tags & thumbnail'), findsNothing);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('SOURCE VIDEO METADATA'), findsOneWidget);
  });

  testWidgets('a project without metadata simply omits the panel',
      (WidgetTester tester) async {
    await _pump(tester, _readyProject(withMeta: false));

    expect(find.text('SOURCE VIDEO METADATA'), findsNothing);
    expect(find.text('Protected Video Ready'), findsOneWidget);
  });

  testWidgets('keywords are offered comma separated', (WidgetTester tester) async {
    await _pump(tester, _readyProject());

    expect(find.text('Copy gives you all 3, comma separated.'), findsOneWidget);
    expect(_meta.keywordsCsv, 'alpha, beta, gamma');
  });
}
