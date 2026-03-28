import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentAttendanceView extends StatelessWidget {
  final String studentId;

  const StudentAttendanceView({super.key, required this.studentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text("My Attendance",
            style: GoogleFonts.playfairDisplay(
                color: Colors.white, fontSize: 20)),
        centerTitle: true,
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection("attendance")
            .where("studentId", isEqualTo: studentId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _emptyState();
          }

          // ── Group by subject + lectureType ──
          // Key = "subject||lectureType"
          final Map<String, Map<String, dynamic>> grouped = {};

          for (var doc in snapshot.data!.docs) {
            final d    = doc.data() as Map<String, dynamic>;
            final subj = d["subject"]     as String? ?? "Unknown";
            final type = d["lectureType"] as String? ?? "LEC";
            final stat = d["status"]      as String? ?? "absent";
            final course = d["course"]   as String? ?? "";
            final div    = d["division"] as String? ?? "";
            final key  = "$subj||$type";

            grouped.putIfAbsent(key, () => {
              "subject":     subj,
              "type":        type,
              "course":      course,
              "division":    div,
              "present":     0,
              "total":       0,
            });
            grouped[key]!["total"] = (grouped[key]!["total"] as int) + 1;
            if (stat == "present") {
              grouped[key]!["present"] = (grouped[key]!["present"] as int) + 1;
            }
          }

          // Sort by subject name then type
          final list = grouped.values.toList()
            ..sort((a, b) {
              final sc = (a["subject"] as String).compareTo(b["subject"] as String);
              if (sc != 0) return sc;
              return (a["type"] as String).compareTo(b["type"] as String);
            });

          // Overall stats
          int totalP = 0, totalT = 0;
          for (var s in list) {
            totalP += s["present"] as int;
            totalT += s["total"]   as int;
          }
          final double overallPct = totalT > 0 ? totalP / totalT * 100 : 0;

          return Column(
            children: [
              // ── Overall banner ──
              Container(
                color: const Color(0xFF1E3A5F),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Row(children: [
                  SizedBox(
                    width: 70, height: 70,
                    child: Stack(alignment: Alignment.center, children: [
                      CircularProgressIndicator(
                        value: overallPct / 100,
                        strokeWidth: 6,
                        color: overallPct >= 75
                            ? Colors.greenAccent : Colors.redAccent,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                      ),
                      Text("${overallPct.toStringAsFixed(0)}%",
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ]),
                  ),
                  const SizedBox(width: 20),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("Overall Attendance",
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text("$totalP / $totalT classes",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: overallPct >= 75
                            ? Colors.green.withValues(alpha: 0.3)
                            : Colors.red.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                          overallPct >= 75 ? "✓ Good Standing" : "⚠ Attendance Low",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ]),
              ),

              // ── Table header ──
              Container(
                color: const Color(0xFF1E3A5F).withValues(alpha: 0.08),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(children: [
                  Expanded(flex: 3,
                      child: Text("Course",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.grey.shade700))),
                  SizedBox(width: 60,
                      child: Text("Type",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.grey.shade700))),
                  SizedBox(width: 75,
                      child: Text("Present/Total",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.grey.shade700))),
                  SizedBox(width: 60,
                      child: Text("  %",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.grey.shade700))),
                ]),
              ),

              // ── Rows ──
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final s    = list[i];
                    final p    = s["present"] as int;
                    final t    = s["total"]   as int;
                    final pct  = t > 0 ? p / t * 100 : 0.0;
                    final type = s["type"] as String;

                    final Color typeColor = type == "LAB"
                        ? Colors.green.shade700
                        : const Color(0xFF1E3A5F);

                    final Color pctColor = pct >= 75
                        ? Colors.green.shade700
                        : pct >= 60
                        ? Colors.orange.shade700
                        : Colors.red.shade700;

                    return Container(
                      decoration: BoxDecoration(
                        color: i.isEven
                            ? Colors.white
                            : const Color(0xFFF0F5FF),
                        border: Border(
                          bottom: BorderSide(
                              color: Colors.grey.shade200, width: 1),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(children: [
                        // Subject + course
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s["subject"],
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: Color(0xFF1A1A2E))),
                              const SizedBox(height: 2),
                              Text(
                                "${s["course"]} - ${s["division"]}",
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),

                        // Type badge
                        SizedBox(
                          width: 60,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(type,
                                  style: TextStyle(
                                      color: typeColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11)),
                            ),
                          ),
                        ),

                        // Present/Total
                        SizedBox(
                          width: 75,
                          child: Text("$p / $t",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ),

                        // Percentage
                        SizedBox(
                          width: 60,
                          child: Text(
                            "${pct.toStringAsFixed(0)}%",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: pctColor),
                          ),
                        ),
                      ]),
                    );
                  },
                ),
              ),

              // ── Bottom summary ──
              Container(
                color: const Color(0xFF1E3A5F),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _summaryChip("Total", "$totalT", Colors.white),
                    _summaryChip("Present", "$totalP", Colors.greenAccent),
                    _summaryChip("Absent",
                        "${totalT - totalP}", Colors.redAccent),
                    _summaryChip("Gross",
                        "${overallPct.toStringAsFixed(1)}%",
                        overallPct >= 75
                            ? Colors.greenAccent : Colors.redAccent),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryChip(String label, String value, Color color) {
    return Column(children: [
      Text(value,
          style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16)),
      Text(label,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11)),
    ]);
  }

  Widget _emptyState() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.fact_check_outlined,
            size: 64,
            color: const Color(0xFF1E3A5F).withValues(alpha: 0.3)),
        const SizedBox(height: 16),
        Text("No attendance records yet",
            style: GoogleFonts.montserrat(
                fontSize: 16, color: Colors.grey)),
      ]),
    );
  }
}