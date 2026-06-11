import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/auth/application/auth_model.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const _WebHomePage(),
      const _InfoPage(
        icon: Icons.self_improvement,
        title: 'Zen room loads on app',
        message: 'Heavy 3D and media resources are not part of the Flutter Web first screen.',
      ),
      const _WebProfilePage(),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B1026), Color(0xFF09070B)],
          ),
        ),
        child: SafeArea(child: pages[_index]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        height: 68,
        backgroundColor: const Color(0xF20D1018),
        indicatorColor: const Color(0x33667EEA),
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.public_outlined),
            selectedIcon: Icon(Icons.public),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.self_improvement_outlined),
            selectedIcon: Icon(Icons.self_improvement),
            label: 'Zen',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Me',
          ),
        ],
      ),
    );
  }
}

class _WebHomePage extends StatelessWidget {
  const _WebHomePage();

  @override
  Widget build(BuildContext context) {
    final authModel = context.watch<AuthModel?>();
    final displayName = authModel?.currentUser?.displayName.trim();
    final name = displayName == null || displayName.isEmpty ? 'Friend' : displayName;
    final initial = name.isEmpty ? 'F' : name.substring(0, 1);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hi, $name',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Share good resources around the world',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0x33667EEA),
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 34),
        const _CardLine(
          icon: Icons.flash_on,
          title: 'Fast Web first screen',
          text: 'The Web entry keeps only the landing UI and account restore path before first paint.',
        ),
        const SizedBox(height: 14),
        const _CardLine(
          icon: Icons.cloud_done_outlined,
          title: 'Deferred heavy services',
          text: 'Firebase, video feed, update checks, 3D and media resources start after the first frame or on app platforms.',
        ),
        const SizedBox(height: 14),
        const _CardLine(
          icon: Icons.privacy_tip_outlined,
          title: 'No Web first-screen dialog',
          text: 'The app platforms keep their agreement flow. Web does not block the first screen with it.',
        ),
      ],
    );
  }
}

class _CardLine extends StatelessWidget {
  const _CardLine({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: const TextStyle(color: Colors.white70, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPage extends StatelessWidget {
  const _InfoPage({required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 58, color: Colors.white70),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _WebProfilePage extends StatelessWidget {
  const _WebProfilePage();

  @override
  Widget build(BuildContext context) {
    final authModel = context.watch<AuthModel?>();
    final user = authModel?.currentUser;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person, color: Colors.white70, size: 58),
            const SizedBox(height: 18),
            Text(
              user == null ? 'Not signed in' : user.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              user == null ? 'Sign-in code is not preloaded for the first screen.' : 'Account state restored after first paint.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, height: 1.5),
            ),
            if (user == null) ...[
              const SizedBox(height: 22),
              FilledButton(
                onPressed: () => Navigator.of(context).pushNamed('/login'),
                child: const Text('Sign in'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
