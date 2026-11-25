import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

class Classe {
  final int codClass;
  final String nomClass;
  final int? codDept;
  final String? nomDept;

  Classe(this.codClass, this.nomClass, {this.codDept, this.nomDept});

  factory Classe.fromMap(Map<String, dynamic> m) {
    final departement = m['departement'];
    return Classe(
      (m['codClass'] as num).toInt(),
      m['nomClass'] as String? ?? '',
      codDept: departement is Map ? (departement['codDept'] as num?)?.toInt() : null,
      nomDept: departement is Map ? departement['nomDept'] as String? : null,
    );
  }

  // Nécessaire pour que le DropdownButton retrouve la classe sélectionnée
  @override
  bool operator ==(Object other) =>
      other is Classe && other.codClass == codClass;

  @override
  int get hashCode => codClass.hashCode;
}

Future<List<Classe>> fetchClasses() async {
  // L'URL qui répond dans le navigateur est /classes (et non /api/classes)
  final res = await http.get(Uri.parse('$baseUrl/classes'));
  if (res.statusCode != 200) {
    throw Exception('Failed to load classes (HTTP ${res.statusCode})');
  }
  final List data = jsonDecode(res.body);
  return data.map((e) => Classe.fromMap(e)).toList();
}

class ClassesScreen extends StatelessWidget {
  const ClassesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage groups')),
      body: FutureBuilder<List<Classe>>(
        future: fetchClasses(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Erreur : ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final classes = snap.data!;
          return ListView.builder(
            itemCount: classes.length,
            itemBuilder: (context, i) => ListTile(
              leading: const Icon(Icons.groups),
              title: Text(classes[i].nomClass),
              subtitle: Text('Code : ${classes[i].codClass}'),
            ),
          );
        },
      ),
    );
  }
}
