import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'classes_screen.dart';
import 'config.dart';
import 'etudiants_screen.dart';

class _MatiereTotal {
  final String codMat;
  final double totalNha;

  const _MatiereTotal(this.codMat, this.totalNha);

}

class TotalAbsencesScreen extends StatefulWidget {
  final Etudiant etudiant;
  final Classe classe;
  final String departement;

  const TotalAbsencesScreen({
    super.key,
    required this.etudiant,
    required this.classe,
    required this.departement,
  });

  @override
  State<TotalAbsencesScreen> createState() => _TotalAbsencesScreenState();
}

class _TotalAbsencesScreenState extends State<TotalAbsencesScreen> {
  late Future<List<_MatiereTotal>> _totals;

  @override
  void initState() {
    super.initState();
    _totals = _loadTotals();
  }

  Future<List<_MatiereTotal>> _loadTotals() async {
    final response = await http.get(
      Uri.parse('$baseUrl/absences/etudiant/${widget.etudiant.id}'),
    );
    if (response.statusCode != 200) {
      throw Exception('Impossible de charger les absences (HTTP ${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) throw const FormatException('Réponse serveur invalide');
    final totals = <String, double>{};
    for (final item in decoded) {
      final absence = Map<String, dynamic>.from(item as Map);
      final matiere = Map<String, dynamic>.from(absence['matiere'] as Map);
      final codMat = matiere['codMat'].toString();
      final nha = (absence['nha'] as num).toDouble();
      totals.update(codMat, (total) => total + nha, ifAbsent: () => nha);
    }
    final entries = totals.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((entry) => _MatiereTotal(entry.key, entry.value)).toList();
  }

  String _hours(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Total des absences')),
      body: FutureBuilder<List<_MatiereTotal>>(
        future: _totals,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Erreur : ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final totals = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Classe : ${widget.classe.nomClass}    Département : ${widget.departement}'),
              const SizedBox(height: 8),
              Text(
                'Étudiant : ${widget.etudiant.id}    Nom : ${widget.etudiant.nom}    Prénom : ${widget.etudiant.prenom}',
              ),
              const SizedBox(height: 20),
              if (totals.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Aucune absence enregistrée pour cet étudiant.'),
                )
              else ...[
                const Text('Total par matière', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('CodMat')),
                      DataColumn(label: Text('Total NHA')),
                    ],
                    rows: [
                      ...totals.map((item) => DataRow(cells: [
                            DataCell(Text(item.codMat)),
                            DataCell(Text(_hours(item.totalNha))),
                          ])),
                      DataRow(cells: [
                        const DataCell(Text('Total général', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(
                          _hours(totals.fold<double>(0, (sum, item) => sum + item.totalNha)),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        )),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Courbe des absences', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 280,
                  child: CustomPaint(
                    painter: _AbsenceChartPainter(totals),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AbsenceChartPainter extends CustomPainter {
  final List<_MatiereTotal> totals;

  _AbsenceChartPainter(this.totals);

  @override
  void paint(Canvas canvas, Size size) {
    if (totals.isEmpty) return;
    const left = 42.0;
    const right = 12.0;
    const top = 14.0;
    const bottom = 54.0;
    final chartWidth = math.max(0.0, size.width - left - right);
    final chartHeight = math.max(0.0, size.height - top - bottom);
    if (chartWidth == 0 || chartHeight == 0) return;

    final maxValue = totals.map((item) => item.totalNha).reduce(math.max);
    final scaleMax = maxValue <= 0 ? 1.0 : maxValue * 1.2;
    final axisPaint = Paint()
      ..color = Colors.blueGrey
      ..strokeWidth = 1.2;
    final gridPaint = Paint()
      ..color = Colors.blueGrey.withValues(alpha: 0.2)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(left, top), Offset(left, top + chartHeight), axisPaint);
    canvas.drawLine(Offset(left, top + chartHeight), Offset(left + chartWidth, top + chartHeight), axisPaint);

    for (var i = 0; i <= 4; i++) {
      final y = top + chartHeight * i / 4;
      canvas.drawLine(Offset(left, y), Offset(left + chartWidth, y), gridPaint);
      final value = scaleMax * (4 - i) / 4;
      _drawText(canvas, _format(value), Offset(0, y - 7), 11, Colors.blueGrey);
    }

    final points = <Offset>[];
    for (var i = 0; i < totals.length; i++) {
      final x = totals.length == 1
          ? left + chartWidth / 2
          : left + chartWidth * i / (totals.length - 1);
      final y = top + chartHeight * (1 - totals[i].totalNha / scaleMax);
      points.add(Offset(x, y));
    }
    final linePaint = Paint()
      ..color = Colors.deepPurple
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, linePaint);
    }

    final dotPaint = Paint()..color = Colors.deepPurple;
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 4, dotPaint);
      _drawText(canvas, totals[i].codMat, Offset(points[i].dx - 20, top + chartHeight + 10), 11, Colors.black87);
      _drawText(canvas, _format(totals[i].totalNha), Offset(points[i].dx - 15, points[i].dy - 20), 11, Colors.deepPurple);
    }
  }

  String _format(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1);

  void _drawText(Canvas canvas, String text, Offset offset, double size, Color color) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: size, color: color)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _AbsenceChartPainter oldDelegate) => oldDelegate.totals != totals;
}
