import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'classes_screen.dart';
import 'config.dart';
import 'etudiants_screen.dart';
import 'total_absences_screen.dart';

class _Departement {
  final int codDept;
  final String nomDept;

  const _Departement(this.codDept, this.nomDept);

  factory _Departement.fromMap(Map<String, dynamic> map) => _Departement(
    (map['codDept'] as num).toInt(),
    map['nomDept'] as String? ?? '',
  );
}

class _Matiere {
  final String codMat;
  final String intMat;
  final String typeMat;

  const _Matiere(this.codMat, this.intMat, this.typeMat);

  factory _Matiere.fromMap(Map<String, dynamic> map) => _Matiere(
    map['codMat'].toString(),
    map['intMat'] as String? ?? '',
    map['typeMat']?.toString().trim().toUpperCase() == 'TP' ? 'TP' : 'COURS',
  );
}

class _Absence {
  final int id;
  final _Matiere matiere;
  final DateTime dateA;
  final double nha;
  final String typeSeance;

  const _Absence(this.id, this.matiere, this.dateA, this.nha, this.typeSeance);

  factory _Absence.fromMap(Map<String, dynamic> map) {
    final matiere = Map<String, dynamic>.from(map['matiere'] as Map);
    final typeSeance = map['typeSeance']?.toString().trim().toUpperCase();
    return _Absence(
      (map['id'] as num).toInt(),
      _Matiere.fromMap(matiere),
      DateTime.parse(map['dateA'].toString()),
      (map['nha'] as num).toDouble(),
      typeSeance == 'TP' ? 'TP' : 'COURS',
    );
  }
}

class AbsencesScreen extends StatefulWidget {
  const AbsencesScreen({super.key});

  @override
  State<AbsencesScreen> createState() => _AbsencesScreenState();
}

class _AbsencesScreenState extends State<AbsencesScreen> {
  List<_Departement> _departements = [];
  List<Classe> _classes = [];
  List<Etudiant> _etudiants = [];
  List<_Matiere> _matieres = [];
  List<_Absence> _absences = [];
  _Departement? _selectedDepartment;
  Classe? _selectedClasse;
  Etudiant? _selectedEtudiant;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<List<dynamic>> _getList(String path) async {
    final response = await http.get(Uri.parse('$baseUrl$path'));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode} sur $path');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('Réponse serveur invalide');
    }
    return decoded;
  }

  Future<void> _loadInitialData() async {
    try {
      final results = await Future.wait([
        _getList('/departements'),
        _getList('/matieres'),
      ]);
      if (!mounted) return;
      setState(() {
        _departements = results[0]
            .map(
              (item) =>
                  _Departement.fromMap(Map<String, dynamic>.from(item as Map)),
            )
            .toList();
        _matieres = results[1]
            .map(
              (item) =>
                  _Matiere.fromMap(Map<String, dynamic>.from(item as Map)),
            )
            .toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _selectDepartment(_Departement? department) async {
    setState(() {
      _selectedDepartment = department;
      _selectedClasse = null;
      _selectedEtudiant = null;
      _classes = [];
      _etudiants = [];
      _absences = [];
    });
    if (department == null) return;
    try {
      final data = await _getList('/classes/departement/${department.codDept}');
      if (!mounted) return;
      setState(() {
        _classes = data
            .map(
              (item) => Classe.fromMap(Map<String, dynamic>.from(item as Map)),
            )
            .toList();
      });
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _selectClasse(Classe? classe) async {
    setState(() {
      _selectedClasse = classe;
      _selectedEtudiant = null;
      _etudiants = [];
      _absences = [];
    });
    if (classe == null) return;
    try {
      final data = await _getList('/etudiants/classe/${classe.codClass}');
      if (!mounted) return;
      setState(() {
        _etudiants = data
            .map(
              (item) =>
                  Etudiant.fromMap(Map<String, dynamic>.from(item as Map)),
            )
            .toList();
      });
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _selectEtudiant(Etudiant? etudiant) async {
    setState(() {
      _selectedEtudiant = etudiant;
      _absences = [];
    });
    if (etudiant != null) await _reloadAbsences();
  }

  Future<void> _reloadAbsences() async {
    final etudiant = _selectedEtudiant;
    if (etudiant == null) return;
    try {
      final data = await _getList('/absences/etudiant/${etudiant.id}');
      if (!mounted) return;
      setState(() {
        _absences = data
            .map(
              (item) =>
                  _Absence.fromMap(Map<String, dynamic>.from(item as Map)),
            )
            .toList();
      });
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erreur : $error'), backgroundColor: Colors.red),
    );
  }

  Future<void> _openAbsenceForm([_Absence? absence]) async {
    final etudiant = _selectedEtudiant;
    if (etudiant == null) {
      _showError('Sélectionnez d’abord un étudiant.');
      return;
    }
    final formKey = GlobalKey<FormState>();
    final nhaController = TextEditingController(
      text: absence == null ? '' : _formatHours(absence.nha),
    );
    final today = DateUtils.dateOnly(DateTime.now());
    var dateA = absence?.dateA ?? today;
    if (dateA.isAfter(today)) dateA = today;
    _Matiere? matiere = absence == null
        ? (_matieres.isEmpty ? null : _matieres.first)
        : _matieres
              .where((item) => item.codMat == absence.matiere.codMat)
              .firstOrNull;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(
            absence == null ? 'Ajouter une absence' : 'Modifier une absence',
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date'),
                    subtitle: Text(_formatDate(dateA)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final selected = await showDatePicker(
                        context: dialogContext,
                        initialDate: dateA.isAfter(today) ? today : dateA,
                        firstDate: DateTime(1900),
                        lastDate: today,
                      );
                      if (selected != null) {
                        setDialogState(() => dateA = selected);
                      }
                    },
                  ),
                  DropdownButtonFormField<_Matiere>(
                    initialValue: matiere,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Matière'),
                    items: _matieres
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(
                              '${item.codMat} — ${item.intMat}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setDialogState(() => matiere = value),
                    validator: (value) =>
                        value == null ? 'Matière obligatoire' : null,
                  ),
                  TextFormField(
                    controller: nhaController,
                    decoration: InputDecoration(
                      labelText: 'Nombre d’heures (NHA)',
                      helperText: matiere?.typeMat == 'TP'
                          ? 'TP : max. 3 h'
                          : 'Cours : max. 1,5 h',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      final parsed = double.tryParse(
                        (value ?? '').replaceAll(',', '.'),
                      );
                      if (parsed == null || !parsed.isFinite || parsed <= 0) {
                        return 'Saisissez un nombre positif';
                      }
                      final maxHours = matiere?.typeMat == 'TP' ? 3.0 : 1.5;
                      if (parsed > maxHours) {
                        return matiere?.typeMat == 'TP'
                            ? 'Un TP ne peut pas dépasser 3 h'
                            : 'Un cours ne peut pas dépasser 1,5 h';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || matiere == null) return;
    try {
      final nha = double.parse(nhaController.text.replaceAll(',', '.'));
      final body = jsonEncode({
        'id': absence?.id,
        'dateA': dateA.toIso8601String().split('T').first,
        'nha': nha,
        'typeSeance': matiere!.typeMat,
        'matiere': {'codMat': matiere!.codMat},
        'etudiant': {'id': etudiant.id},
      });
      final response = absence == null
          ? await http.post(
              Uri.parse('$baseUrl/absences'),
              headers: const {'Content-Type': 'application/json'},
              body: body,
            )
          : await http.put(
              Uri.parse('$baseUrl/absences/${absence.id}'),
              headers: const {'Content-Type': 'application/json'},
              body: body,
            );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}');
      }
      await _reloadAbsences();
    } catch (error) {
      _showError(error);
    } finally {
      nhaController.dispose();
    }
  }

  Future<void> _deleteAbsence(_Absence absence) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer l’absence ?'),
        content: Text(
          '${_formatDate(absence.dateA)} — ${absence.matiere.codMat}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/absences/${absence.id}'),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}');
      }
      await _reloadAbsences();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _openTotals() async {
    final student = _selectedEtudiant;
    final classe = _selectedClasse;
    final department = _selectedDepartment;
    if (student == null || classe == null || department == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TotalAbsencesScreen(
          etudiant: student,
          classe: classe,
          departement: department.nomDept,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des absences'),
        actions: [
          IconButton(
            tooltip: 'Totaux et courbe',
            onPressed: _selectedEtudiant == null ? null : _openTotals,
            icon: const Icon(Icons.show_chart),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _selectedEtudiant == null ? null : () => _openAbsenceForm(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Erreur : $_error'))
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  DropdownButtonFormField<_Departement>(
                    initialValue: _selectedDepartment,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Département'),
                    hint: const Text('Choisir un département'),
                    items: _departements
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.nomDept),
                          ),
                        )
                        .toList(),
                    onChanged: _selectDepartment,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Classe>(
                    initialValue: _selectedClasse,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Classe'),
                    hint: const Text('Choisir une classe'),
                    items: _classes
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.nomClass),
                          ),
                        )
                        .toList(),
                    onChanged: _selectedDepartment == null
                        ? null
                        : _selectClasse,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Etudiant>(
                    initialValue: _selectedEtudiant,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Étudiant'),
                    hint: const Text('Choisir un étudiant'),
                    items: _etudiants
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(
                              '${item.nom} ${item.prenom}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _selectedClasse == null ? null : _selectEtudiant,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: ValueKey(_selectedEtudiant?.id),
                          initialValue: _selectedEtudiant?.nom ?? '',
                          readOnly: true,
                          decoration: const InputDecoration(labelText: 'Nom'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('prenom-${_selectedEtudiant?.id}'),
                          initialValue: _selectedEtudiant?.prenom ?? '',
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Prénom',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Absences',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(child: _buildAbsenceTable()),
                ],
              ),
            ),
    );
  }

  Widget _buildAbsenceTable() {
    if (_selectedEtudiant == null) {
      return const Center(
        child: Text('Sélectionnez un étudiant pour afficher ses absences.'),
      );
    }
    if (_absences.isEmpty) {
      return const Center(child: Text('Aucune absence enregistrée.'));
    }
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('DateA')),
            DataColumn(label: Text('CodMat')),
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('NHA')),
            DataColumn(label: Text('Actions')),
          ],
          rows: _absences
              .map(
                (absence) => DataRow(
                  cells: [
                    DataCell(Text(_formatDate(absence.dateA))),
                    DataCell(Text(absence.matiere.codMat)),
                    DataCell(Text(absence.typeSeance == 'TP' ? 'TP' : 'Cours')),
                    DataCell(Text(_formatHours(absence.nha))),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Modifier',
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _openAbsenceForm(absence),
                          ),
                          IconButton(
                            tooltip: 'Supprimer',
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteAbsence(absence),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';

String _formatHours(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);
