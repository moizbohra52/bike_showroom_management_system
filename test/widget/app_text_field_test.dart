import 'package:bike_showroom_management_system/common/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The password field is the only field in the application that carries a
/// suffix widget, which makes it the only one whose decoration layout can go
/// wrong — so it is the one worth a widget test.
void main() {
  Future<void> pumpField(WidgetTester tester, Widget field) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: SizedBox(width: 400, child: field)),
          ),
        ),
      );

  group('AppPasswordField', () {
    testWidgets('a tap on the text area focuses the field', (
      WidgetTester tester,
    ) async {
      // Regression: the suffix was wrapped in an `Align`, which expands to
      // fill whatever width it is given. `suffixIconConstraints` left the
      // width unbounded, so the enforced maximum became the *whole field*.
      // The reveal icon still painted at the right, so the field looked
      // correct — but the editable area was squeezed to nothing and a tap
      // anywhere on it did nothing at all. Sign-in was impossible.
      final FocusNode focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);

      await pumpField(
        tester,
        AppPasswordField(controller: controller, focusNode: focusNode),
      );

      final Rect field = tester.getRect(find.byType(TextField));
      // Left of centre, well clear of the reveal button: where a user aims
      // when they mean "start typing my password".
      await tester.tapAt(Offset(field.left + 60, field.center.dy));
      await tester.pumpAndSettle();

      expect(focusNode.hasFocus, isTrue);
    });

    testWidgets('the editable area keeps most of the field width', (
      WidgetTester tester,
    ) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);

      await pumpField(tester, AppPasswordField(controller: controller));

      final double fieldWidth = tester.getSize(find.byType(TextField)).width;
      final double editableWidth = tester
          .getSize(find.byType(EditableText))
          .width;

      // A prefix icon and a reveal button together are worth roughly a third
      // of a 400px field; anything below half means the suffix has eaten the
      // input rather than sat beside it.
      expect(editableWidth, greaterThan(fieldWidth * 0.5));
    });

    testWidgets('the reveal button still toggles obscuring', (
      WidgetTester tester,
    ) async {
      final TextEditingController controller = TextEditingController(
        text: 'secret',
      );
      addTearDown(controller.dispose);

      await pumpField(tester, AppPasswordField(controller: controller));

      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isTrue,
      );

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isFalse,
      );
    });
  });

  group('AppTextField', () {
    testWidgets('a plain field focuses on tap', (WidgetTester tester) async {
      final FocusNode focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);

      await pumpField(
        tester,
        AppTextField(
          label: 'Email',
          controller: controller,
          focusNode: focusNode,
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(focusNode.hasFocus, isTrue);
    });
  });
}
