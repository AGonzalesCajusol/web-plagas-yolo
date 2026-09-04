import '../models/affectation_evaluation.dart';
import '../models/pest_recommendation.dart';
import '../utils/pest_name_normalizer.dart';

class RecommendationService {
  const RecommendationService();

  static const String version = 'MIP_V1';

  static const String _whiteLeafWarning =
      'La Hoja Blanca es una enfermedad viral. El control químico no elimina '
      'el virus de una planta ya infectada; cuando corresponde, el manejo '
      'químico se dirige principalmente al vector Sogata.';

  static const Map<String, Map<String, _RecommendationContent>>
      _recommendations = {
    'Añublo bacteriano': {
      AffectationLevels.low: _RecommendationContent(
        monitoring:
            'Continúa monitoreando las panículas y revisa plantas cercanas para identificar si los síntomas aumentan.',
        culturalManagement:
            'Mantén una fertilización equilibrada, evita el exceso de nitrógeno y conserva un manejo adecuado del agua y las malezas.',
        integratedManagement:
            'Mantén buenas prácticas de manejo del cultivo y observa periódicamente la evolución de los síntomas.',
        phytosanitaryControl:
            'No se recomienda realizar una aplicación automática únicamente por esta detección. Continúa el monitoreo.',
      ),
      AffectationLevels.medium: _RecommendationContent(
        monitoring:
            'Incrementa la frecuencia del monitoreo y revisa otras zonas de la parcela para determinar si la afectación está aumentando.',
        culturalManagement:
            'Revisa la fertilización, evita excesos de nitrógeno y refuerza el manejo del agua, malezas y residuos del cultivo.',
        integratedManagement:
            'Combina monitoreo frecuente con buenas prácticas de manejo y evita utilizar material afectado como fuente de semilla.',
        phytosanitaryControl:
            'Si los síntomas continúan avanzando, solicita una evaluación técnica para determinar si corresponde utilizar un producto registrado para arroz.',
      ),
      AffectationLevels.high: _RecommendationContent(
        monitoring:
            'Realiza una evaluación prioritaria de la parcela para determinar la extensión de las panículas afectadas.',
        culturalManagement:
            'Refuerza el manejo del agua, la fertilización y los residuos del cultivo, y evita utilizar material afectado como semilla.',
        integratedManagement:
            'Aplica un manejo integrado y solicita asistencia técnica para definir las medidas necesarias en la parcela.',
        phytosanitaryControl:
            'Puede ser necesario evaluar un control fitosanitario. Utiliza únicamente productos autorizados para arroz y sigue las indicaciones de la etiqueta y de un profesional.',
      ),
    },
    'Hoja blanca': {
      AffectationLevels.low: _RecommendationContent(
        monitoring:
            'Continúa monitoreando el lote y revisa la presencia de Sogata en plantas cercanas.',
        culturalManagement:
            'Controla malezas hospederas y mantén buenas prácticas de manejo del cultivo.',
        integratedManagement:
            'Conserva enemigos naturales y evita aplicaciones innecesarias que puedan afectar el equilibrio biológico del cultivo.',
        phytosanitaryControl:
            'No se recomienda una aplicación automática. Primero evalúa la presencia y población de Sogata.',
      ),
      AffectationLevels.medium: _RecommendationContent(
        monitoring:
            'Incrementa el monitoreo de plantas con síntomas y evalúa la presencia de Sogata en diferentes sectores de la parcela.',
        culturalManagement:
            'Refuerza el control de malezas hospederas y revisa las zonas cercanas donde puedan mantenerse el vector y la enfermedad.',
        integratedManagement:
            'Combina vigilancia de síntomas, monitoreo del vector y conservación de enemigos naturales.',
        phytosanitaryControl:
            'Evalúa técnicamente la población de Sogata antes de decidir una intervención dirigida al vector.',
      ),
      AffectationLevels.high: _RecommendationContent(
        monitoring:
            'Realiza una evaluación prioritaria para determinar la extensión de plantas con síntomas y la presencia de Sogata.',
        culturalManagement:
            'Refuerza las medidas para reducir fuentes de propagación y controla malezas hospederas dentro y alrededor de la parcela.',
        integratedManagement:
            'Intensifica el manejo integrado del complejo Sogata–Hoja Blanca y solicita asistencia técnica.',
        phytosanitaryControl:
            'Si la población de Sogata justifica una intervención, utiliza únicamente productos registrados para el cultivo de arroz y sigue las indicaciones técnicas correspondientes.',
      ),
    },
    'Sogata': {
      AffectationLevels.low: _RecommendationContent(
        monitoring:
            'Continúa monitoreando la parcela y revisa plantas cercanas para detectar si aumenta la presencia de Sogata.',
        culturalManagement:
            'Mantén controladas las malezas hospederas y conserva buenas condiciones de manejo del cultivo.',
        integratedManagement:
            'Favorece la conservación de enemigos naturales y vigila posibles síntomas de Hoja Blanca.',
        phytosanitaryControl:
            'Evita aplicaciones preventivas innecesarias mientras la presencia sea baja.',
      ),
      AffectationLevels.medium: _RecommendationContent(
        monitoring:
            'Aumenta la frecuencia del monitoreo y realiza una evaluación de la población de Sogata en diferentes sectores de la parcela.',
        culturalManagement:
            'Refuerza el control de malezas hospederas y revisa las áreas cercanas al cultivo.',
        integratedManagement:
            'Vigila síntomas de Hoja Blanca y conserva enemigos naturales mientras evalúas la evolución de la población.',
        phytosanitaryControl:
            'Determina primero mediante monitoreo si la población justifica una intervención fitosanitaria.',
      ),
      AffectationLevels.high: _RecommendationContent(
        monitoring:
            'Realiza una evaluación prioritaria de la población de Sogata y revisa si existen síntomas asociados a Hoja Blanca.',
        culturalManagement:
            'Refuerza el manejo de malezas y otros posibles hospederos presentes en la parcela y sus alrededores.',
        integratedManagement:
            'Aplica un manejo integrado, conserva controladores biológicos cuando sea posible y solicita evaluación agronómica.',
        phytosanitaryControl:
            'Si el monitoreo confirma la necesidad de control, utiliza únicamente un insecticida registrado para arroz y Sogata, siguiendo la etiqueta y la recomendación de un profesional.',
      ),
    },
  };

  PestRecommendation recommend({
    required String pestName,
    required String level,
  }) {
    final normalizedPestName = PestNameNormalizer.normalize(pestName);
    final pestRecommendations = _recommendations[normalizedPestName];

    if (pestRecommendations == null) {
      throw ArgumentError.value(
        pestName,
        'pestName',
        'Plaga no soportada para generar recomendaciones.',
      );
    }

    final normalizedLevel = level.trim().toUpperCase();
    final warning =
        normalizedPestName == 'Hoja blanca' ? _whiteLeafWarning : null;

    if (normalizedLevel == AffectationLevels.notEvaluated) {
      return PestRecommendation(
        pestName: normalizedPestName,
        level: AffectationLevels.notEvaluated,
        monitoring:
            'Realiza una evaluación de campo para determinar el nivel de afectación antes de tomar una decisión de manejo.',
        culturalManagement:
            'Mantén el monitoreo y aplica prácticas generales de manejo integrado del cultivo.',
        integratedManagement:
            'Combina la evaluación de campo con prácticas generales de manejo integrado antes de decidir una intervención.',
        phytosanitaryControl:
            'No realices una aplicación fitosanitaria basándote únicamente en la detección de la aplicación. Solicita evaluación técnica si observas aumento de síntomas o presencia de la plaga.',
        warning: warning,
        version: version,
      );
    }

    final content = pestRecommendations[normalizedLevel];
    if (content == null) {
      throw ArgumentError.value(
        level,
        'level',
        'Nivel de afectación no válido.',
      );
    }

    return PestRecommendation(
      pestName: normalizedPestName,
      level: normalizedLevel,
      monitoring: content.monitoring,
      culturalManagement: content.culturalManagement,
      integratedManagement: content.integratedManagement,
      phytosanitaryControl: content.phytosanitaryControl,
      warning: warning,
      version: version,
    );
  }
}

class _RecommendationContent {
  const _RecommendationContent({
    required this.monitoring,
    required this.culturalManagement,
    required this.integratedManagement,
    required this.phytosanitaryControl,
  });

  final String monitoring;
  final String culturalManagement;
  final String integratedManagement;
  final String phytosanitaryControl;
}
