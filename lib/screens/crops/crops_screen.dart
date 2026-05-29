import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/crop_service.dart';

class CropsScreen extends StatefulWidget {
  const CropsScreen({super.key});

  @override
  State<CropsScreen> createState() => _CropsScreenState();
}

class _CropsScreenState extends State<CropsScreen> {
  Future<void> _showAddCropDialog() async {
    final nombreController = TextEditingController();

    final resultado = await showDialog<bool>(
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

                            final position = await _getCurrentPosition();

                            if (context.mounted) {
                              setDialogState(() {
                                coordenadasCapturadas =
                                    '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
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
                            nombre,
                            coordenadas,
                          );

                          debugPrint('Cultivo creado: $cropId');

                          if (!context.mounted) return;
                          Navigator.pop(context, true);
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

    nombreController.dispose();

    if (resultado == true && mounted) {
      setState(() {});
    }
  }

  Future<Position> _getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('El servicio de ubicación está deshabilitado.');
        return _fallbackRegionalPosition();
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Permiso de ubicación denegado.');
          return _fallbackRegionalPosition();
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Permiso de ubicación denegado permanentemente.');
        return _fallbackRegionalPosition();
      }

      final lastKnownPosition = await Geolocator.getLastKnownPosition();
      if (lastKnownPosition != null) {
        return lastKnownPosition;
      }

      try {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 5),
        );
      } on TimeoutException catch (error) {
        debugPrint('Timeout obteniendo ubicación actual: $error');
        return _fallbackRegionalPosition();
      } catch (error) {
        debugPrint('Error obteniendo ubicación actual: $error');
        return _fallbackRegionalPosition();
      }
    } catch (error) {
      debugPrint('Error general obteniendo ubicación: $error');
      return _fallbackRegionalPosition();
    }
  }

  Position _fallbackRegionalPosition() {
    return Position(
      latitude: -6.771,
      longitude: -79.840,
      timestamp: DateTime.now(),
      accuracy: 0.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );
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
        future: CropService.instance.getCultivos(),
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
                ),
              );
            },
          );
        },
      ),
    );
  }
}
