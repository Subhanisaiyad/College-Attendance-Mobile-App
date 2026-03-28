import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewSubjectsPage extends StatelessWidget {
  final String collegeId; // ✅
  const ViewSubjectsPage({super.key, required this.collegeId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("All Subjects", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E3A5F),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("subjects")
            .where("collegeId", isEqualTo: collegeId) // ✅
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No Subjects Found"));

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final subject = snapshot.data!.docs[index];
              final d = subject.data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(d["subjectName"] ?? "",
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                        PopupMenuButton(
                          onSelected: (value) {
                            if (value == "edit") {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => EditSubject(subjectId: subject.id, data: subject),
                              ));
                            }
                            if (value == "delete") {
                              showDialog(context: context, builder: (_) => AlertDialog(
                                title: const Text("Delete Subject"),
                                content: const Text("Are you sure?"),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                                  TextButton(
                                    onPressed: () {
                                      FirebaseFirestore.instance.collection("subjects").doc(subject.id).delete();
                                      Navigator.pop(context);
                                    },
                                    child: const Text("Delete", style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ));
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: "edit",   child: Text("Edit")),
                            PopupMenuItem(value: "delete", child: Text("Delete")),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text("Code: ${d["subjectCode"] ?? "-"}"),
                    Text("Department: ${d["department"] ?? "-"}"),
                    Text("Semester: ${d["semester"] ?? "-"}"),
                    Text("Credits: ${d["credits"] ?? "-"}"),
                    Text("Teacher: ${d["teacherName"] ?? "-"}"),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class EditSubject extends StatefulWidget {
  final String subjectId;
  final QueryDocumentSnapshot data;
  const EditSubject({super.key, required this.subjectId, required this.data});

  @override
  State<EditSubject> createState() => _EditSubjectState();
}

class _EditSubjectState extends State<EditSubject> {
  late TextEditingController nameCtrl, codeCtrl, deptCtrl, creditsCtrl;
  String? selectedSemester;

  @override
  void initState() {
    super.initState();
    final d = widget.data.data() as Map<String, dynamic>;
    nameCtrl    = TextEditingController(text: d["subjectName"] ?? "");
    codeCtrl    = TextEditingController(text: d["subjectCode"] ?? "");
    deptCtrl    = TextEditingController(text: d["department"]  ?? "");
    creditsCtrl = TextEditingController(text: d["credits"]     ?? "");
    selectedSemester = d["semester"];
  }

  Future<void> update() async {
    await FirebaseFirestore.instance.collection("subjects").doc(widget.subjectId).update({
      "subjectName": nameCtrl.text.trim(),
      "subjectCode": codeCtrl.text.trim(),
      "department":  deptCtrl.text.trim(),
      "credits":     creditsCtrl.text.trim(),
      "semester":    selectedSemester,
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Subject", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E3A5F),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Subject Name")),
          const SizedBox(height: 10),
          TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: "Subject Code")),
          const SizedBox(height: 10),
          TextField(controller: deptCtrl, decoration: const InputDecoration(labelText: "Department")),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: selectedSemester,
            decoration: const InputDecoration(labelText: "Semester"),
            items: List.generate(8, (i) => DropdownMenuItem(
                value: "Semester ${i + 1}", child: Text("Semester ${i + 1}"))),
            onChanged: (v) => setState(() => selectedSemester = v),
          ),
          const SizedBox(height: 10),
          TextField(controller: creditsCtrl, decoration: const InputDecoration(labelText: "Credits")),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: update,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Update", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }
}