import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/pdf/domain/pdf_labels.dart';

void main() {
  test('pageRangeLabel : base 0 → base 1, une ou plusieurs pages', () {
    expect(pageRangeLabel(111, 117), 'p. 112–118');
    expect(pageRangeLabel(111, 111), 'p. 112');
    expect(pageRangeLabel(111, null), 'p. 112');
  });

  test('megabytesLabel : Mo arrondis, jamais 0', () {
    expect(megabytesLabel(398458880), '380 Mo');
    expect(megabytesLabel(1000), '1 Mo');
  });

  test('pdfReaderPath', () {
    expect(pdfReaderPath(26), '/colleges/26/pdf');
    expect(pdfReaderPath(26, page: 112, itemId: 'i340'), '/colleges/26/pdf?page=112&item=i340');
  });
}
