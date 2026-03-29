import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class StudentMarksView extends StatefulWidget {
  final String studentId;
  final String collegeId;
  final String semester; // ✅

  const StudentMarksView({
    super.key,
    required this.studentId,
    required this.collegeId,
    required this.semester,
  });

  @override
  State<StudentMarksView> createState() => _StudentMarksViewState();
}

class _StudentMarksViewState extends State<StudentMarksView> {
  String _selectedSubject = "All";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text("My Marks",
            style: GoogleFonts.playfairDisplay(
                color: Colors.white, fontSize: 20)),
        centerTitle: true,
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection("marks")
            .where("studentId", isEqualTo: widget.studentId)
            .where("semester",  isEqualTo: widget.semester)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.score_outlined,
                      size: 64,
                      color: const Color(0xFF1E3A5F).withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text("No marks uploaded yet",
                      style: GoogleFonts.montserrat(
                          fontSize: 16, color: Colors.grey)),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          // All subjects for filter
          final subjects = <String>{"All"};
          for (var d in docs) {
            subjects.add(
                (d.data() as Map<String, dynamic>)["subject"] as String? ??
                    "");
          }

          // Filter
          final filtered = _selectedSubject == "All"
              ? docs
              : docs
              .where((d) =>
          (d.data() as Map)["subject"] == _selectedSubject)
              .toList();

          // Sort by date desc
          filtered.sort((a, b) {
            final ad = (a.data() as Map)["uploadedAt"] as String? ?? "";
            final bd = (b.data() as Map)["uploadedAt"] as String? ?? "";
            return bd.compareTo(ad);
          });

          return Column(
            children: [
              // ── Subject filter ──
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: subjects.map((s) {
                      final bool sel = s == _selectedSubject;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedSubject = s),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel
                                ? const Color(0xFF1E3A5F)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(s,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: sel
                                      ? Colors.white
                                      : Colors.grey.shade700)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // ── Marks list ──
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final d       = filtered[i].data() as Map<String, dynamic>;
                    final subject = d["subject"]    as String? ?? "-";
                    final exam    = d["examType"]   as String? ?? "-";
                    final marks   = d["marks"]      as String? ?? "-";
                    final total   = d["totalMarks"] as String? ?? "-";
                    final date    = d["date"]       as String? ?? "-";
                    final course  = d["course"]     as String? ?? "";
                    final div     = d["division"]   as String? ?? "";

                    final double? m  = double.tryParse(marks);
                    final double? t  = double.tryParse(total);
                    final double pct = (m != null && t != null && t > 0)
                        ? m / t * 100
                        : 0;
                    final Color c = pct >= 75
                        ? Colors.green
                        : pct >= 50
                        ? Colors.orange
                        : Colors.red;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 8)
                        ],
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            // Color strip
                            Container(
                              width: 6,
                              decoration: BoxDecoration(
                                color: c,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  bottomLeft: Radius.circular(16),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(subject,
                                              style: const TextStyle(
                                                  fontWeight:
                                                  FontWeight.bold,
                                                  fontSize: 15,
                                                  color:
                                                  Color(0xFF1A1A2E))),
                                        ),
                                        // Marks badge
                                        Container(
                                          padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 4),
                                          decoration: BoxDecoration(
                                            color:
                                            c.withValues(alpha: 0.1),
                                            borderRadius:
                                            BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            "$marks / $total",
                                            style: TextStyle(
                                                color: c,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        _chip(exam, Icons.assignment),
                                        const SizedBox(width: 8),
                                        _chip("$course-$div",
                                            Icons.school_outlined),
                                        const SizedBox(width: 8),
                                        _chip(date,
                                            Icons.calendar_today_outlined),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius:
                                      BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: pct / 100,
                                        backgroundColor:
                                        c.withValues(alpha: 0.15),
                                        valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                            c),
                                        minHeight: 6,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${pct.toStringAsFixed(1)}%  ·  ${_grade(pct)}",
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: c,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
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

  String _grade(double pct) {
    if (pct >= 90) return "Outstanding";
    if (pct >= 75) return "Good";
    if (pct >= 60) return "Average";
    if (pct >= 50) return "Pass";
    return "Fail";
  }

  Widget _chip(String label, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: Colors.grey.shade500),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }
}