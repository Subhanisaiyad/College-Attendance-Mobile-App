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

          // Group by subject
          final Map<String, Map<String, dynamic>> bySubject = {};
          for (var doc in snapshot.data!.docs) {
            final d       = doc.data() as Map<String, dynamic>;
            final subject = d["subject"]  as String? ?? "Unknown";
            final status  = d["status"]   as String? ?? "absent";
            final course  = d["course"]   as String? ?? "";
            final div     = d["division"] as String? ?? "";

            bySubject.putIfAbsent(subject, () => {
              "subject":  subject,
              "course":   course,
              "division": div,
              "present":  0,
              "total":    0,
            });
            bySubject[subject]!["total"] =
                (bySubject[subject]!["total"] as int) + 1;
            if (status == "present") {
              bySubject[subject]!["present"] =
                  (bySubject[subject]!["present"] as int) + 1;
            }
          }

          final list = bySubject.values.toList()
            ..sort((a, b) {
              final ap = (a["present"] as int) / (a["total"] as int);
              final bp = (b["present"] as int) / (b["total"] as int);
              return ap.compareTo(bp);
            });

          // Overall stats
          int totalP = 0, totalT = 0;
          for (var s in list) {
            totalP += s["present"] as int;
            totalT += s["total"]   as int;
          }
          final double overallPct =
          totalT > 0 ? totalP / totalT * 100 : 0;

          return Column(
            children: [
              // ── Overall banner ──
              Container(
                color: const Color(0xFF1E3A5F),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    // Circle indicator
                    SizedBox(
                      width: 70, height: 70,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: overallPct / 100,
                            strokeWidth: 6,
                            color: overallPct >= 75
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            backgroundColor:
                            Colors.white.withValues(alpha: 0.2),
                          ),
                          Text(
                            "${overallPct.toStringAsFixed(0)}%",
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Overall Attendance",
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12)),
                        Text(
                          "$totalP / $totalT classes",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
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
                            overallPct >= 75
                                ? "✓ Good Standing"
                                : "⚠ Attendance Low",
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Subject list ──
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final s       = list[i];
                    final int p   = s["present"] as int;
                    final int t   = s["total"]   as int;
                    final double pct = t > 0 ? p / t * 100 : 0;
                    final Color c = pct >= 75
                        ? Colors.green
                        : pct >= 60
                        ? Colors.orange
                        : Colors.red;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: c.withValues(alpha: 0.3), width: 1),
                        boxShadow: [
                          BoxShadow(
                              color: c.withValues(alpha: 0.07),
                              blurRadius: 8)
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(s["subject"],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Color(0xFF1A1A2E))),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: c.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "${pct.toStringAsFixed(1)}%",
                                  style: TextStyle(
                                      color: c,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${s["course"]} - ${s["division"]}  ·  $p / $t classes",
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500),
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: pct / 100,
                              backgroundColor:
                              c.withValues(alpha: 0.15),
                              valueColor:
                              AlwaysStoppedAnimation<Color>(c),
                              minHeight: 8,
                            ),
                          ),
                          if (pct < 75) ...[
                            const SizedBox(height: 8),
                            Text(
                              "Need ${_classesNeeded(p, t)} more classes for 75%",
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.red.shade400,
                                  fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  int _classesNeeded(int present, int total) {
    // Classes needed to reach 75%: (0.75*total - present) / 0.25
    int needed = 0;
    int p = present, t = total;
    while (t > 0 && p / t < 0.75) {
      p++; t++; needed++;
    }
    return needed;
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fact_check_outlined,
              size: 64,
              color: const Color(0xFF1E3A5F).withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text("No attendance records yet",
              style: GoogleFonts.montserrat(
                  fontSize: 16, color: Colors.grey)),
        ],
      ),
    );
  }
}