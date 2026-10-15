import 'package:flutter_test/flutter_test.dart';
import 'package:study_stream/domain/services/resume_service.dart';

void main() {
  test('short media keeps meaningful middle progress', () {
    expect(ResumeService.mediaResumeSeconds(4, durationSeconds: 8), 4);
    expect(ResumeService.mediaResumeSeconds(7.9, durationSeconds: 8), 0);
  });
  group('media resume', () {
    test('rewinds established progress by ten seconds', () {
      expect(ResumeService.mediaResumeSeconds(80, durationSeconds: 300), 70);
    });

    test('does not rewind near the beginning', () {
      expect(ResumeService.mediaResumeSeconds(12, durationSeconds: 300), 12);
    });

    test('does not resume in the final seconds or after completion', () {
      expect(ResumeService.mediaResumeSeconds(298, durationSeconds: 300), 0);
      expect(
        ResumeService.mediaResumeSeconds(
          80,
          durationSeconds: 300,
          completed: true,
        ),
        0,
      );
    });
  });

  test('uses a 90 percent media completion threshold', () {
    expect(
      ResumeService.mediaCompleted(positionSeconds: 89, durationSeconds: 100),
      isFalse,
    );
    expect(
      ResumeService.mediaCompleted(positionSeconds: 90, durationSeconds: 100),
      isTrue,
    );
  });

  test(
    'short documents are not completed merely by opening the final page',
    () {
      expect(
        ResumeService.readingCompleted(
          currentPage: 1,
          totalPages: 1,
          pagesVisited: 1,
        ),
        isFalse,
      );
      expect(
        ResumeService.readingCompleted(
          currentPage: 10,
          totalPages: 10,
          pagesVisited: 2,
        ),
        isTrue,
      );
    },
  );
}
