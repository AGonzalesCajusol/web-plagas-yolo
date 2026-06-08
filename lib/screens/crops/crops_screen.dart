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
              title: const Text('Nueva Parcela'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nombreController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la Parcela',
                      prefixIcon: Icon(Icons.landscape_outlined),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    coordenadasCapturadas ?? 'Ubicación no capturada',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
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
                    decoration: const InputDecoration(labelText: 'Latitud'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: longitudeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Longitud'),
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

  @override
  void dispose() {
    nombreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Parcelas'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _showAddCropDialog();
        },
        child: const Icon(Icons.add_location_alt_outlined),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: CropService.instance.getCultivos(userId: widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudieron cargar tus parcelas.',
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }

          final cultivos = snapshot.data ?? [];
          if (cultivos.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  'Aún no has registrado ninguna parcela. Toca el botón + para empezar.',
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: cultivos.length,
            itemBuilder: (context, index) {
              final cultivo = cultivos[index];
              final cultivoId = cultivo['id']?.toString() ?? '';
              final nombre =
                  cultivo['nombre_parcela']?.toString() ?? 'Sin nombre';
              final coordenadas =
                  cultivo['coordenadas_sector']?.toString() ?? 'Sin ubicación';

              return Card(
                elevation: 1,
                color: colorScheme.surfaceContainerLow,
                clipBehavior: Clip.antiAlias,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    foregroundColor: colorScheme.onPrimaryContainer,
                    child: const Icon(Icons.landscape),
                  ),
                  title: Text(
                    nombre,
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    coordenadas,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: 'Eliminar parcela',
                    icon: const Icon(Icons.delete_outline),
                    color: colorScheme.error,
                    onPressed: cultivoId.isEmpty
                        ? null
                        : () => _confirmDeleteCrop(
                              cultivoId: cultivoId,
                              nombre: nombre,
                            ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
