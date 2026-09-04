import '../models/affectation_evaluation.dart';
import '../utils/pest_name_normalizer.dart';

class AffectationLevelService {
  const AffectationLevelService();

  AffectationEvaluation evaluate({
    required String pestName,
    required String range,
  }) {
    final normalizedPestName = PestNameNormalizer.normalize(pestName);
    final normalizedRange = range.trim().toUpperCase();

    switch (normalizedPestName) {
      case 'Añublo bacteriano':
        return _evaluateRange(
          pestName: normalizedPestName,
          range: normalizedRange,
          method: EvaluationMethods.symptomaticPanicle,
          levelsByRange: const {
            '1_20': AffectationLevels.low,
            '21_40': AffectationLevels.medium,
            'MAS_40': AffectationLevels.high,
          },
        );
      case 'Hoja blanca':
        return _evaluateRange(
          pestName: normalizedPestName,
          range: normalizedRange,
          method: EvaluationMethods.symptomaticPlants,
          levelsByRange: const {
            '1_10': AffectationLevels.low,
            '11_30': AffectationLevels.medium,
            'MAS_30': AffectationLevels.high,
          },
        );
      case 'Sogata':
        return _evaluateRange(
          pestName: normalizedPestName,
          range: normalizedRange,
          method: EvaluationMethods.observedPresence,
          levelsByRange: const {
            'AISLADA': AffectationLevels.low,
            'FRECUENTE': AffectationLevels.medium,
            'ABUNDANTE': AffectationLevels.high,
          },
        );
      default:
        throw ArgumentError.value(
          pestName,
          'pestName',
          'Plaga no soportada para evaluar el nivel de afectación.',
        );
    }
  }

  AffectationEvaluation _evaluateRange({
    required String pestName,
    required String range,
    required String method,
    required Map<String, String> levelsByRange,
  }) {
    if (range == AffectationLevels.notEvaluated) {
      return const AffectationEvaluation(
        nivel: AffectationLevels.notEvaluated,
        metodo: EvaluationMethods.notEvaluated,
        rango: AffectationLevels.notEvaluated,
      );
    }

    final level = levelsByRange[range];
    if (level == null) {
      throw ArgumentError.value(
        range,
        'range',
        'Rango de afectación no válido para $pestName.',
      );
    }

    return AffectationEvaluation(
      nivel: level,
      metodo: method,
      rango: range,
    );
  }
}
