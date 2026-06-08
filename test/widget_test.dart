import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plagas_arroz/main.dart';

void main() {
  testWidgets('La pantalla de inicio de sesion se renderiza correctamente',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Bienvenido'), findsOneWidget);
    expect(find.textContaining('Iniciar'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.byIcon(Icons.email_outlined), findsOneWidget);
    expect(find.byIcon(Icons.lock_outlined), findsOneWidget);
  });
}
