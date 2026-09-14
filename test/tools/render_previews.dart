import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:clipshield/models/app_modes.dart';
import 'package:clipshield/models/clip_model.dart';
import 'package:clipshield/models/project_model.dart';
import 'package:clipshield/models/source_metadata.dart';
import 'package:clipshield/screens/home_screen.dart';
import 'package:clipshield/models/app_update.dart';
import 'package:clipshield/screens/tasks_screen.dart';
import 'package:clipshield/screens/update_dialog.dart';
import 'package:clipshield/screens/projects_history_screen.dart';
import 'package:clipshield/screens/results_screen.dart';
import 'package:clipshield/theme/app_theme.dart';

/// Widget tests render with the Ahem placeholder font, which draws every glyph
/// as a filled box. Loading a real system font makes these previews actually
/// readable.
Future<void> loadRealFont() async {
  for (final path in [
    r'C:\Windows\Fonts\segoeui.ttf',
    r'C:\Windows\Fonts\arial.ttf',
  ]) {
    final f = File(path);
    if (!f.existsSync()) continue;
    final bytes = f.readAsBytesSync();
    final loader = FontLoader('Preview')
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
    break;
  }

  // Without this every Icon draws as an empty box, which hides exactly the
  // detail these previews exist to show.
  final icons = File(
      'D:/tools/flutter/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final b = icons.readAsBytesSync();
    final l = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.view(b.buffer)));
    await l.load();
  }
}

ThemeData previewTheme() {
  final base = AppTheme.lightTheme;

  // The button themes pin their own TextStyle, which wins over both the
  // textTheme and any ambient DefaultTextStyle. Without overriding them here
  // every button label renders as boxes -- which is exactly the text worth
  // reading in a preview.
  ButtonStyle? withFont(ButtonStyle? style) => style?.copyWith(
        textStyle: WidgetStateProperty.resolveWith(
          (states) => (style.textStyle?.resolve(states) ?? const TextStyle())
              .copyWith(fontFamily: 'Preview'),
        ),
      );

  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'Preview'),
    elevatedButtonTheme:
        ElevatedButtonThemeData(style: withFont(base.elevatedButtonTheme.style)),
    outlinedButtonTheme:
        OutlinedButtonThemeData(style: withFont(base.outlinedButtonTheme.style)),
    textButtonTheme: TextButtonThemeData(style: withFont(base.textButtonTheme.style)),
  );
}

Future<void> shot(WidgetTester tester, Widget home, String name,
    {Future<void> Function(WidgetTester)? after}) async {
  tester.view.physicalSize = const Size(411 * 2, 890 * 2);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(
    theme: previewTheme(),
    home: DefaultTextStyle.merge(style: const TextStyle(fontFamily: 'Preview'), child: home),
  ));
  await tester.pumpAndSettle();
  if (after != null) await after(tester);
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('../golden/$name.png'));
}

void main() {
  setUpAll(loadRealFont);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('01 dashboard copyright', (t) async {
    await shot(t, const HomeScreen(), '01_dashboard_copyright');
  });

  testWidgets('02 dashboard ai shorts', (t) async {
    await shot(t, const HomeScreen(), '02_dashboard_ai_shorts', after: (tt) async {
      await tt.tap(find.text('AI Shorts'));
      await tt.pumpAndSettle();
    });
  });

  testWidgets('03 dashboard song dsp', (t) async {
    await shot(t, const HomeScreen(), '03_dashboard_song_copyright', after: (tt) async {
      await tt.tap(find.text('Song Copyright'));
      await tt.pumpAndSettle();
    });
  });

  testWidgets('04 free videos tab', (t) async {
    await shot(t, const HomeScreen(), '04_free_videos', after: (tt) async {
      await tt.tap(find.text('Free'));
      await tt.pumpAndSettle();
    });
  });

  testWidgets('05 projects tab', (t) async {
    await shot(t, const HomeScreen(), '05_projects', after: (tt) async {
      await tt.tap(find.text('Projects'));
      await tt.pumpAndSettle();
    });
  });

  testWidgets('06 tasks screen standalone', (t) async {
    await shot(t, const TasksScreen(), '06_tasks_screen');
  });

  testWidgets('07 projects history standalone', (t) async {
    await shot(t, const ProjectsHistoryScreen(), '07_projects_history');
  });

  testWidgets('09 update dialog', (t) async {
    await shot(t, const _DialogHost(AppUpdate(
      versionName: '1.2.11',
      versionCode: 14,
      apkUrl: 'https://example.com/app.apk',
      notes: 'Long videos now render roughly twice as fast, captions no longer '
          'drop the final line, and the support number can be changed without '
          'a new build.',
    )), '09_update_dialog', after: (tt) async {
      await tt.tap(find.text('open'));
      await tt.pumpAndSettle();
    });
  });

  testWidgets('10 update dialog mandatory', (t) async {
    await shot(t, const _DialogHost(AppUpdate(
      versionName: '1.3.0',
      versionCode: 20,
      apkUrl: 'https://example.com/app.apk',
      notes: 'This build talks to a new server API.',
      mandatory: true,
    )), '10_update_dialog_mandatory', after: (tt) async {
      await tt.tap(find.text('open'));
      await tt.pumpAndSettle();
    });
  });

  testWidgets('08 results ready', (t) async {
    final tmp = Directory.systemTemp.createTempSync('cs_preview');
    final clipFile = File('${tmp.path}/c.mp4')..writeAsBytesSync(List<int>.filled(4096, 7));
    addTearDown(() { try { tmp.deleteSync(recursive: true); } catch (_) {} });

    const meta = SourceMetadata(
      videoId: 'abc12345678',
      title: 'How I Grew a Faceless Channel to 100K Subscribers',
      author: 'Creator Academy',
      description: 'Full breakdown of the workflow, the tools, and the mistakes I made.',
      keywords: ['faceless channel', 'youtube automation', 'shorts', 'growth'],
      durationSeconds: 1420,
    );
    final clip = ClipItem(
      id: 'c1', title: 'Best moment', duration: '0:38',
      startTime: 0, endTime: 38, score: 94, tag: 'Shielded',
      outputPath: clipFile.path, isRendered: true,
    );
    final project = ProjectItem(
      id: 'p1', mode: AppMode.transformAndProtect,
      title: 'How I Grew a Faceless Channel to 100K Subscribers',
      sourceUrlOrPath: 'https://youtu.be/abc12345678',
      sourceType: SourceType.youtubeUrl,
      status: ProjectStatus.done, clips: [clip],
      outputPaths: [clipFile.path],
      settings: {'sourceMeta': meta.toMap()},
    );

    await shot(t, ResultsScreen(project: project, renderedClips: [clip]), '08_results_ready');
  });
}

/// Opens the update dialog over an ordinary scaffold, so the preview shows it
/// the way a user meets it rather than as a bare widget.
class _DialogHost extends StatelessWidget {
  final AppUpdate update;

  const _DialogHost(this.update);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => UpdateDialog.show(ctx, update),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }
}
