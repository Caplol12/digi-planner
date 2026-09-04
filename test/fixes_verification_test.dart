import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_app/models/drawing_stroke_model.dart';
import 'package:journal_app/models/notebook_model.dart';
import 'package:journal_app/models/text_box_model.dart';

void main() {
  group('Code Review Fixes Verification', () {
    test('DrawingStroke copyWith performs a deep copy of points', () {
      final original = DrawingStroke(
        id: 'stroke_1',
        points: [const DrawingPoint(10, 20), const DrawingPoint(30, 40)],
        color: Colors.black,
      );

      final copy = original.copyWith();

      // Ensure lists are distinct
      expect(identical(original.points, copy.points), isFalse);

      // Mutate original's points list
      original.points.add(const DrawingPoint(50, 60));
      expect(copy.points.length, 2);
      expect(original.points.length, 3);
    });

    test('NotebookPageModel copyWith performs deep copies of drawingStrokes and textBoxes', () {
      final page = NotebookPageModel(
        id: 'p1',
        drawingStrokes: [
          DrawingStroke(
            id: 's1',
            points: [const DrawingPoint(1, 2)],
            color: Colors.blue,
          ),
        ],
        textBoxes: [
          TextBoxItem(id: 'tb1', text: 'Hello', position: const Offset(10, 10)),
        ],
      );

      final historyCopy = page.copyWith();

      // Mutate page in-place
      page.drawingStrokes.first.points.add(const DrawingPoint(3, 4));
      page.textBoxes.first.text = 'Modified';

      expect(historyCopy.drawingStrokes.first.points.length, 1);
      expect(historyCopy.textBoxes.first.text, 'Hello');
    });

    test('TextBoxItem and DetectedBox serialize textAlign as String and support backwards-compatibility', () {
      final box = TextBoxItem(
        id: 'tb1',
        text: 'Align Test',
        position: const Offset(0, 0),
        textAlign: TextAlign.center,
      );

      final json = box.toJson();
      expect(json['textAlign'], 'center');

      // Deserializing with String name
      final fromString = TextBoxItem.fromJson(json);
      expect(fromString.textAlign, TextAlign.center);

      // Deserializing legacy integer index (e.g. TextAlign.left = 1, right = 0, etc.)
      final legacyJson = Map<String, dynamic>.from(json);
      legacyJson['textAlign'] = TextAlign.left.index;
      final fromLegacy = TextBoxItem.fromJson(legacyJson);
      expect(fromLegacy.textAlign, TextAlign.left);
    });

    test('UUID generates non-colliding IDs across rapid model instantiation', () {
      final ids = <String>{};
      for (int i = 0; i < 50; i++) {
        final p = NotebookPageModel(id: 'p_$i');
        final json = p.toJson();
        json.remove('id');
        final restored = NotebookPageModel.fromJson(json);
        expect(ids.contains(restored.id), isFalse);
        ids.add(restored.id);
      }
      expect(ids.length, 50);
    });
  });
}
