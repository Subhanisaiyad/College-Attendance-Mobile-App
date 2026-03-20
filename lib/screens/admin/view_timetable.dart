import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewTimetable extends StatefulWidget {
  const ViewTimetable({super.key});

  @override
  State<ViewTimetable> createState() => _ViewTimetableState();
}

class _ViewTimetableState extends State<ViewTimetable> {

  String selectedCourse = "All";
  String selectedDivision = "All";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "View Timetable",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E3A5F),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [

          // FILTER SECTION
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [

                DropdownButtonFormField<String>(
                  value: selectedCourse,
                  decoration: const InputDecoration(
                    labelText: "Select Course",
                  ),
                  items: const [

                    DropdownMenuItem(
                        value: "All",
                        child: Text("All")),

                    DropdownMenuItem(
                        value: "MCA",
                        child: Text("MCA")),

                    DropdownMenuItem(
                        value: "BCA",
                        child: Text("BCA")),

                    DropdownMenuItem(
                        value: "MSIT",
                        child: Text("MSIT")),

                    DropdownMenuItem(
                        value: "BSIT",
                        child: Text("BSIT")),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedCourse = value!;
                    });
                  },
                ),

                const SizedBox(height: 10),

                DropdownButtonFormField<String>(
                  value: selectedDivision,
                  decoration:
                  const InputDecoration(labelText: "Select Division"),
                  items: const [
                    DropdownMenuItem(value: "All", child: Text("All")),
                    DropdownMenuItem(value: "A", child: Text("A")),
                    DropdownMenuItem(value: "B", child: Text("B")),
                    DropdownMenuItem(value: "C", child: Text("C")),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedDivision = value!;
                    });
                  },
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("timetable")
                  .orderBy("day")
                  .snapshots(),
              builder: (context, snapshot) {

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snapshot.data!.docs;

                var filteredDocs = docs.where((doc) {

                  bool courseMatch = selectedCourse == "All" ||
                      doc["course"] == selectedCourse;

                  bool divisionMatch = selectedDivision == "All" ||
                      doc["division"] == selectedDivision;

                  return courseMatch && divisionMatch;

                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(child: Text("No Timetable Found"));
                }

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {

                    var data = filteredDocs[index];

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: ListTile(
                        title: Text(
                          "${data["subjectName"]} (${data["course"]}-${data["division"]})",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Day: ${data["day"]}"),
                            Text("Lecture: ${data["lectureNo"]}"),
                            Text("Teacher: ${data["teacherName"]}"),
                            Text("Room: ${data["room"]}"),
                            Text(
                                "Time: ${data["startTime"]} - ${data["endTime"]}"),
                          ],
                        ),
                        trailing: PopupMenuButton(
                          onSelected: (value) {

                            if (value == "edit") {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EditTimetable(
                                    docId: data.id,
                                    data: data,
                                  ),
                                ),
                              );
                            }

                            if (value == "delete") {
                              FirebaseFirestore.instance
                                  .collection("timetable")
                                  .doc(data.id)
                                  .delete();
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
                      ),
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
}

////////////////////////////////////////////////////////////
/// EDIT TIMETABLE PAGE
////////////////////////////////////////////////////////////

class EditTimetable extends StatefulWidget {
  final String docId;
  final QueryDocumentSnapshot data;

  const EditTimetable({
    super.key,
    required this.docId,
    required this.data,
  });

  @override
  State<EditTimetable> createState() => _EditTimetableState();
}

class _EditTimetableState extends State<EditTimetable> {

  late TextEditingController courseController;
  late TextEditingController divisionController;
  late TextEditingController roomController;
  late TextEditingController startController;
  late TextEditingController endController;

  String? selectedDay;
  String? selectedLecture;
  String? selectedSubjectId;
  String? selectedSubjectName;
  String? selectedTeacherId;
  String? selectedTeacherName;

  @override
  void initState() {
    super.initState();

    courseController =
        TextEditingController(text: widget.data["course"]);
    divisionController =
        TextEditingController(text: widget.data["division"]);
    roomController =
        TextEditingController(text: widget.data["room"]);
    startController =
        TextEditingController(text: widget.data["startTime"]);
    endController =
        TextEditingController(text: widget.data["endTime"]);

    selectedDay = widget.data["day"];
    selectedLecture = widget.data["lectureNo"].toString();
    selectedSubjectId = widget.data["subjectId"];
    selectedTeacherId = widget.data["teacherId"];
  }

  Future<void> updateTimetable() async {

    await FirebaseFirestore.instance
        .collection("timetable")
        .doc(widget.docId)
        .update({
      "course": courseController.text.trim(),
      "division": divisionController.text.trim(),
      "room": roomController.text.trim(),
      "day": selectedDay,
      "lectureNo": int.parse(selectedLecture!),
      "subjectId": selectedSubjectId,
      "teacherId": selectedTeacherId,
      "startTime": startController.text.trim(),
      "endTime": endController.text.trim(),
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Edit Timetable",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E3A5F),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            TextField(
              controller: courseController,
              decoration: const InputDecoration(labelText: "Course"),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: divisionController,
              decoration: const InputDecoration(labelText: "Division"),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: roomController,
              decoration: const InputDecoration(labelText: "Room"),
            ),

            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              value: selectedDay,
              decoration: const InputDecoration(labelText: "Day"),
              items: const [
                DropdownMenuItem(value: "Monday", child: Text("Monday")),
                DropdownMenuItem(value: "Tuesday", child: Text("Tuesday")),
                DropdownMenuItem(value: "Wednesday", child: Text("Wednesday")),
                DropdownMenuItem(value: "Thursday", child: Text("Thursday")),
                DropdownMenuItem(value: "Friday", child: Text("Friday")),
                DropdownMenuItem(value: "Saturday", child: Text("Saturday")),
              ],
              onChanged: (value) {
                setState(() {
                  selectedDay = value;
                });
              },
            ),

            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              value: selectedLecture,
              decoration: const InputDecoration(labelText: "Lecture No"),
              items: List.generate(
                6,
                    (index) => DropdownMenuItem(
                  value: "${index + 1}",
                  child: Text("Lecture ${index + 1}"),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  selectedLecture = value;
                });
              },
            ),

            const SizedBox(height: 10),

            TextField(
              controller: startController,
              decoration: const InputDecoration(labelText: "Start Time"),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: endController,
              decoration: const InputDecoration(labelText: "End Time"),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: updateTimetable,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E3A5F),
                  side: const BorderSide(color: Color(0xFF1E3A5F)),
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