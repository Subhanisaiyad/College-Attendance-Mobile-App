import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewTeachers extends StatelessWidget {
  final String collegeId;
  const ViewTeachers({super.key, required this.collegeId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("All Teachers", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E3A5F),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("teachers")
            .where("collegeId", isEqualTo: collegeId) // ✅
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No Teachers Found"));

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final teacher = snapshot.data!.docs[index];
              final d = teacher.data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(d["name"] ?? "", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        PopupMenuButton(
                          onSelected: (value) {
                            if (value == "edit") {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => EditTeacher(teacherId: teacher.id, data: teacher),
                              ));
                            }
                            if (value == "delete") {
                              showDialog(context: context, builder: (_) => AlertDialog(
                                title: const Text("Delete Teacher"),
                                content: const Text("Are you sure?"),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                                  TextButton(
                                    onPressed: () {
                                      FirebaseFirestore.instance.collection("teachers").doc(teacher.id).delete();
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
                    const SizedBox(height: 8),
                    Text("Email: ${d["email"] ?? "-"}"),
                    Text("Contact: ${d["contact"] ?? "-"}"),
                    Text("Username: ${d["username"] ?? "-"}"),
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

class EditTeacher extends StatefulWidget {
  final String teacherId;
  final QueryDocumentSnapshot data;
  const EditTeacher({super.key, required this.teacherId, required this.data});

  @override
  State<EditTeacher> createState() => _EditTeacherState();
}

class _EditTeacherState extends State<EditTeacher> {
  late TextEditingController nameCtrl, emailCtrl, contactCtrl;

  @override
  void initState() {
    super.initState();
    final d = widget.data.data() as Map<String, dynamic>;
    nameCtrl    = TextEditingController(text: d["name"]    ?? "");
    emailCtrl   = TextEditingController(text: d["email"]   ?? "");
    contactCtrl = TextEditingController(text: d["contact"] ?? "");
  }

  Future<void> update() async {
    await FirebaseFirestore.instance.collection("teachers").doc(widget.teacherId).update({
      "name":    nameCtrl.text.trim(),
      "email":   emailCtrl.text.trim(),
      "contact": contactCtrl.text.trim(),
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Teacher", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E3A5F),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          TextField(controller: nameCtrl,    decoration: const InputDecoration(labelText: "Name")),
          const SizedBox(height: 15),
          TextField(controller: emailCtrl,   decoration: const InputDecoration(labelText: "Email")),
          const SizedBox(height: 15),
          TextField(controller: contactCtrl, decoration: const InputDecoration(labelText: "Contact")),
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