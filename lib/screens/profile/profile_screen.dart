import 'package:flutter/material.dart';

import '../../services/profile_service.dart';
import 'edit_profile_screen.dart';
import '../auth/login_screen.dart';
import '../../services/sync_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.user,
  });

  final Map<String, dynamic> user;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Map<String, dynamic>> _metricsFuture;
  late Map<String, dynamic> _currentUser;

  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _currentUser = Map<String, dynamic>.from(widget.user);
    _metricsFuture = ProfileService.instance.getDashboardMetrics(
      userId: _currentUserId,
    );
  }

  Future<void> _reloadMetrics() async {
    setState(() {
      _metricsFuture = ProfileService.instance.getDashboardMetrics(
        userId: _currentUserId,
      );
    });
  }

  Future<void> _syncNow() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      final result = await SyncService.instance.syncPendingDetections(
        user: _currentUser,
      );

      await _reloadMetrics();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sincronización finalizada. '
            'Total: ${result.total}, '
            'correctas: ${result.synced}, '
            'errores: ${result.failed}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo sincronizar: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  String get _currentUserId => _currentUser['id']?.toString() ?? '';

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

  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final userName =
        _currentUser['nombre']?.toString().trim().isNotEmpty == true
            ? _currentUser['nombre'].toString()
            : 'Agricultor Local';

    final userEmail = _currentUser['email']?.toString() ?? 'Sin correo';
    final userRole = _currentUser['rol']?.toString() ?? 'AGRICULTOR';

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
            final errores = _toInt(metrics['erroresSincronizacion']);
            final sincronizando = _toInt(metrics['sincronizando']);

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
                                userName,
                                style: textTheme.titleLarge?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$userRole • $userEmail',
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
                OutlinedButton.icon(
                  onPressed: () async {
                    final updatedUser =
                        await Navigator.push<Map<String, dynamic>>(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            EditProfileScreen(user: _currentUser),
                      ),
                    );

                    if (updatedUser == null || !mounted) return;

                    setState(() {
                      _currentUser = updatedUser;
                    });
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar datos del usuario'),
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
                  value:
                      metrics['plagaMasFrecuente']?.toString() ?? 'Sin datos',
                ),
                _metricCard(
                  context: context,
                  icon: Icons.landscape_outlined,
                  title: 'Parcela con más incidencias',
                  value:
                      metrics['parcelaMasAfectada']?.toString() ?? 'Sin datos',
                ),
                _metricCard(
                  context: context,
                  icon: Icons.cloud_upload_outlined,
                  title: 'Pendientes de sincronización',
                  value: pendientes.toString(),
                ),
                _metricCard(
                  context: context,
                  icon: Icons.cloud_sync_outlined,
                  title: 'En proceso de sincronización',
                  value: sincronizando.toString(),
                ),
                _metricCard(
                  context: context,
                  icon: Icons.error_outline,
                  title: 'Errores de sincronización',
                  value: errores.toString(),
                ),
                _metricCard(
                  context: context,
                  icon: Icons.cloud_done_outlined,
                  title: 'Registros sincronizados',
                  value: sincronizadas.toString(),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _isSyncing ? null : _syncNow,
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded),
                  label: Text(
                      _isSyncing ? 'Sincronizando...' : 'Sincronizar Datos'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Cerrar sesión'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
