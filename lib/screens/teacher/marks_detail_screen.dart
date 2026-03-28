import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MarksDetailScreen extends StatefulWidget {
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

  @override
  State<MarksDetailScreen> createState() => _MarksDetailScreenState();
}

class _MarksDetailScreenState extends State<MarksDetailScreen> {
  List<Map<String, dynamic>> _sortedRecords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAndSortData();
  }

  Future<void> _fetchAndSortData() async {
    List<Map<String, dynamic>> tempRecords = [];

    // Fetch student details for all records
    for (var record in widget.records) {
      final String studentId = record["studentId"] as String? ?? "";
      String displayName = studentId;
      String rollNumber = "";

      if (studentId.isNotEmpty) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection("students")
              .doc(studentId)
              .get();

          if (doc.exists) {
            final data = doc.data() as Map<String, dynamic>;
            displayName = data["username"] as String? ??
                data["name"] as String? ??
                studentId;
            // Roll number format check
            rollNumber = data["rollnumber"] as String? ??
                data["rollNumber"] as String? ??
                "";
          }
        } catch (e) {
          debugPrint("Error fetching student $studentId: $e");
        }
      }

      tempRecords.add({
        ...record,
        "displayName": displayName,
        "rollNumber": rollNumber,
      });
    }

    // ✅ Sort by Roll Number
    tempRecords.sort((a, b) {
      final String rollA = a["rollNumber"] ?? "";
      final String rollB = b["rollNumber"] ?? "";
      return rollA.compareTo(rollB);
    });

    if (mounted) {
      setState(() {
        _sortedRecords = tempRecords;
        _isLoading = false;
      });
    }
  }

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
    final values = widget.records
        .map((d) => double.tryParse(d["marks"] as String? ?? "") ?? 0)
        .toList();
    if (values.isEmpty) return "-";
    final avg = values.reduce((a, b) => a + b) / values.length;
    return "${avg.toStringAsFixed(1)} / ${widget.total}";
  }

  int get _passCount {
    return widget.records.where((d) {
      final m = double.tryParse(d["marks"] as String? ?? "") ?? 0;
      final t = double.tryParse(widget.total) ?? 0;
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
        title: Text(widget.subject,
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
                Text(widget.subject,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _infoChip(widget.examType, Icons.assignment),
                    _infoChip("${widget.course} - ${widget.division}", Icons.school),
                    _infoChip("Out of ${widget.total}", Icons.score),
                    _infoChip(widget.date, Icons.calendar_today),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _statBox("Total", "${widget.records.length}", Icons.people, Colors.white),
                    const SizedBox(width: 10),
                    _statBox("Avg", _average, Icons.bar_chart, Colors.amber),
                    const SizedBox(width: 10),
                    _statBox("Pass", "$_passCount", Icons.check_circle, Colors.greenAccent),
                    const SizedBox(width: 10),
                    _statBox("Fail", "${widget.records.length - _passCount}", Icons.cancel, Colors.redAccent),
                  ],
                ),
              ],
            ),
          ),

          // ── Students List ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _sortedRecords.length,
              itemBuilder: (context, index) {
                final d = _sortedRecords[index];
                final String marks = d["marks"] as String? ?? "-";
                final String displayName = d["displayName"] as String? ?? "Unknown";
                final String rollNumber = d["rollNumber"] as String? ?? "";

                final double? m = double.tryParse(marks);
                final double? t = double.tryParse(widget.total);
                final double percent = (m != null && t != null && t > 0)
                    ? (m / t * 100)
                    : 0;

                return _studentCard(
                  index + 1,
                  displayName,
                  rollNumber,
                  marks,
                  percent,
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
              "$marks / ${widget.total}",
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