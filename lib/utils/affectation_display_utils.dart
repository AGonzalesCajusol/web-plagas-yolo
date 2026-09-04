class AffectationDisplayUtils {
  const AffectationDisplayUtils._();

  static String levelLabel(String? level) {
    switch (_normalize(level)) {
      case 'BAJO':
        return 'Bajo';
      case 'MEDIO':
        return 'Medio';
      case 'ALTO':
        return 'Alto';
      case 'NO_EVALUADO':
        return 'No evaluado';
      default:
        return 'No registrado';
    }
  }

  static String methodLabel(String? method) {
    switch (_normalize(method)) {
      case 'PANICULA_SINTOMATICA':
        return 'Panícula con síntomas';
      case 'PLANTAS_SINTOMATICAS':
        return 'Plantas con síntomas';
      case 'PRESENCIA_OBSERVADA':
        return 'Presencia observada';
      case 'NO_EVALUADO':
        return 'No evaluado';
      default:
        return 'No registrado';
    }
  }

  static String rangeLabel(String? range) {
    switch (_normalize(range)) {
      case '1_20':
        return '1–20 % de la panícula';
      case '21_40':
        return '21–40 % de la panícula';
      case 'MAS_40':
        return 'Más de 40 % de la panícula';
      case '1_10':
        return '1–10 % de plantas';
      case '11_30':
        return '11–30 % de plantas';
      case 'MAS_30':
        return 'Más de 30 % de plantas';
      case 'AISLADA':
        return 'Presencia aislada';
      case 'FRECUENTE':
        return 'Presencia frecuente';
      case 'ABUNDANTE':
        return 'Presencia abundante';
      case 'NO_EVALUADO':
        return 'No evaluado';
      default:
        return 'No registrado';
    }
  }

  static bool hasRegisteredLevel(String? level) =>
      level != null && level.trim().isNotEmpty;

  static String _normalize(String? value) => value?.trim().toUpperCase() ?? '';
}
