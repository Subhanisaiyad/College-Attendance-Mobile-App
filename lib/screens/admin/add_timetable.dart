import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class AddTimetable extends StatefulWidget {
  const AddTimetable({super.key});

  @override
  State<AddTimetable> createState() => _AddTimetableState();
}

class _AddTimetableState extends State<AddTimetable> {

  final courseController = TextEditingController();
  final divisionController = TextEditingController();
  final roomController = TextEditingController();
  final startTimeController = TextEditingController();
  final endTimeController = TextEditingController();

  String? selectedDay;
  String? selectedLecture;
  String? selectedSubjectId;
  String? selectedSubjectName;
  String? selectedTeacherId;
  String? selectedTeacherName;

  bool isLoading = false;

  Future<void> saveTimetable() async {

    if (courseController.text.isEmpty ||
        divisionController.text.isEmpty ||
        roomController.text.isEmpty ||
        selectedDay == null ||
        selectedLecture == null ||
        selectedSubjectId == null ||
        selectedTeacherId == null ||
        startTimeController.text.isEmpty ||
        endTimeController.text.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    setState(() => isLoading = true);

    await FirebaseFirestore.instance.collection("timetable").add({
      "course": courseController.text.trim(),
      "division": divisionController.text.trim(),
      "room": roomController.text.trim(),
      "day": selectedDay,
      "lectureNo": int.parse(selectedLecture!),
      "subjectId": selectedSubjectId,
      "subjectName": selectedSubjectName,
      "teacherId": selectedTeacherId,
      "teacherName": selectedTeacherName,
      "startTime": startTimeController.text.trim(),
      "endTime": endTimeController.text.trim(),
      "createdAt": Timestamp.now(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Timetable Saved")),
    );

    Navigator.pop(context);

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Add Timetable",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E3A5F),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [

            TextField(
              controller: courseController,
              decoration: const InputDecoration(
                labelText: "Course ",
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: divisionController,
              decoration: const InputDecoration(
                labelText: "Division (A/B/C)",
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: roomController,
              decoration: const InputDecoration(
                labelText: "Class / Lab (Ex: Class-10 or Lab-01)",
              ),
            ),

            const SizedBox(height: 15),

            DropdownButtonFormField<String>(
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

            const SizedBox(height: 15),

            DropdownButtonFormField<String>(
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

            const SizedBox(height: 15),

            // SUBJECT DROPDOWN
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("subjects")
                  .snapshots(),
              builder: (context, snapshot) {

                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                return DropdownButtonFormField<String>(
                  decoration:
                  const InputDecoration(labelText: "Subject"),
                  items: snapshot.data!.docs.map((doc) {
                    return DropdownMenuItem<String>(
                      value: doc.id,
                      child: Text(doc["subjectName"]),
                    );
                  }).toList(),
                  onChanged: (value) {
                    var subject = snapshot.data!.docs
                        .firstWhere((doc) => doc.id == value);

                    setState(() {
                      selectedSubjectId = value;
                      selectedSubjectName = subject["subjectName"];
                    });
                  },
                );
              },
            ),

            const SizedBox(height: 15),

            // TEACHER DROPDOWN
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("teachers")
                  .snapshots(),
              builder: (context, snapshot) {

                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                return DropdownButtonFormField<String>(
                  decoration:
                  const InputDecoration(labelText: "Teacher Name"),
                  items: snapshot.data!.docs.map((doc) {
                    return DropdownMenuItem<String>(
                      value: doc.id,
                      child: Text(doc["name"]),
                    );
                  }).toList(),
                  onChanged: (value) {
                    var teacher = snapshot.data!.docs
                        .firstWhere((doc) => doc.id == value);

                    setState(() {
                      selectedTeacherId = value;
                      selectedTeacherName = teacher["name"];
                    });
                  },
                );
              },
            ),

            const SizedBox(height: 15),

            TextField(
              controller: startTimeController,
              decoration: const InputDecoration(
                labelText: "Start Time (09:00 AM)",
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: endTimeController,
              decoration: const InputDecoration(
                labelText: "End Time (10:00 AM)",
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : saveTimetable,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A5F),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text("ADD TIMETABLE",
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white
                ),),
              ),
            ),
          ],
        ),
      ),
    );
  }
}