import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceScreen extends StatefulWidget {
  final String course;
  final String division;
  final String subject;
  final String teacherId;
  final bool skipDateCheck;
  final DateTime? forDate;
  final int lectureNo;

  const AttendanceScreen({
    super.key,
    required this.course,
    required this.division,
    required this.subject,
    required this.teacherId,
    this.skipDateCheck = false,
    this.forDate,
    this.lectureNo = 1,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  Map<String, bool>   attendance   = {};
  Map<String, String> studentNames = {}; // ✅ username
  Map<String, String> studentRolls = {}; // ✅ rollnumber
  bool isSaving     = false;
  bool alreadyTaken = false;
  bool isChecking   = true;
  bool showPreview  = false;
  bool savedDone    = false;

  int get totalStudents => attendance.length;
  int get presentCount  => attendance.values.where((v) => v).length;
  int get absentCount   => attendance.values.where((v) => !v).length;

  List<String> get presentIds => attendance.entries.where((e) => e.value).map((e) => e.key).toList();
  List<String> get absentIds  => attendance.entries.where((e) => !e.value).map((e) => e.key).toList();

  @override
  void initState() {
    super.initState();
    if (widget.skipDateCheck) {
      setState(() => isChecking = false);
    } else {
      checkIfAlreadyTaken();
    }
  }

  Future<void> checkIfAlreadyTaken() async {
    try {
      final checkDate  = widget.forDate ?? DateTime.now();
      final startOfDay = DateTime(checkDate.year, checkDate.month, checkDate.day, 0, 0, 0);
      final endOfDay   = DateTime(checkDate.year, checkDate.month, checkDate.day, 23, 59, 59);

      final query = await FirebaseFirestore.instance
          .collection("attendance")
          .where("teacherId", isEqualTo: widget.teacherId)
          .where("subject",   isEqualTo: widget.subject)
          .where("date", isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where("date", isLessThanOrEqualTo:   Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();

      if (mounted) {
        setState(() {
          alreadyTaken = query.docs.isNotEmpty;
          isChecking   = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isChecking = false);
    }
  }

  void openPreview() {
    if (attendance.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No students to save")),
      );
      return;
    }
    setState(() => showPreview = true);
  }

  Future<void> confirmAndSave() async {
    setState(() => isSaving = true);

    try {
      final DateTime saveDate = widget.forDate ?? DateTime.now();

      for (var entry in attendance.entries) {
        await FirebaseFirestore.instance.collection("attendance").add({
          "studentId": entry.key,
          "status":    entry.value ? "present" : "absent",
          "course":    widget.course,
          "division":  widget.division,
          "subject":   widget.subject,
          "date":      Timestamp.fromDate(saveDate),
          "teacherId": widget.teacherId,
          "present":   presentCount,
          "absent":    absentCount,
          "total":     totalStudents,
          "lectureNo": widget.lectureNo,
        });
      }

      if (mounted) {
        setState(() {
          isSaving  = false;
          savedDone = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving: $e"),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => isSaving = false);
      }
    }
  }

  // ✅ Preview Page
  Widget _buildPreviewPage() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        title: Text(
          savedDone ? "Attendance Saved!" : "Confirm Attendance",
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: savedDone
            ? null
            : IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => setState(() => showPreview = false),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (savedDone)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Colors.green, size: 36),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Attendance Saved Successfully!",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          "${widget.subject} · Lecture ${widget.lectureNo}",
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            Row(
              children: [
                _countCard("Total",   totalStudents, Icons.groups_rounded,       const Color(0xFF1E3A5F)),
                const SizedBox(width: 10),
                _countCard("Present", presentCount,  Icons.check_circle_rounded, Colors.green),
                const SizedBox(width: 10),
                _countCard("Absent",  absentCount,   Icons.cancel_rounded,       Colors.red),
              ],
            ),

            const SizedBox(height: 20),

            _buildStudentList(
              title: "✅ Present Students",
              ids: presentIds,
              color: Colors.green,
              bgColor: Colors.green.shade50,
              borderColor: Colors.green.shade200,
            ),

            const SizedBox(height: 16),

            _buildStudentList(
              title: "❌ Absent Students",
              ids: absentIds,
              color: Colors.red,
              bgColor: Colors.red.shade50,
              borderColor: Colors.red.shade200,
            ),

            const SizedBox(height: 24),

            if (!savedDone) ...[
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF1E3A5F), width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => setState(() => showPreview = false),
                  icon: const Icon(Icons.edit, color: Color(0xFF1E3A5F)),
                  label: const Text(
                    "Edit Attendance",
                    style: TextStyle(
                      color: Color(0xFF1E3A5F),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: isSaving ? null : confirmAndSave,
                  icon: isSaving
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                      : const Icon(Icons.cloud_upload_rounded, color: Colors.white),
                  label: Text(
                    isSaving ? "Saving..." : "Confirm & Save",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A5F),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  label: const Text(
                    "Go Back",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _countCard(String label, int count, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text("$count",
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentList({
    required String title,
    required List<String> ids,
    required Color color,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$title (${ids.length})",
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 10),
          ids.isEmpty
              ? Text("None",
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14))
              : Column(
            children: ids.map((id) {
              final name = studentNames[id] ?? id;
              final roll = studentRolls[id] ?? ""; // ✅
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: color.withOpacity(0.15),
                      child: Text(
                        name[0].toUpperCase(),
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                          // ✅ Roll number neeche
                          if (roll.isNotEmpty)
                            Text(
                              "Roll: $roll",
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        color == Colors.green ? "Present ✓" : "Absent ✗",
                        style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (showPreview) return _buildPreviewPage();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        title: Text(
          "Lecture ${widget.lectureNo}  ·  ${widget.subject}",
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: widget.forDate != null
            ? PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              "📅 Marking for: ${_formatDate(widget.forDate!)}",
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        )
            : null,
      ),
      body: isChecking
          ? const Center(child: CircularProgressIndicator())
          : alreadyTaken
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: Colors.green, size: 55),
              ),
              const SizedBox(height: 24),
              const Text(
                "Attendance Already Taken!",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F)),
              ),
              const SizedBox(height: 12),
              Text(
                "${widget.subject}\n${widget.course} - ${widget.division}",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.6),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A5F),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  label: const Text("Go Back",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      )
          : Column(
        children: [
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.school,
                    color: Color(0xFF1E3A5F), size: 18),
                const SizedBox(width: 8),
                Text(
                  "${widget.course} - Division ${widget.division}",
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("students")
                  .where("course",   isEqualTo: widget.course)
                  .where("division", isEqualTo: widget.division)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                final students = snapshot.data!.docs;
                if (students.isEmpty) {
                  return const Center(
                      child: Text("No Students Found"));
                }

                for (var s in students) {
                  final data = s.data() as Map<String, dynamic>;
                  attendance.putIfAbsent(s.id, () => false);
                  // ✅ username aur rollnumber dono save karo
                  studentNames[s.id] =
                      data["username"]   as String? ??
                          data["name"]       as String? ?? "Unknown";
                  studentRolls[s.id] =
                      data["rollnumber"] as String? ?? "";
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final String id  = students[index].id;
                    final String name = studentNames[id] ?? "Unknown";
                    final String roll = studentRolls[id] ?? "";
                    final bool isPresent = attendance[id] ?? false;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isPresent
                              ? Colors.green.shade300
                              : Colors.red.shade200,
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black12, blurRadius: 6)
                        ],
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPresent
                              ? Colors.green
                              : Colors.red.shade100,
                          child: Text(
                            name[0].toUpperCase(),
                            style: TextStyle(
                                color: isPresent
                                    ? Colors.white
                                    : Colors.red,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        // ✅ Name + Roll number
                        title: Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (roll.isNotEmpty)
                              Text(
                                "Roll: $roll",
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            Text(
                              isPresent ? "Present ✓" : "Absent ✗",
                              style: TextStyle(
                                  color: isPresent
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        trailing: Switch(
                          value: isPresent,
                          activeColor: Colors.green,
                          inactiveThumbColor: Colors.red,
                          onChanged: (value) =>
                              setState(() => attendance[id] = value),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A5F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: openPreview,
                child: const Text(
                  "Save Attendance",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return "${dt.day.toString().padLeft(2, '0')}-"
        "${dt.month.toString().padLeft(2, '0')}-${dt.year}";
  }
}