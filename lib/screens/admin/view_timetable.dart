import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewTimetable extends StatefulWidget {
  final String collegeId; // ✅
  const ViewTimetable({super.key, required this.collegeId});

  @override
  State<ViewTimetable> createState() => _ViewTimetableState();
}

class _ViewTimetableState extends State<ViewTimetable> {
  String selectedCourse   = "All";
  String selectedDivision = "All";

  Color _typeColor(String type) =>
      type == "LAB" ? Colors.green.shade700 : const Color(0xFF1E3A5F);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("View Timetable", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E3A5F),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            DropdownButtonFormField<String>(
              value: selectedCourse,
              decoration: const InputDecoration(labelText: "Select Course"),
              items: const [
                DropdownMenuItem(value: "All",  child: Text("All")),
                DropdownMenuItem(value: "MCA",  child: Text("MCA")),
                DropdownMenuItem(value: "BCA",  child: Text("BCA")),
                DropdownMenuItem(value: "MSIT", child: Text("MSIT")),
                DropdownMenuItem(value: "BSIT", child: Text("BSIT")),
              ],
              onChanged: (v) => setState(() => selectedCourse = v!),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedDivision,
              decoration: const InputDecoration(labelText: "Select Division"),
              items: const [
                DropdownMenuItem(value: "All", child: Text("All")),
                DropdownMenuItem(value: "A",   child: Text("A")),
                DropdownMenuItem(value: "B",   child: Text("B")),
                DropdownMenuItem(value: "C",   child: Text("C")),
              ],
              onChanged: (v) => setState(() => selectedDivision = v!),
            ),
          ]),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("timetable")
                .where("collegeId", isEqualTo: widget.collegeId) // ✅
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              final filtered = snapshot.data!.docs.where((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final cm = selectedCourse   == "All" || (d["course"]   ?? "") == selectedCourse;
                final dm = selectedDivision == "All" || (d["division"] ?? "") == selectedDivision;
                return cm && dm;
              }).toList();

              if (filtered.isEmpty) return const Center(child: Text("No Timetable Found"));

              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final d    = filtered[index].data() as Map<String, dynamic>;
                  final type = d["lectureType"] as String? ?? "LEC";
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _typeColor(type).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(type, style: TextStyle(
                            color: _typeColor(type), fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      title: Text("${d["subjectName"]} (${d["course"]}-${d["division"]})",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text("Day: ${d["day"]}  ·  Lecture: ${d["lectureNo"]}"),
                        Text("Teacher: ${d["teacherName"] ?? "-"}"),
                        Text("Room: ${d["room"]}  ·  ${d["startTime"]} - ${d["endTime"]}"),
                      ]),
                      trailing: PopupMenuButton(
                        onSelected: (value) {
                          if (value == "edit") {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => EditTimetable(docId: filtered[index].id, data: filtered[index]),
                            ));
                          }
                          if (value == "delete") {
                            FirebaseFirestore.instance.collection("timetable").doc(filtered[index].id).delete();
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: "edit",   child: Text("Edit")),
                          PopupMenuItem(value: "delete", child: Text("Delete")),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

class EditTimetable extends StatefulWidget {
  final String docId;
  final QueryDocumentSnapshot data;
  const EditTimetable({super.key, required this.docId, required this.data});

  @override
  State<EditTimetable> createState() => _EditTimetableState();
}

class _EditTimetableState extends State<EditTimetable> {
  late TextEditingController courseCtrl, divisionCtrl, roomCtrl, startCtrl, endCtrl;
  String? selectedDay, selectedLecture;
  String  selectedType = "LEC";

  static const _types = [
    {"value": "LEC", "label": "LEC — Lecture"},
    {"value": "LAB", "label": "LAB — Laboratory"},
  ];

  Color _typeColor(String t) =>
      t == "LAB" ? Colors.green.shade700 : const Color(0xFF1E3A5F);

  @override
  void initState() {
    super.initState();
    final d = widget.data.data() as Map<String, dynamic>;
    courseCtrl   = TextEditingController(text: d["course"]    ?? "");
    divisionCtrl = TextEditingController(text: d["division"]  ?? "");
    roomCtrl     = TextEditingController(text: d["room"]      ?? "");
    startCtrl    = TextEditingController(text: d["startTime"] ?? "");
    endCtrl      = TextEditingController(text: d["endTime"]   ?? "");
    selectedDay     = d["day"];
    selectedLecture = d["lectureNo"]?.toString();
    selectedType    = d["lectureType"] as String? ?? "LEC";
  }

  Future<void> update() async {
    await FirebaseFirestore.instance.collection("timetable").doc(widget.docId).update({
      "course":      courseCtrl.text.trim(),
      "division":    divisionCtrl.text.trim(),
      "room":        roomCtrl.text.trim(),
      "day":         selectedDay,
      "lectureNo":   int.parse(selectedLecture ?? "1"),
      "lectureType": selectedType,
      "startTime":   startCtrl.text.trim(),
      "endTime":     endCtrl.text.trim(),
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Timetable", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E3A5F),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          _f(courseCtrl,   "Course"),    const SizedBox(height: 10),
          _f(divisionCtrl, "Division"),  const SizedBox(height: 10),
          _f(roomCtrl,     "Room/Lab"),  const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: selectedDay,
            decoration: const InputDecoration(labelText: "Day"),
            items: ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
                .map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
            onChanged: (v) => setState(() => selectedDay = v),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: selectedLecture,
            decoration: const InputDecoration(labelText: "Lecture No"),
            items: List.generate(6, (i) => DropdownMenuItem(
                value: "${i+1}", child: Text("Lecture ${i+1}"))),
            onChanged: (v) => setState(() => selectedLecture = v),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: selectedType,
            decoration: const InputDecoration(labelText: "Lecture Type",
                prefixIcon: Icon(Icons.category_outlined, color: Color(0xFF1E3A5F))),
            items: _types.map((t) => DropdownMenuItem(
              value: t["value"],
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _typeColor(t["value"]!).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(t["value"]!, style: TextStyle(
                      color: _typeColor(t["value"]!), fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(width: 10),
                Text(t["label"]!.split("—").last.trim()),
              ]),
            )).toList(),
            onChanged: (v) => setState(() => selectedType = v!),
          ),
          const SizedBox(height: 10),
          _f(startCtrl, "Start Time"), const SizedBox(height: 10),
          _f(endCtrl,   "End Time"),   const SizedBox(height: 30),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: update,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A5F),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text("Update Timetable",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _f(TextEditingController c, String l) =>
      TextField(controller: c, decoration: InputDecoration(labelText: l));
}