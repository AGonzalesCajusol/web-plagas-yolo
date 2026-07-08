import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/crop_service.dart';

class CropsScreen extends StatefulWidget {
  const CropsScreen({
    super.key,
    required this.userId,
    this.returnOnCreate = false,
  });

  final String userId;
  final bool returnOnCreate;

  @override
  State<CropsScreen> createState() => _CropsScreenState();
}

class _CropsScreenState extends State<CropsScreen> {
  final TextEditingController nombreController = TextEditingController();

  Future<void> _confirmDeleteCrop({
    required String cultivoId,
    required String nombre,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Eliminar parcela'),
          content: Text('Se eliminará la parcela "$nombre".'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final result = await CropService.instance.deleteCultivo(
      userId: widget.userId,
      cultivoId: cultivoId,
    );

    if (!mounted) return;

    switch (result) {
      case DeleteCultivoResult.deleted:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parcela eliminada correctamente.'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {});
      case DeleteCultivoResult.hasDetections:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se puede eliminar esta parcela porque tiene detecciones registradas.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      case DeleteCultivoResult.notFound:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo eliminar la parcela seleccionada.'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  Future<void> _showAddCropDialog() async {
    nombreController.clear();

    final cropId = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? coordenadasCapturadas;
        bool isGettingLocation = false;
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.add_location_alt_outlined,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Nueva parcela'),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nombreController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _fieldDecoration(
                        context: context,
                        labelText: 'Nombre de la parcela',
                        icon: Icons.landscape_outlined,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6FAF6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF2E7D32).withOpacity(0.10),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 20,
                            color: Color(0xFF2E7D32),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              coordenadasCapturadas ?? 'Ubicación no capturada',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: const Color(0xFF6B7280),
                                    height: 1.35,
                                    letterSpacing: 0,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: isGettingLocation
                          ? null
                          : () async {
                              setDialogState(() {
                                isGettingLocation = true;
                                coordenadasCapturadas = 'Buscando señal GPS...';
                              });

                              final locationText =
                                  await _getCurrentLocationText();

                              if (context.mounted) {
                                setDialogState(() {
                                  coordenadasCapturadas = locationText;
                                  isGettingLocation = false;
                                });
                              }
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2E7D32),
                        side: BorderSide(
                          color: const Color(0xFF2E7D32).withOpacity(0.35),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      icon: isGettingLocation
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.gps_fixed_outlined),
                      label: Text(
                        isGettingLocation
                            ? 'Obteniendo ubicación...'
                            : 'Obtener ubicación actual',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSaving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final nombre = nombreController.text.trim();
                          final coordenadas = coordenadasCapturadas;

                          if (nombre.isEmpty || coordenadas == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Ingresa el nombre y captura la ubicación.',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                          });

                          final cropId = await CropService.instance.addCultivo(
                            userId: widget.userId,
                            nombre: nombre,
                            coordenadas: coordenadas,
                          );

                          debugPrint('Cultivo creado: $cropId');

                          if (!context.mounted) return;
                          Navigator.pop(context, cropId);
                        },
                  child: isSaving
                      ? const Text('Guardando...')
                      : const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (cropId == null || !mounted) return;

    if (widget.returnOnCreate) {
      Navigator.pop(context, cropId);
    } else {
      setState(() {});
    }
  }

  Future<void> _showEditCropDialog(Map<String, dynamic> cultivo) async {
    final cultivoId = cultivo['id']?.toString() ?? '';
    final nombreActual = cultivo['nombre_parcela']?.toString() ?? '';
    final coordenadasActuales =
        cultivo['coordenadas_sector']?.toString() ?? '';

    if (cultivoId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo identificar la parcela seleccionada.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final editNombreController = TextEditingController(text: nombreActual);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        String coordenadasCapturadas = coordenadasActuales;
        bool isGettingLocation = false;
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Editar parcela'),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: editNombreController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _fieldDecoration(
                        context: context,
                        labelText: 'Nombre de la parcela',
                        icon: Icons.grass_outlined,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6FAF6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF2E7D32).withOpacity(0.10),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 20,
                            color: Color(0xFF2E7D32),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              coordenadasCapturadas.trim().isEmpty
                                  ? 'Ubicación no capturada'
                                  : coordenadasCapturadas,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: const Color(0xFF6B7280),
                                    height: 1.35,
                                    letterSpacing: 0,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: isGettingLocation
                              ? null
                              : () async {
                                  setDialogState(() {
                                    isGettingLocation = true;
                                    coordenadasCapturadas =
                                        'Buscando señal GPS...';
                                  });

                                  final locationText =
                                      await _getCurrentLocationText();

                                  if (context.mounted) {
                                    setDialogState(() {
                                      coordenadasCapturadas = locationText;
                                      isGettingLocation = false;
                                    });
                                  }
                                },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2E7D32),
                            side: BorderSide(
                              color:
                                  const Color(0xFF2E7D32).withOpacity(0.35),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          icon: isGettingLocation
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.gps_fixed_outlined),
                          label: Text(
                            isGettingLocation
                                ? 'Obteniendo ubicación...'
                                : 'Actualizar ubicación',
                          ),
                        ),
                        TextButton.icon(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final manualLocation =
                                      await _showManualLocationDialog();
                                  if (manualLocation == null ||
                                      !context.mounted) {
                                    return;
                                  }
                                  setDialogState(() {
                                    coordenadasCapturadas = manualLocation;
                                  });
                                },
                          icon: const Icon(Icons.edit_location_alt_outlined),
                          label: const Text('Ingresar manualmente'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSaving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final nombre = editNombreController.text.trim();
                          final coordenadas = coordenadasCapturadas.trim();

                          if (nombre.isEmpty || coordenadas.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Ingresa el nombre y las coordenadas.',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                          });

                          final success =
                              await CropService.instance.updateCultivo(
                            userId: widget.userId,
                            cultivoId: cultivoId,
                            nombre: nombre,
                            coordenadas: coordenadas,
                          );

                          if (!mounted) return;

                          if (success) {
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Parcela actualizada correctamente.',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                            setState(() {});
                          } else {
                            setDialogState(() {
                              isSaving = false;
                            });
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No se pudo actualizar la parcela.',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  child: isSaving
                      ? const Text('Guardando...')
                      : const Text('Guardar cambios'),
                ),
              ],
            );
          },
        );
      },
    );

    editNombreController.dispose();
  }

  Future<String> _getCurrentLocationText() async {
    final automaticLocation = await _tryAutomaticLocationText();
    if (automaticLocation != null) return automaticLocation;

    if (!mounted) return 'Ubicación no disponible';
    return _showCropLocationFallbackDialog();
  }

  Future<String?> _tryAutomaticLocationText() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('El servicio de ubicación está deshabilitado.');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Permiso de ubicación denegado.');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Permiso de ubicación denegado permanentemente.');
        return null;
      }

      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 15),
          ),
        );
        return _formatPosition(position);
      } on TimeoutException catch (error) {
        debugPrint('Timeout obteniendo ubicación actual: $error');
      } catch (error) {
        debugPrint('Error obteniendo ubicación actual: $error');
      }

      final lastKnownPosition = await Geolocator.getLastKnownPosition();
      if (lastKnownPosition != null) {
        return _formatPosition(lastKnownPosition);
      }
    } catch (error) {
      debugPrint('Error general obteniendo ubicación: $error');
    }

    return null;
  }

  Future<String> _showCropLocationFallbackDialog() async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('No se pudo obtener la ubicación automáticamente'),
          content: const Text(
            'Puedes registrar una ubicación manualmente o continuar sin coordenadas.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                'Ubicación no disponible',
              ),
              child: const Text('Continuar sin ubicación'),
            ),
            TextButton(
              onPressed: () async {
                final manualLocation = await _showManualLocationDialog();
                if (manualLocation == null || !dialogContext.mounted) return;
                Navigator.pop(dialogContext, manualLocation);
              },
              child: const Text('Ingresar coordenadas'),
            ),
            FilledButton(
              onPressed: () async {
                final retryLocation = await _tryAutomaticLocationText();
                if (!dialogContext.mounted) return;
                Navigator.pop(
                  dialogContext,
                  retryLocation ?? 'Ubicación no disponible',
                );
              },
              child: const Text('Reintentar GPS'),
            ),
          ],
        );
      },
    );

    return result ?? 'Ubicación no disponible';
  }

  Future<String?> _showManualLocationDialog() async {
    final latitudeController = TextEditingController();
    final longitudeController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? errorText;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('Ingresar coordenadas'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: latitudeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: _fieldDecoration(
                      context: context,
                      labelText: 'Latitud',
                      icon: Icons.explore_outlined,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: longitudeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: _fieldDecoration(
                      context: context,
                      labelText: 'Longitud',
                      icon: Icons.explore_outlined,
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final latitude = double.tryParse(
                      latitudeController.text.trim().replaceAll(',', '.'),
                    );
                    final longitude = double.tryParse(
                      longitudeController.text.trim().replaceAll(',', '.'),
                    );

                    if (!_isValidCoordinates(latitude, longitude)) {
                      setDialogState(() {
                        errorText = 'Ingresa una latitud y longitud válidas.';
                      });
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                      '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}',
                    );
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    latitudeController.dispose();
    longitudeController.dispose();
    return result;
  }

  String _formatPosition(Position position) {
    if (!_isValidCoordinates(position.latitude, position.longitude)) {
      return 'Ubicación no disponible';
    }

    return '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
  }

  bool _isValidCoordinates(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return false;
    if (latitude == 0.0 && longitude == 0.0) return false;
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  InputDecoration _fieldDecoration({
    required BuildContext context,
    required String labelText,
    required IconData icon,
  }) {
    const primaryGreen = Color(0xFF2E7D32);

    return InputDecoration(
      labelText: labelText,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFFF8FBF8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: primaryGreen.withOpacity(0.12),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: primaryGreen,
          width: 1.4,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }

  Widget _buildHeader({
    required BuildContext context,
    required int total,
  }) {
    const primaryGreen = Color(0xFF2E7D32);
    const darkGreen = Color(0xFF1B5E20);
    const textPrimary = Color(0xFF1F2933);
    const textSecondary = Color(0xFF6B7280);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.88),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: primaryGreen.withOpacity(0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: darkGreen.withOpacity(0.08),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(19),
              ),
              child: const Icon(
                Icons.agriculture_outlined,
                color: primaryGreen,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mis parcelas',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: textPrimary,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Administra tus zonas de monitoreo',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: textSecondary,
                          height: 1.35,
                          letterSpacing: 0,
                        ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                total == 1 ? '1 parcela' : '$total parcelas',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: darkGreen,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStateCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    bool showProgress = false,
    bool showAddButton = false,
    Color? iconColor,
  }) {
    const primaryGreen = Color(0xFF2E7D32);
    const darkGreen = Color(0xFF1B5E20);
    const textPrimary = Color(0xFF1F2933);
    const textSecondary = Color(0xFF6B7280);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 430),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: primaryGreen.withOpacity(0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: darkGreen.withOpacity(0.08),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  icon,
                  size: 34,
                  color: iconColor ?? primaryGreen,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: textPrimary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: textSecondary,
                      height: 1.4,
                      letterSpacing: 0,
                    ),
              ),
              if (showProgress) ...[
                const SizedBox(height: 20),
                const SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ],
              if (showAddButton) ...[
                const SizedBox(height: 22),
                ElevatedButton.icon(
                  onPressed: () async {
                    await _showAddCropDialog();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: darkGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar parcela'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCropCard({
    required BuildContext context,
    required Map<String, dynamic> cultivo,
  }) {
    const primaryGreen = Color(0xFF2E7D32);
    const darkGreen = Color(0xFF1B5E20);
    const textPrimary = Color(0xFF1F2933);
    const textSecondary = Color(0xFF6B7280);

    final cultivoId = cultivo['id']?.toString() ?? '';
    final nombre = cultivo['nombre_parcela']?.toString() ?? 'Sin nombre';
    final coordenadas =
        cultivo['coordenadas_sector']?.toString() ?? 'Sin ubicación';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: primaryGreen.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: darkGreen.withOpacity(0.07),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.grass_outlined,
              color: primaryGreen,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: textPrimary,
                              fontWeight: FontWeight.w900,
                              height: 1.18,
                              letterSpacing: 0,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Activa',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: darkGreen,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 17,
                      color: textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        coordenadas,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: textSecondary,
                              height: 1.35,
                              letterSpacing: 0,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6FAF6),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: primaryGreen.withOpacity(0.08),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.map_outlined,
                            size: 15,
                            color: primaryGreen,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Monitoreo',
                            style:
                                Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: primaryGreen,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Editar parcela',
                      icon: const Icon(Icons.edit_outlined),
                      color: primaryGreen,
                      onPressed: cultivoId.isEmpty
                          ? null
                          : () => _showEditCropDialog(cultivo),
                    ),
                    IconButton(
                      tooltip: 'Eliminar parcela',
                      icon: const Icon(Icons.delete_outline),
                      color: Theme.of(context).colorScheme.error,
                      onPressed: cultivoId.isEmpty
                          ? null
                          : () => _confirmDeleteCrop(
                                cultivoId: cultivoId,
                                nombre: nombre,
                              ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    nombreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const darkGreen = Color(0xFF1B5E20);
    const lightGreen = Color(0xFFE8F5E9);
    const backgroundColor = Color(0xFFF6FAF6);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Mis parcelas'),
        centerTitle: true,
        backgroundColor: lightGreen,
        elevation: 0,
        foregroundColor: darkGreen,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await _showAddCropDialog();
        },
        backgroundColor: darkGreen,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              lightGreen,
              backgroundColor,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: CropService.instance.getCultivos(userId: widget.userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Column(
                  children: [
                    _buildHeader(
                      context: context,
                      total: 0,
                    ),
                    Expanded(
                      child: _buildStateCard(
                        context: context,
                        icon: Icons.agriculture_outlined,
                        title: 'Cargando parcelas',
                        subtitle:
                            'Estamos preparando tus zonas de monitoreo.',
                        showProgress: true,
                      ),
                    ),
                  ],
                );
              }

              if (snapshot.hasError) {
                return Column(
                  children: [
                    _buildHeader(
                      context: context,
                      total: 0,
                    ),
                    Expanded(
                      child: _buildStateCard(
                        context: context,
                        icon: Icons.error_outline,
                        title: 'No se pudieron cargar tus parcelas',
                        subtitle:
                            'Intenta volver a abrir esta pantalla en unos momentos.',
                        iconColor: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                );
              }

              final cultivos = snapshot.data ?? [];
              if (cultivos.isEmpty) {
                return Column(
                  children: [
                    _buildHeader(
                      context: context,
                      total: 0,
                    ),
                    Expanded(
                      child: _buildStateCard(
                        context: context,
                        icon: Icons.eco_outlined,
                        title: 'Aún no tienes cultivos registrados',
                        subtitle:
                            'Agrega una parcela para empezar a organizar tus detecciones.',
                        showAddButton: true,
                      ),
                    ),
                  ],
                );
              }

              return ListView.builder(
                padding: EdgeInsets.only(
                  bottom: 96 + MediaQuery.of(context).padding.bottom,
                ),
                itemCount: cultivos.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildHeader(
                      context: context,
                      total: cultivos.length,
                    );
                  }

                  final cultivo = cultivos[index - 1];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: _buildCropCard(
                      context: context,
                      cultivo: cultivo,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
