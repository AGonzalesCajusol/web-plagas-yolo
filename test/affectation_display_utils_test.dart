import 'package:flutter_test/flutter_test.dart';
import 'package:plagas_arroz/utils/affectation_display_utils.dart';

void main() {
  group('AffectationDisplayUtils.levelLabel', () {
    test('convierte todos los niveles a etiquetas legibles', () {
      expect(AffectationDisplayUtils.levelLabel('BAJO'), 'Bajo');
      expect(AffectationDisplayUtils.levelLabel('MEDIO'), 'Medio');
      expect(AffectationDisplayUtils.levelLabel('ALTO'), 'Alto');
      expect(
        AffectationDisplayUtils.levelLabel('NO_EVALUADO'),
        'No evaluado',
      );
      expect(AffectationDisplayUtils.levelLabel(null), 'No registrado');
    });
  });

  group('AffectationDisplayUtils.methodLabel', () {
    test('convierte todos los métodos a etiquetas legibles', () {
      expect(
        AffectationDisplayUtils.methodLabel('PANICULA_SINTOMATICA'),
        'Panícula con síntomas',
      );
      expect(
        AffectationDisplayUtils.methodLabel('PLANTAS_SINTOMATICAS'),
        'Plantas con síntomas',
      );
      expect(
        AffectationDisplayUtils.methodLabel('PRESENCIA_OBSERVADA'),
        'Presencia observada',
      );
      expect(
        AffectationDisplayUtils.methodLabel('NO_EVALUADO'),
        'No evaluado',
      );
      expect(AffectationDisplayUtils.methodLabel(null), 'No registrado');
    });
  });

  group('AffectationDisplayUtils.rangeLabel', () {
    test('convierte todos los rangos a etiquetas legibles', () {
      expect(
        AffectationDisplayUtils.rangeLabel('1_20'),
        '1–20 % de la panícula',
      );
      expect(
        AffectationDisplayUtils.rangeLabel('21_40'),
        '21–40 % de la panícula',
      );
      expect(
        AffectationDisplayUtils.rangeLabel('MAS_40'),
        'Más de 40 % de la panícula',
      );
      expect(
        AffectationDisplayUtils.rangeLabel('1_10'),
        '1–10 % de plantas',
      );
      expect(
        AffectationDisplayUtils.rangeLabel('11_30'),
        '11–30 % de plantas',
      );
      expect(
        AffectationDisplayUtils.rangeLabel('MAS_30'),
        'Más de 30 % de plantas',
      );
      expect(
        AffectationDisplayUtils.rangeLabel('AISLADA'),
        'Presencia aislada',
      );
      expect(
        AffectationDisplayUtils.rangeLabel('FRECUENTE'),
        'Presencia frecuente',
      );
      expect(
        AffectationDisplayUtils.rangeLabel('ABUNDANTE'),
        'Presencia abundante',
      );
      expect(
        AffectationDisplayUtils.rangeLabel('NO_EVALUADO'),
        'No evaluado',
      );
      expect(AffectationDisplayUtils.rangeLabel(null), 'No registrado');
    });
  });

  test('normaliza espacios y mayúsculas sin exponer códigos desconocidos', () {
    expect(AffectationDisplayUtils.levelLabel(' bajo '), 'Bajo');
    expect(AffectationDisplayUtils.methodLabel('DESCONOCIDO'), 'No registrado');
    expect(AffectationDisplayUtils.rangeLabel(''), 'No registrado');
  });
}
