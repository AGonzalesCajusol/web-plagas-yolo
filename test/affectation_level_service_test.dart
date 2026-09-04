import 'package:flutter_test/flutter_test.dart';
import 'package:plagas_arroz/models/affectation_evaluation.dart';
import 'package:plagas_arroz/services/affectation_level_service.dart';

void main() {
  const service = AffectationLevelService();

  group('AffectationLevelService', () {
    final cases = <({
      String pest,
      String range,
      String level,
      String method,
    })>[
      (
        pest: 'Añublo bacteriano',
        range: '1_20',
        level: AffectationLevels.low,
        method: EvaluationMethods.symptomaticPanicle,
      ),
      (
        pest: 'ANUBLO',
        range: '21_40',
        level: AffectationLevels.medium,
        method: EvaluationMethods.symptomaticPanicle,
      ),
      (
        pest: 'AÑUBLO',
        range: 'MAS_40',
        level: AffectationLevels.high,
        method: EvaluationMethods.symptomaticPanicle,
      ),
      (
        pest: 'añublo bacteriano',
        range: 'NO_EVALUADO',
        level: AffectationLevels.notEvaluated,
        method: EvaluationMethods.notEvaluated,
      ),
      (
        pest: 'Hoja blanca',
        range: '1_10',
        level: AffectationLevels.low,
        method: EvaluationMethods.symptomaticPlants,
      ),
      (
        pest: 'HOJA_BLANCA',
        range: '11_30',
        level: AffectationLevels.medium,
        method: EvaluationMethods.symptomaticPlants,
      ),
      (
        pest: 'hoja blanca',
        range: 'MAS_30',
        level: AffectationLevels.high,
        method: EvaluationMethods.symptomaticPlants,
      ),
      (
        pest: 'Hoja blanca',
        range: 'NO_EVALUADO',
        level: AffectationLevels.notEvaluated,
        method: EvaluationMethods.notEvaluated,
      ),
      (
        pest: 'Sogata',
        range: 'AISLADA',
        level: AffectationLevels.low,
        method: EvaluationMethods.observedPresence,
      ),
      (
        pest: 'sogata',
        range: 'FRECUENTE',
        level: AffectationLevels.medium,
        method: EvaluationMethods.observedPresence,
      ),
      (
        pest: 'TAGOSODES ORIZICOLUS',
        range: 'ABUNDANTE',
        level: AffectationLevels.high,
        method: EvaluationMethods.observedPresence,
      ),
      (
        pest: 'Sogata',
        range: 'NO_EVALUADO',
        level: AffectationLevels.notEvaluated,
        method: EvaluationMethods.notEvaluated,
      ),
    ];

    for (final testCase in cases) {
      test('${testCase.pest} + ${testCase.range}', () {
        final result = service.evaluate(
          pestName: testCase.pest,
          range: testCase.range,
        );

        expect(result.nivel, testCase.level);
        expect(result.metodo, testCase.method);
        expect(result.rango, testCase.range);
      });
    }

    test('rechaza un rango que no corresponde a la plaga', () {
      expect(
        () => service.evaluate(pestName: 'Sogata', range: '21_40'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rechaza una plaga no soportada', () {
      expect(
        () => service.evaluate(pestName: 'Plaga desconocida', range: '1_20'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
