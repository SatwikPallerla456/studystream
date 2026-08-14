import 'package:flutter_test/flutter_test.dart';
import 'package:study_stream/core/utils/sort_utils.dart';

void main() {
  test('sorts numeric course prefixes naturally', () {
    final values = ['10 Advanced', '02 Setup', 'Appendix', '1 Introduction'];
    values.sort(naturalCourseCompare);
    expect(values, ['1 Introduction', '02 Setup', '10 Advanced', 'Appendix']);
  });

  test('uses case-insensitive alphabetical order without a prefix', () {
    final values = ['zebra', 'Beta', 'alpha'];
    values.sort(naturalCourseCompare);
    expect(values, ['alpha', 'Beta', 'zebra']);
  });
}
