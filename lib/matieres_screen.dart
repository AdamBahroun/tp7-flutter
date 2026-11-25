import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config.dart';

class _Matiere {
  final String codMat;
  final String intMat;
  final String description;
  final String typeMat;

  const _Matiere({
    required this.codMat,
    required this.intMat,
    required this.description,
    required this.typeMat,
  });

  factory _Matiere.fromMap(Map<String, dynamic> map) => _Matiere(
    codMat: map['codMat']?.toString() ?? '',
    intMat: map['intMat'] as String? ?? '',
    description: map['description'] as String? ?? '',
    typeMat: map['typeMat']?.toString().trim().toUpperCase() == 'TP'
        ? 'TP'
        : 'COURS',
  );
}

class _MatiereDraft {
  final String codMat;
  final String intMat;
  final String description;
  final String typeMat;

  const _MatiereDraft(this.codMat, this.intMat, this.description, this.typeMat);
}

class MatieresScreen extends StatefulWidget {
  const MatieresScreen({super.key});

  @override
  State<MatieresScreen> createState() => _MatieresScreenState();
}

class _MatieresScreenState extends State<MatieresScreen> {
  List<_Matiere> _matieres = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMatieres();
  }

  Future<void> _loadMatieres() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await http.get(Uri.parse('$baseUrl/matieres'));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final data = jsonDecode(response.body) as List;
      final matieres = data
          .map((item) => _Matiere.fromMap(item as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() => _matieres = matieres);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Impossible de charger les matières : $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _editMatiere([_Matiere? matiere]) async {
    final formKey = GlobalKey<FormState>();
    final codMatController = TextEditingController(text: matiere?.codMat ?? '');
    final intMatController = TextEditingController(text: matiere?.intMat ?? '');
    final descriptionController = TextEditingController(
      text: matiere?.description ?? '',
    );
    var typeMat = matiere?.typeMat ?? 'COURS';

    final draft = await showDialog<_MatiereDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(
            matiere == null ? 'Ajouter une matière' : 'Modifier la matière',
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: codMatController,
                    enabled: matiere == null,
                    decoration: const InputDecoration(
                      labelText: 'Code matière',
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Champ obligatoire'
                        : null,
                  ),
                  TextFormField(
                    controller: intMatController,
                    decoration: const InputDecoration(labelText: 'Intitulé'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Champ obligatoire'
                        : null,
                  ),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    minLines: 1,
                    maxLines: 3,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: typeMat,
                    decoration: const InputDecoration(
                      labelText: 'Type de matière',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'COURS', child: Text('Cours')),
                      DropdownMenuItem(value: 'TP', child: Text('TP')),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => typeMat = value);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final code = codMatController.text.trim();
                final duplicate =
                    matiere == null &&
                    _matieres.any((item) => item.codMat == code);
                if (duplicate) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Ce code matière existe déjà.'),
                    ),
                  );
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  _MatiereDraft(
                    code,
                    intMatController.text.trim(),
                    descriptionController.text.trim(),
                    typeMat,
                  ),
                );
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );

    codMatController.dispose();
    intMatController.dispose();
    descriptionController.dispose();
    if (draft == null || !mounted) return;

    try {
      final editing = matiere != null;
      final uri = Uri.parse(
        '$baseUrl/matieres/${Uri.encodeComponent(draft.codMat)}',
      );
      final response = editing
          ? await http.put(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'codMat': draft.codMat,
                'intMat': draft.intMat,
                'description': draft.description,
                'typeMat': draft.typeMat,
              }),
            )
          : await http.post(
              Uri.parse('$baseUrl/matieres'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'codMat': draft.codMat,
                'intMat': draft.intMat,
                'description': draft.description,
                'typeMat': draft.typeMat,
              }),
            );
      if (response.statusCode != 200 &&
          response.statusCode != 201 &&
          response.statusCode != 204) {
        throw Exception('HTTP ${response.statusCode}');
      }
      _showMessage(editing ? 'Matière modifiée.' : 'Matière ajoutée.');
      await _loadMatieres();
    } catch (error) {
      _showMessage('Échec de l’enregistrement : $error');
    }
  }

  Future<void> _deleteMatiere(_Matiere matiere) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer la matière ?'),
        content: Text(
          'Voulez-vous supprimer ${matiere.codMat} — ${matiere.intMat} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/matieres/${Uri.encodeComponent(matiere.codMat)}'),
      );
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('HTTP ${response.statusCode}');
      }
      _showMessage('Matière supprimée.');
      await _loadMatieres();
    } catch (error) {
      _showMessage(
        'Impossible de supprimer cette matière. Elle est peut-être liée à des absences. ($error)',
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage subjects'),
        actions: [
          IconButton(
            onPressed: _loadMatieres,
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading && _matieres.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMatieres,
              child: _error != null && _matieres.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: 240,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(_error!, textAlign: TextAlign.center),
                            ),
                          ),
                        ),
                      ],
                    )
                  : _matieres.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(
                          height: 240,
                          child: Center(
                            child: Text('Aucune matière enregistrée.'),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _matieres.length,
                      itemBuilder: (context, index) {
                        final matiere = _matieres[index];
                        return ListTile(
                          leading: const Icon(Icons.menu_book),
                          title: Text('${matiere.codMat} — ${matiere.intMat}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Type : ${matiere.typeMat == 'TP' ? 'TP' : 'Cours'}',
                              ),
                              if (matiere.description.isNotEmpty)
                                Text(matiere.description),
                            ],
                          ),
                          isThreeLine: matiere.description.length > 50,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Modifier',
                                icon: const Icon(Icons.edit),
                                onPressed: () => _editMatiere(matiere),
                              ),
                              IconButton(
                                tooltip: 'Supprimer',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deleteMatiere(matiere),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editMatiere(),
        tooltip: 'Ajouter une matière',
        child: const Icon(Icons.add),
      ),
    );
  }
}
