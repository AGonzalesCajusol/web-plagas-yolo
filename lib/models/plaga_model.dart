class PlagaModel {
  final int? id;
  final String? nombreCientifico;
  final String? nombreComun;
  final String? descripcion;

  const PlagaModel({
    this.id,
    this.nombreCientifico,
    this.nombreComun,
    this.descripcion,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre_cientifico': nombreCientifico,
      'nombre_comun': nombreComun,
      'descripcion': descripcion,
    };
  }

  factory PlagaModel.fromMap(Map<String, dynamic> map) {
    return PlagaModel(
      id: map['id'] as int?,
      nombreCientifico: map['nombre_cientifico'] as String?,
      nombreComun: map['nombre_comun'] as String?,
      descripcion: map['descripcion'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return toMap();
  }

  factory PlagaModel.fromJson(Map<String, dynamic> json) {
    return PlagaModel.fromMap(json);
  }
}
