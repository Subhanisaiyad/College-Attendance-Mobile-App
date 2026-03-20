import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MarksDetailScreen extends StatelessWidget {
  final String subject;
  final String examType;
  final String course;
  final String division;
  final String date;
  final String total;
  final List<Map<String, dynamic>> records;

  const MarksDetailScreen({
    super.key,
    required this.subject,
    required this.examType,
    required this.course,
    required this.division,
    required this.date,
    required this.total,
    required this.records,
  });

  Color _gradeColor(double percent) {
    if (percent >= 75) return Colors.green;
    if (percent >= 50) return Colors.orange;
    return Colors.red;
  }

  String _grade(double percent) {
    if (percent >= 90) return "A+";
    if (percent >= 75) return "A";
    if (percent >= 60) return "B";
    if (percent >= 50) return "C";
    if (percent >= 35) return "D";
    return "F";
  }

  String get _average {
    final values = records
        .map((d) => double.tryParse(d["marks"] as String? ?? "") ?? 0)
        .toList();
    if (values.isEmpty) return "-";
    final avg = values.reduce((a, b) => a + b) / values.length;
    return "${avg.toStringAsFixed(1)} / $total";
  }

  int get _passCount {
    return records.where((d) {
      final m = double.tryParse(d["marks"] as String? ?? "") ?? 0;
      final t = double.tryParse(total) ?? 0;
      return t > 0 && (m / t * 100) >= 35;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(subject,
            style: GoogleFonts.playfairDisplay(
                color: Colors.white, fontSize: 18)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── Top Info Card ──
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 10)
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subject,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _infoChip(examType, Icons.assignment),
                    _infoChip("$course - $division", Icons.school),
                    _infoChip("Out of $total", Icons.score),
                    _infoChip(date, Icons.calendar_today),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _statBox("Total", "${records.length}", Icons.people, Colors.white),
                    const SizedBox(width: 10),
                    _statBox("Avg", _average, Icons.bar_chart, Colors.amber),
                    const SizedBox(width: 10),
                    _statBox("Pass", "$_passCount", Icons.check_circle, Colors.greenAccent),
                    const SizedBox(width: 10),
                    _statBox("Fail", "${records.length - _passCount}", Icons.cancel, Colors.redAccent),
                  ],
                ),
              ],
            ),
          ),

          // ── Students List ──
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: records.length,
              itemBuilder: (context, index) {
                final d                = records[index];
                final String studentId = d["studentId"] as String? ?? "";
                final String marks     = d["marks"]     as String? ?? "-";
                final double? m        = double.tryParse(marks);
                final double? t        = double.tryParse(total);
                final double percent   = (m != null && t != null && t > 0)
                    ? (m / t * 100) : 0;

                // ✅ HAMESHA students collection se fetch karo
                // Taaki dono cases mein name + rollnumber sahi aaye
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection("students")
                      .doc(studentId)
                      .get(),
                  builder: (ctx, sSnap) {
                    String displayName = "Loading...";
                    String rollNumber  = "";

                    if (sSnap.connectionState == ConnectionState.waiting) {
                      displayName = "Loading...";
                    }

                    if (sSnap.hasData && sSnap.data!.exists) {
                      final sd = sSnap.data!.data() as Map<String, dynamic>;

                      // ✅ username field se name fetch karo
                      displayName = sd["username"]   as String? ??
                          sd["name"]       as String? ??
                          studentId;

                      // ✅ rollnumber field se ID fetch karo
                      rollNumber  = sd["rollnumber"] as String? ?? "";
                    }

                    return _studentCard(
                      index + 1,
                      displayName,
                      rollNumber,
                      marks,
                      percent,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Student Card ──
  Widget _studentCard(
      int rank,
      String name,
      String rollNumber,
      String marks,
      double percent,
      ) {
    final color = _gradeColor(percent);
    final grade = _grade(percent);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
      ),
      child: Row(
        children: [
          // ── Rank ──
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text("$rank",
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F))),
            ),
          ),
          const SizedBox(width: 10),

          // ── Avatar ──
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withOpacity(0.12),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : "?",
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),

          // ── Name + Roll Number ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 2),
                // ✅ Roll: 25MCA148 format
                if (rollNumber.isNotEmpty)
                  Text(
                    "Roll: $rollNumber",
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),

          // ── Marks Badge ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              "$marks / $total",
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),

          // ── Grade Badge ──
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(grade,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String label, IconData icon) {
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

  Widget _statBox(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
            Text(label,
                style: const TextStyle(
                    color: Colors.white60, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}