class AffectationLevels {
  const AffectationLevels._();

  static const String low = 'BAJO';
  static const String medium = 'MEDIO';
  static const String high = 'ALTO';
  static const String notEvaluated = 'NO_EVALUADO';
}

class EvaluationMethods {
  const EvaluationMethods._();

  static const String symptomaticPanicle = 'PANICULA_SINTOMATICA';
  static const String symptomaticPlants = 'PLANTAS_SINTOMATICAS';
  static const String observedPresence = 'PRESENCIA_OBSERVADA';
  static const String notEvaluated = 'NO_EVALUADO';
}

class AffectationEvaluation {
  const AffectationEvaluation({
    required this.nivel,
    required this.metodo,
    required this.rango,
  });

  final String nivel;
  final String metodo;
  final String rango;
}
