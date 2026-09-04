class PestRecommendation {
  const PestRecommendation({
    required this.pestName,
    required this.level,
    required this.monitoring,
    required this.culturalManagement,
    required this.integratedManagement,
    required this.phytosanitaryControl,
    required this.version,
    this.warning,
  });

  final String pestName;
  final String level;
  final String monitoring;
  final String culturalManagement;
  final String integratedManagement;
  final String phytosanitaryControl;
  final String? warning;
  final String version;
}
