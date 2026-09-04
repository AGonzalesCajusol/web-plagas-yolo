import 'package:flutter_test/flutter_test.dart';
import 'package:plagas_arroz/models/affectation_evaluation.dart';
import 'package:plagas_arroz/services/recommendation_service.dart';

void main() {
  const service = RecommendationService();

  void expectCompleteRecommendation({
    required String inputPest,
    required String expectedPest,
    required String level,
    bool expectsWarning = false,
  }) {
    final result = service.recommend(pestName: inputPest, level: level);

    expect(result.version, RecommendationService.version);
    expect(result.version, 'MIP_V1');
    expect(result.pestName, expectedPest);
    expect(result.level, level);
    expect(result.monitoring, isNotEmpty);
    expect(result.culturalManagement, isNotEmpty);
    expect(result.integratedManagement, isNotEmpty);
    expect(result.phytosanitaryControl, isNotEmpty);

    if (expectsWarning) {
      expect(result.warning, isNotNull);
      expect(result.warning, contains('enfermedad viral'));
      expect(result.warning, contains('vector Sogata'));
    } else {
      expect(result.warning, isNull);
    }
  }

  group('RecommendationService', () {
    final cases = <({
      String inputPest,
      String expectedPest,
      String level,
      bool warning,
    })>[
      (
        inputPest: 'ANUBLO',
        expectedPest: 'Añublo bacteriano',
        level: AffectationLevels.low,
        warning: false,
      ),
      (
        inputPest: 'Añublo bacteriano',
        expectedPest: 'Añublo bacteriano',
        level: AffectationLevels.medium,
        warning: false,
      ),
      (
        inputPest: 'AÑUBLO',
        expectedPest: 'Añublo bacteriano',
        level: AffectationLevels.high,
        warning: false,
      ),
      (
        inputPest: 'Hoja blanca',
        expectedPest: 'Hoja blanca',
        level: AffectationLevels.low,
        warning: true,
      ),
      (
        inputPest: 'HOJA_BLANCA',
        expectedPest: 'Hoja blanca',
        level: AffectationLevels.medium,
        warning: true,
      ),
      (
        inputPest: 'hoja blanca',
        expectedPest: 'Hoja blanca',
        level: AffectationLevels.high,
        warning: true,
      ),
      (
        inputPest: 'Sogata',
        expectedPest: 'Sogata',
        level: AffectationLevels.low,
        warning: false,
      ),
      (
        inputPest: 'sogata',
        expectedPest: 'Sogata',
        level: AffectationLevels.medium,
        warning: false,
      ),
      (
        inputPest: 'TAGOSODES ORIZICOLUS',
        expectedPest: 'Sogata',
        level: AffectationLevels.high,
        warning: false,
      ),
    ];

    for (final testCase in cases) {
      test('${testCase.expectedPest} + ${testCase.level}', () {
        expectCompleteRecommendation(
          inputPest: testCase.inputPest,
          expectedPest: testCase.expectedPest,
          level: testCase.level,
          expectsWarning: testCase.warning,
        );
      });
    }

    for (final pest in const [
      (input: 'ANUBLO', expected: 'Añublo bacteriano', warning: false),
      (input: 'Hoja blanca', expected: 'Hoja blanca', warning: true),
      (input: 'Sogata', expected: 'Sogata', warning: false),
    ]) {
      test('${pest.expected} + NO_EVALUADO', () {
        expectCompleteRecommendation(
          inputPest: pest.input,
          expectedPest: pest.expected,
          level: AffectationLevels.notEvaluated,
          expectsWarning: pest.warning,
        );
      });
    }

    test('rechaza una plaga no soportada', () {
      expect(
        () => service.recommend(
          pestName: 'Plaga desconocida',
          level: AffectationLevels.low,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rechaza un nivel no soportado', () {
      expect(
        () => service.recommend(pestName: 'Sogata', level: 'CRITICO'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
