import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class AddTimetable extends StatefulWidget {
  final String collegeId; // ✅
  const AddTimetable({super.key, required this.collegeId});

  @override
  State<AddTimetable> createState() => _AddTimetableState();
}

class _AddTimetableState extends State<AddTimetable> {
  final courseCtrl    = TextEditingController();
  final divisionCtrl  = TextEditingController();
  final roomCtrl      = TextEditingController();
  final startCtrl     = TextEditingController();
  final endCtrl       = TextEditingController();

  String? selectedDay, selectedLecture, selectedSubjectId;
  String? selectedSemester; // ✅ Added semester variable
  String? selectedSubjectName, selectedTeacherId, selectedTeacherName;
  String  selectedType = "LEC";
  bool    isLoading    = false;

  static const _types = [
    {"value": "LEC", "label": "LEC — Lecture"},
    {"value": "LAB", "label": "LAB — Laboratory"},
  ];

  Color _typeColor(String t) =>
      t == "LAB" ? Colors.green.shade700 : const Color(0xFF1E3A5F);

  Future<void> save() async {
    if (courseCtrl.text.isEmpty || divisionCtrl.text.isEmpty ||
        roomCtrl.text.isEmpty || selectedDay == null ||
        selectedLecture == null || selectedSubjectId == null ||
        selectedSemester == null || // ✅ Validation for semester
        selectedTeacherId == null || startCtrl.text.isEmpty ||
        endCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please fill all fields")));
      return;
    }
    setState(() => isLoading = true);
    await FirebaseFirestore.instance.collection("timetable").add({
      "course":      courseCtrl.text.trim(),
      "division":    divisionCtrl.text.trim(),
      "semester":    selectedSemester, // ✅ Saved semester to database
      "room":        roomCtrl.text.trim(),
      "day":         selectedDay,
      "lectureNo":   int.parse(selectedLecture!),
      "lectureType": selectedType,
      "subjectId":   selectedSubjectId,
      "subjectName": selectedSubjectName,
      "teacherId":   selectedTeacherId,
      "teacherName": selectedTeacherName,
      "startTime":   startCtrl.text.trim(),
      "endTime":     endCtrl.text.trim(),
      "collegeId":   widget.collegeId, // ✅
      "createdAt":   Timestamp.now(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Timetable Saved!"),
              backgroundColor: Colors.green));
      Navigator.pop(context);
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Timetable", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E3A5F),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(children: [
          TextField(controller: courseCtrl,   decoration: const InputDecoration(labelText: "Course")),
          const SizedBox(height: 15),

          // ✅ Added Dropdown for Semester
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: "Semester"),
            items: ["Sem 1", "Sem 2", "Sem 3", "Sem 4", "Sem 5", "Sem 6", "Sem 7", "Sem 8"]
                .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => selectedSemester = v),
          ),
          const SizedBox(height: 15),

          TextField(controller: divisionCtrl, decoration: const InputDecoration(labelText: "Division (A/B/C)")),
          const SizedBox(height: 15),
          TextField(controller: roomCtrl,     decoration: const InputDecoration(labelText: "Class / Lab")),
          const SizedBox(height: 15),

          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: "Day"),
            items: ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
                .map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
            onChanged: (v) => setState(() => selectedDay = v),
          ),
          const SizedBox(height: 15),

          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: "Lecture No"),
            items: List.generate(6, (i) => DropdownMenuItem(
                value: "${i+1}", child: Text("Lecture ${i+1}"))),
            onChanged: (v) => setState(() => selectedLecture = v),
          ),
          const SizedBox(height: 15),

          DropdownButtonFormField<String>(
            value: selectedType,
            decoration: const InputDecoration(
              labelText: "Lecture Type",
              prefixIcon: Icon(Icons.category_outlined, color: Color(0xFF1E3A5F)),
            ),
            items: _types.map((t) => DropdownMenuItem(
              value: t["value"],
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _typeColor(t["value"]!).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(t["value"]!,
                      style: TextStyle(color: _typeColor(t["value"]!),
                          fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(width: 10),
                Text(t["label"]!.split("—").last.trim()),
              ]),
            )).toList(),
            onChanged: (v) => setState(() => selectedType = v!),
          ),
          const SizedBox(height: 15),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection("subjects")
                .where("collegeId", isEqualTo: widget.collegeId).snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const CircularProgressIndicator();
              return DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Subject"),
                items: snap.data!.docs.map((doc) => DropdownMenuItem<String>(
                    value: doc.id, child: Text((doc.data() as Map)["subjectName"] ?? ""))).toList(),
                onChanged: (v) {
                  final sub = snap.data!.docs.firstWhere((d) => d.id == v);
                  setState(() { selectedSubjectId = v; selectedSubjectName = (sub.data() as Map)["subjectName"]; });
                },
              );
            },
          ),
          const SizedBox(height: 15),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection("teachers")
                .where("collegeId", isEqualTo: widget.collegeId).snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const CircularProgressIndicator();
              return DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Teacher Name"),
                items: snap.data!.docs.map((doc) => DropdownMenuItem<String>(
                    value: doc.id, child: Text((doc.data() as Map)["name"] ?? ""))).toList(),
                onChanged: (v) {
                  final t = snap.data!.docs.firstWhere((d) => d.id == v);
                  setState(() { selectedTeacherId = v; selectedTeacherName = (t.data() as Map)["name"]; });
                },
              );
            },
          ),
          const SizedBox(height: 15),

          TextField(controller: startCtrl, decoration: const InputDecoration(labelText: "Start Time (09:00 AM)")),
          const SizedBox(height: 15),
          TextField(controller: endCtrl,   decoration: const InputDecoration(labelText: "End Time (10:00 AM)")),
          const SizedBox(height: 30),

          SizedBox(height: 50,
            child: ElevatedButton(
              onPressed: isLoading ? null : save,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A5F),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text("ADD TIMETABLE", style: GoogleFonts.montserrat(
                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }
}