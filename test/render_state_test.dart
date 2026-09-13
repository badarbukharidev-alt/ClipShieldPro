import 'package:flutter_test/flutter_test.dart';
import 'package:clipshield/models/app_modes.dart';
import 'package:clipshield/models/clip_model.dart';
import 'package:clipshield/models/project_model.dart';
import 'package:clipshield/services/render_job_service.dart';

ClipItem _clip(String id, {bool rendered = false, bool selected = true}) {
  return ClipItem(
    id: id,
    title: 'Clip $id',
    duration: '10s',
    startTime: 0,
    endTime: 10,
    score: 90,
    tag: 'Highlight',
    isSelected: selected,
    outputPath: rendered ? '/tmp/$id.mp4' : null,
    isRendered: rendered,
  );
}

ProjectItem _project({List<ClipItem>? clips}) {
  return ProjectItem(
    id: 'proj_1',
    mode: AppMode.longVideoToShorts,
    title: 'Test project',
    sourceUrlOrPath: '/tmp/source.mp4',
    sourceType: SourceType.localVideo,
    clips: clips ?? [_clip('a'), _clip('b'), _clip('c'), _clip('d'), _clip('e')],
  );
}

void main() {
  group('ProjectItem readiness', () {
    test('a queued project is never ready', () {
      final p = _project()..status = ProjectStatus.queued;
      expect(p.isReady, isFalse);
      expect(p.isRenderingOrQueued, isTrue);
    });

    test('a rendering project is never ready', () {
      final p = _project()..status = ProjectStatus.rendering;
      expect(p.isReady, isFalse);
    });

    test('done without output paths is not ready', () {
      final p = _project()..status = ProjectStatus.done;
      expect(p.outputPaths, isEmpty);
      expect(p.isReady, isFalse);
    });

    test('done with output paths is ready', () {
      final p = _project()
        ..status = ProjectStatus.done
        ..outputPaths = ['/tmp/a.mp4'];
      expect(p.isReady, isTrue);
    });

    test('failed is never ready even with partial output', () {
      final p = _project()
        ..status = ProjectStatus.failed
        ..outputPaths = ['/tmp/a.mp4'];
      expect(p.isReady, isFalse);
    });
  });

  group('clip counts', () {
    test('copyForRender carries only the submitted clips', () {
      final source = _project();
      final selected = [source.clips.first];

      final render = source.copyForRender(clipsToRender: selected);

      expect(source.clips.length, 5, reason: 'source project is untouched');
      expect(render.clips.length, 1, reason: 'only the selected clip is rendered');
      expect(render.clipsCount, 1);
      expect(render.id, isNot(source.id), reason: 'each submission is its own entry');
      expect(render.status, ProjectStatus.queued);
    });

    test('clipsCount does not invent a clip for an empty project', () {
      final p = ProjectItem(
        id: 'empty',
        mode: AppMode.songRemover,
        title: 'Empty',
        sourceUrlOrPath: '/tmp/a.mp3',
        sourceType: SourceType.localAudio,
      );
      expect(p.clipsCount, 0);
    });

    test('renderedClipsCount counts only verified clips', () {
      final p = _project(clips: [
        _clip('a', rendered: true),
        _clip('b'),
        _clip('c'),
      ]);
      expect(p.clipsCount, 3);
      expect(p.renderedClipsCount, 1);
    });
  });

  group('RenderJobStatus mapping', () {
    test('each job status maps onto exactly one persisted project status', () {
      expect(RenderJobStatus.queued.projectStatus, ProjectStatus.queued);
      expect(RenderJobStatus.rendering.projectStatus, ProjectStatus.rendering);
      expect(RenderJobStatus.completed.projectStatus, ProjectStatus.done);
      expect(RenderJobStatus.failed.projectStatus, ProjectStatus.failed);
      expect(RenderJobStatus.canceled.projectStatus, ProjectStatus.canceled);
    });

    test('active and terminal partition the lifecycle', () {
      for (final s in RenderJobStatus.values) {
        expect(s.isActive, isNot(s.isTerminal), reason: '$s must be exactly one of active/terminal');
      }
    });
  });

  group('RenderJobState transitions', () {
    test('a new job starts queued at zero progress', () {
      final job = RenderJobState.queued(projectId: 'p', title: 'T', totalClips: 3);
      expect(job.status, RenderJobStatus.queued);
      expect(job.isActive, isTrue);
      expect(job.isCompleted, isFalse);
      expect(job.progress, 0.0);
      expect(job.renderedClips, 0);
      expect(job.totalClips, 3);
    });

    test('progress updates preserve the clip totals', () {
      final job = RenderJobState.queued(projectId: 'p', title: 'T', totalClips: 3)
          .copyWith(status: RenderJobStatus.rendering, progress: 0.5, renderedClips: 1);
      expect(job.totalClips, 3);
      expect(job.renderedClips, 1);
      expect(job.progressPercent, 50);
      expect(job.isCompleted, isFalse);
    });

    test('a failed job is not completed and carries its error', () {
      final job = RenderJobState.queued(projectId: 'p', title: 'T', totalClips: 2).copyWith(
        status: RenderJobStatus.failed,
        error: 'encoder produced nothing',
      );
      expect(job.isFailed, isTrue);
      expect(job.isCompleted, isFalse);
      expect(job.isActive, isFalse);
      expect(job.error, 'encoder produced nothing');
      expect(job.projectStatusOrNull, ProjectStatus.failed);
    });
  });
}

extension on RenderJobState {
  String get projectStatusOrNull => status.projectStatus;
}
