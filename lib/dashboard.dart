import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'absences_screen.dart';
import 'classes_screen.dart';
import 'etudiants_screen.dart';
import 'matieres_screen.dart';
import 'login.dart';
import 'moyennes_screen.dart';
import 'top_absences_screen.dart';

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

  void _go(BuildContext context, Widget page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Voulez-vous vous déconnecter ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Logout')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const Login()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8A5DD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE8A5DD),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.purple,
              padding: const EdgeInsets.fromLTRB(16, 60, 16, 20),
              child: const Text(
                "Exercise for groups :\nDSI33 and DSI31",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            ListTile(
              title: const Text("Moyennes"),
              onTap: () => _go(context, const MoyennesScreen()),
            ),
            ListTile(
              title: const Text("Top 3 Absences"),
              onTap: () => _go(context, const TopAbsencesScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.groups, color: Colors.deepOrange),
              title: const Text("Manage groups"),
              onTap: () => _go(context, const ClassesScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.school, color: Colors.deepOrange),
              title: const Text("Manage students"),
              onTap: () => _go(context, const EtudiantsScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.event_busy, color: Colors.deepOrange),
              title: const Text("Manage absences"),
              onTap: () => _go(context, const AbsencesScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.menu_book, color: Colors.deepOrange),
              title: const Text("Manage subjects"),
              onTap: () => _go(context, const MatieresScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.person, color: Colors.deepOrange),
              title: const Text("Manage teachers"),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Not implemented yet')),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.deepOrange),
              title: const Text("Logout"),
              onTap: () {
                Navigator.pop(context);
                _logout(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.deepOrange),
              title: const Text("Close"),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Text(
            "Dashboard",
            style: GoogleFonts.pacifico(fontSize: 40, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
