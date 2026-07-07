import 'package:flutter/material.dart';

import '../detection/capture_screen.dart';
import '../history/history_screen.dart';
import '../crops/crops_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.user,
  });

  final Map<String, dynamic> user;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Map<String, dynamic> _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = Map<String, dynamic>.from(widget.user);
  }

  String get _currentUserId => _currentUser['id']?.toString() ?? '';

  String _getDynamicGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Buenos días';
    } else if (hour < 18) {
      return 'Buenas tardes';
    } else {
      return 'Buenas noches';
    }
  }

  Widget _buildMenuCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? description,
  }) {
    const primaryGreen = Color(0xFF2E7D32);
    const darkGreen = Color(0xFF1B5E20);
    const textPrimary = Color(0xFF1F2933);
    const textSecondary = Color(0xFF6B7280);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
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
              Row(
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
                      size: 25,
                      color: primaryGreen,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6FAF6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: darkGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: textPrimary,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      letterSpacing: 0,
                    ),
              ),
              if (description != null) ...[
                const SizedBox(height: 8),
                Text(
                  description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: textSecondary,
                        height: 1.35,
                        letterSpacing: 0,
                      ),
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
    final theme = Theme.of(context);
    const primaryGreen = Color(0xFF2E7D32);
    const darkGreen = Color(0xFF1B5E20);
    const lightGreen = Color(0xFFE8F5E9);
    const backgroundColor = Color(0xFFF6FAF6);
    const textPrimary = Color(0xFF1F2933);
    const textSecondary = Color(0xFF6B7280);
    final userName =
        _currentUser['nombre']?.toString().trim().isNotEmpty == true
            ? _currentUser['nombre'].toString()
            : 'Agricultor';

    return Scaffold(
      backgroundColor: backgroundColor,
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 380;
              final crossAxisCount = constraints.maxWidth >= 620 ? 3 : 2;
              final childAspectRatio = isCompact ? 0.72 : 0.78;

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  isCompact ? 18 : 24,
                  24,
                  isCompact ? 18 : 24,
                  28,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 58,
                                height: 58,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(19),
                                  boxShadow: [
                                    BoxShadow(
                                      color: darkGreen.withOpacity(0.10),
                                      blurRadius: 18,
                                      offset: const Offset(0, 9),
                                    ),
                                  ],
                                ),
                                child: Image.asset(
                                  'assets/icons/logo_login.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'RiceGuard',
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                        color: textPrimary,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Monitoreo inteligente de cultivos de arroz',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
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
                        ),
                        const SizedBox(height: 22),
                        Text(
                          '${_getDynamicGreeting()},',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: textSecondary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hola, $userName',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: textPrimary,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: darkGreen,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: darkGreen.withOpacity(0.16),
                                blurRadius: 26,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(17),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_outlined,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Analiza una imagen de arroz',
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      'Detecta señales de plagas y enfermedades con visión artificial.',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: Colors.white.withOpacity(0.82),
                                        height: 1.35,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 26),
                        Row(
                          children: [
                            Text(
                              'Funciones principales',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: textPrimary,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: lightGreen,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '4 opciones',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: darkGreen,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        GridView.count(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: childAspectRatio,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildMenuCard(
                              context: context,
                              icon: Icons.camera_alt_outlined,
                              title: 'Detectar plagas',
                              description:
                                  'Captura o selecciona una imagen para analizar el cultivo.',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CaptureScreen(
                                      userId: _currentUserId,
                                    ),
                                  ),
                                );
                              },
                            ),
                            _buildMenuCard(
                              context: context,
                              icon: Icons.bar_chart_rounded,
                              title: 'Historial',
                              description:
                                  'Consulta tus detecciones y resultados anteriores.',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => HistoryScreen(
                                      userId: _currentUserId,
                                    ),
                                  ),
                                );
                              },
                            ),
                            _buildMenuCard(
                              context: context,
                              icon: Icons.person_outline_rounded,
                              title: 'Perfil de usuario',
                              description:
                                  'Revisa la información de tu cuenta RiceGuard.',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ProfileScreen(user: _currentUser),
                                  ),
                                );
                              },
                            ),
                            _buildMenuCard(
                              context: context,
                              icon: Icons.agriculture_outlined,
                              title: 'Mis parcelas',
                              description:
                                  'Organiza y monitorea tus zonas de cultivo.',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CropsScreen(
                                      userId: _currentUserId,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
