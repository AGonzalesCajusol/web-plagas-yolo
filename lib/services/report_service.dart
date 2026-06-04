import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ReportService {
  Future<String> generateFullReport(List<Map<String, dynamic>> detecciones) async {
    final pdf = pw.Document();
    final generatedAt = DateTime.now();
    final totalMuestras = detecciones.length;
    final parcelas = detecciones
    .map((d) => d['nombre_parcela']?.toString().trim())
    .where((nombre) => nombre != null && nombre.isNotEmpty)
    .cast<String>()
    .toSet();

    final parcelaReporte = parcelas.length == 1
        ? parcelas.first
        : parcelas.isEmpty
            ? 'Parcela Principal'
            : 'Varias parcelas';
    final plagaMasFrecuente = _mostFrequentPest(detecciones);

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(32),
          theme: pw.ThemeData.withFont(),
        ),
        header: (context) => _buildHeader(
            generatedAt,
            parcelaReporte,
          ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          ),
        ),
        build: (context) => [
          _buildSummaryBox(
            totalMuestras: totalMuestras,
            plagaMasFrecuente: plagaMasFrecuente,
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Detalle de detecciones',
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green900,
            ),
          ),
          pw.SizedBox(height: 10),
          _buildDetailsTable(detecciones),
        ],
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final fileName =
        'reporte_plagas_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(await pdf.save(), flush: true);

    return file.path;
  }

  pw.Widget _buildHeader(
      DateTime generatedAt,
      String parcelaReporte,
    ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 18),
      padding: const pw.EdgeInsets.only(bottom: 14),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            color: PdfColors.green800,
            width: 1.2,
          ),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'SISTEMA DE VISIÓN COMPUTACIONAL - REPORTE DE PLAGAS',
            style: pw.TextStyle(
              fontSize: 17,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green900,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'Caserío / Parcela: $parcelaReporte',
            style: const pw.TextStyle(
              fontSize: 11,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            'Fecha de generación: ${_formatDate(generatedAt)}',
            style: const pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryBox({
    required int totalMuestras,
    required String plagaMasFrecuente,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        border: pw.Border.all(color: PdfColors.green700, width: 0.8),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: _summaryMetric(
              label: 'Total de muestras analizadas',
              value: totalMuestras.toString(),
            ),
          ),
          pw.Container(width: 1, height: 42, color: PdfColors.green200),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: _summaryMetric(
              label: 'Plaga más frecuente',
              value: plagaMasFrecuente,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _summaryMetric({
    required String label,
    required String value,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(
            fontSize: 9,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.green900,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildDetailsTable(List<Map<String, dynamic>> detecciones) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.green800),
        children: [
          _headerCell('N° / Fecha'),
          _headerCell('Plaga Detectada'),
          _headerCell('Parcela'),
          _headerCell('Confianza (%)'),
          _headerCell('Ubicación (Lat/Lon)'),
          _headerCell('Evidencia visual'),
        ],
      ),
    ];

    for (var index = 0; index < detecciones.length; index++) {
      final detection = detecciones[index];
      final confidence = _toDouble(detection['confianza']);
      final latitude = _toDouble(detection['latitud']);
      final longitude = _toDouble(detection['longitud']);
      final image = _loadPdfImage(detection['ruta_imagen']?.toString());
      final pestName = detection['nombre_comun']?.toString() ?? 'No disponible';
      final parcelName =
        detection['nombre_parcela']?.toString() ?? 'Parcela Principal';

      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: index.isEven ? PdfColors.white : PdfColors.grey100,
          ),
          children: [
            _bodyCell('${index + 1}\n${_formatDateValue(detection['fecha_hora'])}'),
            _bodyCell(pestName),
            _bodyCell(parcelName),
            _bodyCell('${(confidence * 100).toStringAsFixed(1)}%'),
            _bodyCell(
              'Lat: ${latitude.toStringAsFixed(6)}\n'
              'Lon: ${longitude.toStringAsFixed(6)}',
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: _buildEvidenceImage(
                image: image,
                detection: detection,
                pestName: pestName,
                confidence: confidence,
              ),
            ),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.45),
        1: pw.FlexColumnWidth(1.7),
        2: pw.FlexColumnWidth(1.05),
        3: pw.FlexColumnWidth(1.75),
        4: pw.FlexColumnWidth(3),
      },
      children: rows,
    );
  }

  pw.Widget _headerCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _bodyCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: const pw.TextStyle(
          fontSize: 8.5,
          color: PdfColors.grey900,
        ),
      ),
    );
  }

  pw.Widget _buildEvidenceImage({
    required pw.MemoryImage? image,
    required Map<String, dynamic> detection,
    required String pestName,
    required double confidence,
  }) {
    const imageWidth = 240.0;
    const imageHeight = 160.0;

    if (image == null) {
      return pw.SizedBox(
        width: imageWidth,
        height: imageHeight,
        child: pw.Container(
          alignment: pw.Alignment.center,
          color: PdfColors.grey300,
          child: pw.Text(
            'Sin imagen',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
      );
    }

    final boxLeft = _nullableDouble(detection['box_left']);
    final boxTop = _nullableDouble(detection['box_top']);
    final boxRight = _nullableDouble(detection['box_right']);
    final boxBottom = _nullableDouble(detection['box_bottom']);
    final hasBox = boxLeft != null &&
        boxTop != null &&
        boxRight != null &&
        boxBottom != null &&
        boxRight > boxLeft &&
        boxBottom > boxTop;

    return pw.SizedBox(
      width: imageWidth,
      height: imageHeight,
      child: pw.Stack(
        children: [
          pw.Positioned.fill(
            child: pw.Image(
              image,
              fit: pw.BoxFit.fill,
            ),
          ),
          if (hasBox)
            pw.Positioned(
              left: boxLeft.clamp(0.0, 1.0) * imageWidth,
              top: boxTop.clamp(0.0, 1.0) * imageHeight,
              child: pw.Container(
                width: (boxRight.clamp(0.0, 1.0) -
                        boxLeft.clamp(0.0, 1.0)) *
                    imageWidth,
                height: (boxBottom.clamp(0.0, 1.0) -
                        boxTop.clamp(0.0, 1.0)) *
                    imageHeight,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColors.green,
                    width: 2,
                  ),
                ),
                child: pw.Align(
                  alignment: pw.Alignment.topLeft,
                  child: pw.Container(
                    color: PdfColors.green,
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 1,
                    ),
                    child: pw.Text(
                      '$pestName ${(confidence * 100).round()}%',
                      maxLines: 1,
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 6,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  pw.MemoryImage? _loadPdfImage(String? path) {
    if (path == null || path.trim().isEmpty) return null;

    final file = File(path);
    if (!file.existsSync()) return null;

    try {
      return pw.MemoryImage(file.readAsBytesSync());
    } catch (_) {
      return null;
    }
  }

  String _mostFrequentPest(List<Map<String, dynamic>> detecciones) {
    if (detecciones.isEmpty) return 'Sin registros';

    final counts = <String, int>{};
    for (final detection in detecciones) {
      final name = detection['nombre_comun']?.toString() ?? 'No disponible';
      counts[name] = (counts[name] ?? 0) + 1;
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.first.key;
  }

  String _formatDateValue(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'Fecha no disponible';
    return _formatDate(date);
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  double? _nullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
