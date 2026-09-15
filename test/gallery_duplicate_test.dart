import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:clipshield/models/app_modes.dart';
import 'package:clipshield/models/clip_model.dart';
import 'package:clipshield/models/project_model.dart';
import 'package:clipshield/screens/results_screen.dart';

/// One processed video was turning up in the gallery two or three times.
///
/// The results screen is reachable from four places — the processing screen,
/// Recent Projects, Projects History, and after a share — and every visit re-ran
/// the export. MediaStore does not overwrite: a second insert of the same name
/// becomes "clip (1).mp4", so each visit looked like a brand new file.
///
/// The real guard is in Kotlin (an existing-row lookup before insert) and cannot
/// be exercised here. What is testable is the second layer: the project
/// remembers that it was exported, and a revisit must not try again.
ProjectItem finishedProject(String clipPath) {
  final project = ProjectItem(
    id: 'p_dup',
    mode: AppMode.transformAndProtect,
    title: 'Test Export',
    sourceUrlOrPath: '/tmp/source.mp4',
    sourceType: SourceType.localVideo,
    clips: [
      ClipItem(
        id: 'c1',
        title: 'Clip',
        duration: '30s',
        startTime: 0,
        endTime: 30,
        score: 90,
        tag: 'Test',
        outputPath: clipPath,
        isRendered: true,
      ),
    ],
    preset: PipelinePreset.balanced,
    aspectRatio: AspectRatioOption.original169,
  );
  project.status = ProjectStatus.done;

  return project;
}

void main() {
  late Directory tmp;
  late String clipPath;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tmp = Directory.systemTemp.createTempSync('cs_dup');
    clipPath = '${tmp.path}/clip.mp4';
    File(clipPath).writeAsBytesSync(List<int>.filled(4096, 9));
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('a fresh project is not yet marked as exported', () {
    expect(finishedProject(clipPath).isExportedToGallery, isFalse);
  });

  test('the flag round-trips through storage', () {
    final project = finishedProject(clipPath)..isExportedToGallery = true;

    final restored = ProjectItem.fromMap(project.toMap());

    expect(restored.isExportedToGallery, isTrue,
        reason: 'the flag must survive a restart, or reopening a project from '
            'history after relaunching would export it all over again');
  });

  testWidgets('revisiting an exported project does not export again',
      (tester) async {
    final project = finishedProject(clipPath)..isExportedToGallery = true;

    await tester.pumpWidget(MaterialApp(
      home: ResultsScreen(project: project, renderedClips: project.clips),
    ));
    await tester.pump();

    // It reports the earlier save rather than showing "Saving..." and running
    // the export a second time.
    expect(find.textContaining('Saved to your gallery'), findsOneWidget);
    expect(find.textContaining('Saving to your gallery'), findsNothing);
  });

  testWidgets('a project that was never exported does try', (tester) async {
    final project = finishedProject(clipPath);

    await tester.pumpWidget(MaterialApp(
      home: ResultsScreen(project: project, renderedClips: project.clips),
    ));
    await tester.pump();

    expect(find.textContaining('Saving to your gallery'), findsOneWidget);
  });

  testWidgets('an unfinished project exports nothing at all', (tester) async {
    final project = finishedProject(clipPath)..status = ProjectStatus.rendering;

    await tester.pumpWidget(MaterialApp(
      home: ResultsScreen(project: project, renderedClips: project.clips),
    ));
    await tester.pump();

    expect(find.textContaining('Saving to your gallery'), findsNothing);
    expect(project.isExportedToGallery, isFalse);
  });
}
