import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewSubjects extends StatelessWidget {
  const ViewSubjects({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("All Subjects",
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E3A5F),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("subjects")
            .orderBy("createdAt", descending: true)
            .snapshots(),
        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No Subjects Found"));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {

              var subject = snapshot.data!.docs[index];

              return Card(
                margin:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [

                          Text(
                            subject["subjectName"],
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),

                          PopupMenuButton(
                            onSelected: (value) {
                              if (value == "edit") {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EditSubject(
                                      subjectId: subject.id,
                                      data: subject,
                                    ),
                                  ),
                                );
                              }

                              if (value == "delete") {
                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title:
                                    const Text("Delete Subject"),
                                    content: const Text(
                                        "Are you sure you want to delete?"),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context),
                                        child:
                                        const Text("Cancel"),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          FirebaseFirestore.instance
                                              .collection("subjects")
                                              .doc(subject.id)
                                              .delete();
                                          Navigator.pop(context);
                                        },
                                        child: const Text(
                                          "Delete",
                                          style: TextStyle(
                                              color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: "edit",
                                child: Text("Edit"),
                              ),
                              PopupMenuItem(
                                value: "delete",
                                child: Text("Delete"),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      Text("Code: ${subject["subjectCode"]}"),
                      Text("Department: ${subject["department"]}"),
                      Text("Semester: ${subject["semester"]}"),
                      Text("Credits: ${subject["credits"]}"),
                      Text("Teacher: ${subject["teacherName"]}"),

                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// EDIT SUBJECT PAGE
////////////////////////////////////////////////////////////

class EditSubject extends StatefulWidget {
  final String subjectId;
  final QueryDocumentSnapshot data;

  const EditSubject({
    super.key,
    required this.subjectId,
    required this.data,
  });

  @override
  State<EditSubject> createState() => _EditSubjectState();
}

class _EditSubjectState extends State<EditSubject> {

  late TextEditingController nameController;
  late TextEditingController codeController;
  late TextEditingController departmentController;
  late TextEditingController creditsController;

  String? selectedSemester;

  @override
  void initState() {
    super.initState();

    nameController =
        TextEditingController(text: widget.data["subjectName"]);
    codeController =
        TextEditingController(text: widget.data["subjectCode"]);
    departmentController =
        TextEditingController(text: widget.data["department"]);
    creditsController =
        TextEditingController(text: widget.data["credits"]);
    selectedSemester = widget.data["semester"];
  }

  Future<void> updateSubject() async {

    await FirebaseFirestore.instance
        .collection("subjects")
        .doc(widget.subjectId)
        .update({
      "subjectName": nameController.text.trim(),
      "subjectCode": codeController.text.trim(),
      "department": departmentController.text.trim(),
      "credits": creditsController.text.trim(),
      "semester": selectedSemester,
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
        const Text("Edit Subject",
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E3A5F),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            TextField(
              controller: nameController,
              decoration:
              const InputDecoration(labelText: "Subject Name"),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: codeController,
              decoration:
              const InputDecoration(labelText: "Subject Code"),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: departmentController,
              decoration:
              const InputDecoration(labelText: "Department"),
            ),

            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              value: selectedSemester,
              decoration:
              const InputDecoration(labelText: "Semester"),
              items: List.generate(
                8,
                    (index) => DropdownMenuItem(
                  value: "Semester ${index + 1}",
                  child: Text("Semester ${index + 1}"),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  selectedSemester = value;
                });
              },
            ),

            const SizedBox(height: 10),

            TextField(
              controller: creditsController,
              decoration:
              const InputDecoration(labelText: "Credits"),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: updateSubject,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E3A5F),
                  side: const BorderSide(
                    color: Color(0xFF1E3A5F),
                  ),
                ),
                child: const Text("Update"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}