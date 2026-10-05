import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unisism_motorista/presentation/widgets/form_field.dart';

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            child,
            Container(
              key: const Key('outside_area'),
              color: Colors.grey,
              height: 100,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );

void main() {
  group('AppFormField', () {
    testWidgets('desfoca e minimiza teclado ao tocar fora do campo', (tester) async {
      final ctrl = TextEditingController();
      await tester.pumpWidget(
        _host(
          AppFormField(
            label: 'Matrícula',
            controller: ctrl,
          ),
        ),
      );

      // Foca no input
      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();

      final editableText =
          tester.state<EditableTextState>(find.byType(EditableText));
      expect(editableText.widget.focusNode.hasFocus, isTrue);

      // Toca na área externa
      await tester.tap(find.byKey(const Key('outside_area')));
      await tester.pumpAndSettle();

      // Input perdeu o foco com sucesso
      expect(editableText.widget.focusNode.hasFocus, isFalse);
    });
  });
}
