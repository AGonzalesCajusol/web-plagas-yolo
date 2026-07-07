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
            'Subidas: ${result.synced}/${result.total}. '
            'Descargadas nuevas: ${result.downloaded}. '
            'Encontradas en nube: ${result.remoteTotal}. '
            'Errores: ${result.failed}.',
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
    const primaryGreen = Color(0xFF2E7D32);
    const darkGreen = Color(0xFF1B5E20);
    const textPrimary = Color(0xFF1F2933);
    const textSecondary = Color(0xFF6B7280);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: primaryGreen.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: darkGreen.withOpacity(0.06),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              icon,
              size: 24,
              color: primaryGreen,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.bodySmall?.copyWith(
                    color: textSecondary,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    color: textPrimary,
                    fontWeight: FontWeight.w900,
                    height: 1.18,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
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

  Widget _buildHeader(BuildContext context) {
    const primaryGreen = Color(0xFF2E7D32);
    const darkGreen = Color(0xFF1B5E20);
    const textPrimary = Color(0xFF1F2933);
    const textSecondary = Color(0xFF6B7280);

    return Container(
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
              Icons.person_outline,
              color: primaryGreen,
              size: 31,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Perfil',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: textPrimary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Administra tu información de usuario',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: textSecondary,
                        height: 1.35,
                        letterSpacing: 0,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard({
    required BuildContext context,
    required String userName,
    required String userEmail,
    required String userRole,
  }) {
    const primaryGreen = Color(0xFF2E7D32);
    const darkGreen = Color(0xFF1B5E20);
    const textPrimary = Color(0xFF1F2933);
    const textSecondary = Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
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
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: darkGreen,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: darkGreen.withOpacity(0.16),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const Icon(
              Icons.person_outline,
              color: Colors.white,
              size: 46,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            userName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: textPrimary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            userEmail,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: textSecondary,
                  height: 1.35,
                  letterSpacing: 0,
                ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              userRole,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: darkGreen,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
  }) {
    const primaryGreen = Color(0xFF2E7D32);
    const textPrimary = Color(0xFF1F2933);
    const textSecondary = Color(0xFF6B7280);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: primaryGreen,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: textSecondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: textPrimary,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      letterSpacing: 0,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection({
    required BuildContext context,
    required String userName,
    required String userEmail,
    required String userRole,
  }) {
    const primaryGreen = Color(0xFF2E7D32);
    const darkGreen = Color(0xFF1B5E20);
    const textPrimary = Color(0xFF1F2933);

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Información personal',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: textPrimary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
          ),
          const SizedBox(height: 16),
          _infoRow(
            context: context,
            icon: Icons.person_outline,
            label: 'Nombre',
            value: userName,
          ),
          const SizedBox(height: 14),
          _infoRow(
            context: context,
            icon: Icons.email_outlined,
            label: 'Correo',
            value: userEmail,
          ),
          const SizedBox(height: 14),
          _infoRow(
            context: context,
            icon: Icons.badge_outlined,
            label: 'Rol',
            value: userRole,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onPressed,
    bool danger = false,
    Widget? trailing,
  }) {
    const primaryGreen = Color(0xFF2E7D32);
    const darkGreen = Color(0xFF1B5E20);
    const dangerRed = Color(0xFFC62828);
    const dangerBackground = Color(0xFFFFEBEE);
    const textPrimary = Color(0xFF1F2933);
    const textSecondary = Color(0xFF6B7280);
    final color = danger ? dangerRed : primaryGreen;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: (danger ? dangerRed : primaryGreen).withOpacity(0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: (danger ? dangerRed : darkGreen).withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: danger ? dangerBackground : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 23,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: danger ? dangerRed : textPrimary,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: textSecondary,
                            height: 1.35,
                            letterSpacing: 0,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ??
                  Icon(
                    Icons.chevron_right,
                    color: danger ? dangerRed : darkGreen,
                  ),
            ],
          ),
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
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const darkGreen = Color(0xFF1B5E20);
    const lightGreen = Color(0xFFE8F5E9);
    const backgroundColor = Color(0xFFF6FAF6);

    final userName =
        _currentUser['nombre']?.toString().trim().isNotEmpty == true
            ? _currentUser['nombre'].toString()
            : 'Agricultor Local';

    final userEmail = _currentUser['email']?.toString() ?? 'Sin correo';
    final userRole = _currentUser['rol']?.toString() ?? 'AGRICULTOR';

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Perfil'),
        centerTitle: true,
        backgroundColor: lightGreen,
        elevation: 0,
        foregroundColor: darkGreen,
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
          child: RefreshIndicator(
            onRefresh: _reloadMetrics,
            child: FutureBuilder<Map<String, dynamic>>(
              future: _metricsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                    children: [
                      _buildHeader(context),
                      const SizedBox(height: 18),
                      _buildStateCard(
                        context: context,
                        icon: Icons.person_outline,
                        title: 'Cargando perfil',
                        subtitle:
                            'Estamos preparando tu información y métricas locales.',
                        showProgress: true,
                      ),
                    ],
                  );
                }

                if (snapshot.hasError) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                    children: [
                      _buildHeader(context),
                      const SizedBox(height: 18),
                      _buildStateCard(
                        context: context,
                        icon: Icons.error_outline,
                        title: 'No se pudieron cargar las métricas locales',
                        subtitle:
                            'Desliza hacia abajo para intentar actualizar nuevamente.',
                        iconColor: Theme.of(context).colorScheme.error,
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
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeader(context),
                            const SizedBox(height: 18),
                            _buildProfileCard(
                              context: context,
                              userName: userName,
                              userEmail: userEmail,
                              userRole: userRole,
                            ),
                            const SizedBox(height: 18),
                            _buildInfoSection(
                              context: context,
                              userName: userName,
                              userEmail: userEmail,
                              userRole: userRole,
                            ),
                            const SizedBox(height: 18),
                            _buildActionTile(
                              context: context,
                              icon: Icons.edit_outlined,
                              title: 'Editar datos del usuario',
                              subtitle:
                                  'Actualiza tu información personal de RiceGuard.',
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
                            ),
                            const SizedBox(height: 22),
                            Text(
                              'Métricas locales',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: const Color(0xFF1F2933),
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            _metricCard(
                              context: context,
                              icon: Icons.analytics_outlined,
                              title: 'Total de plagas detectadas',
                              value: totalDetecciones.toString(),
                            ),
                            const SizedBox(height: 12),
                            _metricCard(
                              context: context,
                              icon: Icons.bug_report_outlined,
                              title: 'Plaga más frecuente',
                              value: metrics['plagaMasFrecuente']?.toString() ??
                                  'Sin datos',
                            ),
                            const SizedBox(height: 12),
                            _metricCard(
                              context: context,
                              icon: Icons.landscape_outlined,
                              title: 'Parcela con más incidencias',
                              value:
                                  metrics['parcelaMasAfectada']?.toString() ??
                                      'Sin datos',
                            ),
                            const SizedBox(height: 22),
                            Text(
                              'Sincronización',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: const Color(0xFF1F2933),
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            _metricCard(
                              context: context,
                              icon: Icons.cloud_upload_outlined,
                              title: 'Pendientes de sincronización',
                              value: pendientes.toString(),
                            ),
                            const SizedBox(height: 12),
                            _metricCard(
                              context: context,
                              icon: Icons.cloud_sync_outlined,
                              title: 'En proceso de sincronización',
                              value: sincronizando.toString(),
                            ),
                            const SizedBox(height: 12),
                            _metricCard(
                              context: context,
                              icon: Icons.error_outline,
                              title: 'Errores de sincronización',
                              value: errores.toString(),
                            ),
                            const SizedBox(height: 12),
                            _metricCard(
                              context: context,
                              icon: Icons.cloud_done_outlined,
                              title: 'Registros sincronizados',
                              value: sincronizadas.toString(),
                            ),
                            const SizedBox(height: 18),
                            _buildActionTile(
                              context: context,
                              icon: Icons.sync_rounded,
                              title: _isSyncing
                                  ? 'Sincronizando...'
                                  : 'Sincronizar datos',
                              subtitle:
                                  'Envía detecciones pendientes y actualiza información local.',
                              onPressed: _isSyncing ? null : _syncNow,
                              trailing: _isSyncing
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 22),
                            Text(
                              'Sesión',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: const Color(0xFF1F2933),
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            _buildActionTile(
                              context: context,
                              icon: Icons.logout_rounded,
                              title: 'Cerrar sesión',
                              subtitle:
                                  'Sal de tu cuenta y vuelve a la pantalla de inicio.',
                              onPressed: _logout,
                              danger: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
