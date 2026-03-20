import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'marks_detail_screen.dart'; // ✅ New screen

class ViewMarks extends StatefulWidget {
  final String teacherId;
  const ViewMarks({super.key, required this.teacherId});

  @override
  State<ViewMarks> createState() => _ViewMarksState();
}

class _ViewMarksState extends State<ViewMarks> {
  String? _selectedSubject;
  String? _selectedExamType;
  List<String> _subjects  = [];
  List<String> _examTypes = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text("View Marks",
            style: GoogleFonts.playfairDisplay(
                color: Colors.white, fontSize: 20)),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("marks")
            .where("teacherId", isEqualTo: widget.teacherId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.score_outlined,
                      size: 70,
                      color: const Color(0xFF1E3A5F).withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text("No Marks Uploaded Yet",
                      style: GoogleFonts.montserrat(
                          fontSize: 16, color: Colors.grey)),
                ],
              ),
            );
          }

          final allDocs = snapshot.data!.docs;

          // ── Unique filters ──
          final subjectSet  = <String>{};
          final examTypeSet = <String>{};
          for (var doc in allDocs) {
            final d = doc.data() as Map<String, dynamic>;
            final s = d["subject"]  as String? ?? "";
            final e = d["examType"] as String? ?? "";
            if (s.isNotEmpty) subjectSet.add(s);
            if (e.isNotEmpty) examTypeSet.add(e);
          }
          _subjects  = subjectSet.toList()..sort();
          _examTypes = examTypeSet.toList()..sort();

          // ── Filter ──
          final filtered = allDocs.where((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final matchSubject  = _selectedSubject  == null || d["subject"]  == _selectedSubject;
            final matchExamType = _selectedExamType == null || d["examType"] == _selectedExamType;
            return matchSubject && matchExamType;
          }).toList();

          // ── Group by subject+examType+course+division+date+total ──
          final Map<String, List<Map<String, dynamic>>> grouped = {};
          for (var doc in filtered) {
            final d        = doc.data() as Map<String, dynamic>;
            final subject  = d["subject"]  as String? ?? "Unknown";
            final examType = d["examType"] as String? ?? "-";
            final course   = d["course"]   as String? ?? "";
            final division = d["division"] as String? ?? "";
            final date     = d["date"]     as String? ?? "";
            final total    = d["totalMarks"] as String? ?? "-";
            final key      = "$subject||$examType||$course||$division||$date||$total";
            grouped.putIfAbsent(key, () => []);
            grouped[key]!.add(d);
          }

          return Column(
            children: [
              // ── Filter Chips ──
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  children: [
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _filterChip("All Subjects", _selectedSubject == null,
                                  () => setState(() => _selectedSubject = null)),
                          ..._subjects.map((s) => _filterChip(s, _selectedSubject == s,
                                  () => setState(() => _selectedSubject = _selectedSubject == s ? null : s))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _filterChip("All Exams", _selectedExamType == null,
                                  () => setState(() => _selectedExamType = null)),
                          ..._examTypes.map((e) => _filterChip(e, _selectedExamType == e,
                                  () => setState(() => _selectedExamType = _selectedExamType == e ? null : e))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Cards List ──
              Expanded(
                child: grouped.isEmpty
                    ? Center(
                    child: Text("No records found",
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 15)))
                    : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: grouped.keys.length,
                  itemBuilder: (context, index) {
                    final key      = grouped.keys.elementAt(index);
                    final parts    = key.split("||");
                    final subject  = parts[0];
                    final examType = parts[1];
                    final course   = parts[2];
                    final division = parts[3];
                    final date     = parts[4];
                    final total    = parts[5];
                    final records  = grouped[key]!;

                    // ── Average calculate ──
                    final values = records
                        .map((d) => double.tryParse(d["marks"] as String? ?? "") ?? 0)
                        .toList();
                    final avg = values.isEmpty
                        ? "-"
                        : "${(values.reduce((a, b) => a + b) / values.length).toStringAsFixed(1)} / $total";

                    // ✅ GestureDetector - click par navigate
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MarksDetailScreen(
                              subject:  subject,
                              examType: examType,
                              course:   course,
                              division: division,
                              date:     date,
                              total:    total,
                              records:  records,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 8)
                          ],
                        ),
                        child: Column(
                          children: [
                            // ── Card Header ──
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: const BoxDecoration(
                                color: Color(0xFF1E3A5F),
                                borderRadius: BorderRadius.only(
                                  topLeft:  Radius.circular(16),
                                  topRight: Radius.circular(16),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(subject,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15)),
                                      ),
                                      // ✅ Tap hint
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text("View",
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600)),
                                            SizedBox(width: 4),
                                            Icon(Icons.arrow_forward_ios,
                                                color: Colors.white, size: 10),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      _whiteChip(examType, Icons.assignment),
                                      _whiteChip("$course-$division", Icons.school),
                                      _whiteChip("Out of $total", Icons.score),
                                      _whiteChip(date, Icons.calendar_today),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // ── Card Footer (sirf count + avg) ──
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.people,
                                          size: 15,
                                          color: Colors.grey.shade500),
                                      const SizedBox(width: 5),
                                      Text("${records.length} students",
                                          style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 12)),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Icon(Icons.bar_chart,
                                          size: 15,
                                          color: const Color(0xFF1E3A5F)
                                              .withOpacity(0.7)),
                                      const SizedBox(width: 5),
                                      Text("Avg: $avg",
                                          style: const TextStyle(
                                              color: Color(0xFF1E3A5F),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12)),
                                    ],
                                  ),
                                ],
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

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1E3A5F) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.grey.shade600)),
      ),
    );
  }

  Widget _whiteChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white70),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}