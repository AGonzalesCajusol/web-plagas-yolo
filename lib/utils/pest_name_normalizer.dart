class PestNameNormalizer {
  const PestNameNormalizer._();

  static String normalize(String value) {
    final raw = value.trim();

    if (raw.isEmpty) {
      return 'Sin diagnóstico';
    }

    final key = _normalizeKey(raw);

    if (key == 'ANUBLO' ||
        key == 'ANUBLO BACTERIANO' ||
        key == 'ANUBLO BACTERIAL' ||
        key == 'ANUBLO DEL ARROZ' ||
        key == 'ANUBLO BACTERIANO DEL ARROZ') {
      return 'Añublo bacteriano';
    }

    if (key == 'HOJA BLANCA' ||
        key == 'HOJA_BLANCA' ||
        key == 'VIRUS DE LA HOJA BLANCA' ||
        key == 'HOJA BLANCA DEL ARROZ') {
      return 'Hoja blanca';
    }

    if (key == 'SOGATA' || key == 'TAGOSODES ORIZICOLUS') {
      return 'Sogata';
    }

    if (key == 'SANO' ||
        key == 'ARROZ SANO' ||
        key == 'SIN PLAGA' ||
        key == 'SIN PLAGA VISIBLE' ||
        key == 'ARROZ SIN PLAGA VISIBLE') {
      return 'Arroz sano';
    }

    return raw;
  }

  static String _normalizeKey(String value) {
    return value
        .trim()
        .toUpperCase()
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ñ', 'N')
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}