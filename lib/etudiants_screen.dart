import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'classes_screen.dart';
import 'config.dart';

class Etudiant {
  final int id;
  final String nom;
  final String prenom;
  final int? codClasse;
  // JSON d'origine, conservé pour ne pas perdre les autres champs lors d'une mise à jour
  final Map<String, dynamic> raw;

  Etudiant(this.id, this.nom, this.prenom, this.codClasse, [this.raw = const {}]);

  factory Etudiant.fromMap(Map<String, dynamic> m) {
    final classe = m['classe'];
    return Etudiant(
      m['id'],
      m['nom'] ?? '',
      m['prenom'] ?? '',
      classe is Map ? classe['codClass'] : null,
      m,
    );
  }
}

const _jsonHeaders = {'Content-Type': 'application/json'};

bool _ok(int code) => code == 200 || code == 201 || code == 204;

Future<void> createEtudiant(String nom, String prenom, int codClass) async {
  final res = await http.post(
    Uri.parse('$baseUrl/etudiants'),
    headers: _jsonHeaders,
    body: jsonEncode({
      'nom': nom,
      'prenom': prenom,
      'classe': {'codClass': codClass},
    }),
  );
  if (!_ok(res.statusCode)) {
    throw Exception('Failed to add student (HTTP ${res.statusCode})');
  }
}

Future<void> updateEtudiant(Etudiant e, String nom, String prenom, int codClass) async {
  final body = Map<String, dynamic>.from(e.raw)
    ..remove('_links')
    ..['id'] = e.id
    ..['nom'] = nom
    ..['prenom'] = prenom
    ..['classe'] = {'codClass': codClass};
  final res = await http.put(
    Uri.parse('$baseUrl/etudiants/${e.id}'),
    headers: _jsonHeaders,
    body: jsonEncode(body),
  );
  if (!_ok(res.statusCode)) {
    throw Exception('Failed to update student (HTTP ${res.statusCode})');
  }
}

Future<void> deleteEtudiant(int id) async {
  final res = await http.delete(Uri.parse('$baseUrl/etudiants/$id'));
  if (!_ok(res.statusCode)) {
    throw Exception('Failed to delete student (HTTP ${res.statusCode})');
  }
}

class EtudiantsScreen extends StatefulWidget {
  const EtudiantsScreen({super.key});

  @override
  State<EtudiantsScreen> createState() => _EtudiantsScreenState();
}

class _EtudiantsScreenState extends State<EtudiantsScreen> {
  List<Classe> _classes = [];
  Classe? _selected;
  List<Etudiant> _tous = [];
  bool _loading = true;
  String? _error;

  List<Etudiant> get _affiches => _selected == null
      ? []
      : _tous.where((e) => e.codClasse == _selected!.codClass).toList();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final classes = await fetchClasses();
      final etudiants = await _fetchEtudiants();
      if (!mounted) return;
      setState(() {
        _classes = classes;
        _selected = classes.isNotEmpty ? classes.first : null;
        _tous = etudiants;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _reload() async {
    try {
      final etudiants = await _fetchEtudiants();
      if (!mounted) return;
      setState(() => _tous = etudiants);
    } catch (e) {
      _showError(e);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
    );
  }

  Future<List<Etudiant>> _fetchEtudiants() async {
    final res = await http.get(Uri.parse('$baseUrl/etudiants'));
    if (res.statusCode != 200) {
      throw Exception('Failed to load students (HTTP ${res.statusCode})');
    }
    final decoded = jsonDecode(res.body);
    // Accepte un tableau simple ou le format HAL de Spring Data REST
    final List data = decoded is List
        ? decoded
        : (decoded['_embedded']?['etudiants'] ?? []);
    if (data.isNotEmpty && data.first is Map && !(data.first as Map).containsKey('classe')) {
      throw Exception(
          'Le JSON des étudiants ne contient pas le champ "classe". Vérifie @JsonIgnore côté Spring.');
    }
    return data.map((e) => Etudiant.fromMap(e)).toList();
  }

  Future<void> _openForm([Etudiant? etudiant]) async {
    final nomCtrl = TextEditingController(text: etudiant?.nom ?? '');
    final prenomCtrl = TextEditingController(text: etudiant?.prenom ?? '');
    final formKey = GlobalKey<FormState>();
    Classe? classe = etudiant == null
        ? _selected
        : _classes.where((c) => c.codClass == etudiant.codClasse).firstOrNull ?? _selected;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(etudiant == null ? 'Ajouter un étudiant' : 'Modifier l\'étudiant'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nomCtrl,
                    decoration: const InputDecoration(labelText: 'Nom'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom obligatoire' : null,
                  ),
                  TextFormField(
                    controller: prenomCtrl,
                    decoration: const InputDecoration(labelText: 'Prénom'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Prénom obligatoire' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Classe>(
                    initialValue: classe,
                    decoration: const InputDecoration(labelText: 'Classe'),
                    items: _classes
                        .map((c) => DropdownMenuItem<Classe>(value: c, child: Text(c.nomClass)))
                        .toList(),
                    onChanged: (c) => setDialogState(() => classe = c),
                    validator: (c) => c == null ? 'Classe obligatoire' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) Navigator.pop(ctx, true);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    try {
      final nom = nomCtrl.text.trim();
      final prenom = prenomCtrl.text.trim();
      if (etudiant == null) {
        await createEtudiant(nom, prenom, classe!.codClass);
      } else {
        await updateEtudiant(etudiant, nom, prenom, classe!.codClass);
      }
      if (!mounted) return;
      setState(() => _selected = classe);
      await _reload();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _confirmDelete(Etudiant e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text('Supprimer ${e.nom} ${e.prenom} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await deleteEtudiant(e.id);
      await _reload();
    } catch (err) {
      _showError(err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final etudiants = _affiches;
    return Scaffold(
      appBar: AppBar(title: const Text('Manage students')),
      floatingActionButton: _loading || _error != null
          ? null
          : FloatingActionButton(
              onPressed: () => _openForm(),
              child: const Icon(Icons.add),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Erreur : $_error'))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Text('Classe : ',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 12),
                          DropdownButton<Classe>(
                            value: _selected,
                            hint: const Text('Code Classe'),
                            items: _classes
                                .map((c) => DropdownMenuItem<Classe>(
                                      value: c,
                                      child: Text(c.nomClass),
                                    ))
                                .toList(),
                            onChanged: (c) {
                              if (c == null) return;
                              setState(() => _selected = c);
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: etudiants.isEmpty
                          ? const Center(child: Text('Aucun étudiant'))
                          : RefreshIndicator(
                              onRefresh: _reload,
                              child: ListView.builder(
                                itemCount: etudiants.length,
                                itemBuilder: (context, i) => ListTile(
                                  leading: const Icon(Icons.school),
                                  title: Text('${etudiants[i].nom} ${etudiants[i].prenom}'),
                                  onTap: () => _openForm(etudiants[i]),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue),
                                        tooltip: 'Modifier',
                                        onPressed: () => _openForm(etudiants[i]),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        tooltip: 'Supprimer',
                                        onPressed: () => _confirmDelete(etudiants[i]),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }
}
