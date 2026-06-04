import 'package:flutter/material.dart';

import '../../services/profile_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Map<String, dynamic>> _metricsFuture;

  @override
  void initState() {
    super.initState();
    _metricsFuture = ProfileService.instance.getDashboardMetrics();
  }

  Future<void> _reloadMetrics() async {
    setState(() {
      _metricsFuture = ProfileService.instance.getDashboardMetrics();
    });
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Widget _metricCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 1,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(icon, color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSyncPlaceholder() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sincronización pendiente: se implementará con Laravel/AWS.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil de Usuario'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _reloadMetrics,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _metricsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'No se pudieron cargar las métricas locales.',
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            }

            final metrics = snapshot.data ?? {};
            final totalDetecciones = _toInt(metrics['totalDetecciones']);
            final pendientes = _toInt(metrics['pendientesSincronizacion']);
            final sincronizadas = _toInt(metrics['sincronizadas']);

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  elevation: 1,
                  color: colorScheme.primaryContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: colorScheme.primary,
                          child: Icon(
                            Icons.person_outline_rounded,
                            color: colorScheme.onPrimary,
                            size: 34,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Agricultor Local',
                                style: textTheme.titleLarge?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Panel de control offline',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _metricCard(
                  context: context,
                  icon: Icons.analytics_outlined,
                  title: 'Total de plagas detectadas',
                  value: totalDetecciones.toString(),
                ),
                _metricCard(
                  context: context,
                  icon: Icons.bug_report_outlined,
                  title: 'Plaga más frecuente',
                  value: metrics['plagaMasFrecuente']?.toString() ?? 'Sin datos',
                ),
                _metricCard(
                  context: context,
                  icon: Icons.landscape_outlined,
                  title: 'Parcela con más incidencias',
                  value: metrics['parcelaMasAfectada']?.toString() ?? 'Sin datos',
                ),
                _metricCard(
                  context: context,
                  icon: Icons.cloud_upload_outlined,
                  title: 'Pendientes de sincronización',
                  value: pendientes.toString(),
                ),
                _metricCard(
                  context: context,
                  icon: Icons.cloud_done_outlined,
                  title: 'Registros sincronizados',
                  value: sincronizadas.toString(),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _showSyncPlaceholder,
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text('Sincronizar Datos'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}