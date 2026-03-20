import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class AddSubject extends StatefulWidget {
  const AddSubject({super.key});

  @override
  State<AddSubject> createState() => _AddSubjectState();
}

class _AddSubjectState extends State<AddSubject> {

  final _formKey = GlobalKey<FormState>();

  final subjectNameController = TextEditingController();
  final subjectCodeController = TextEditingController();
  final departmentController = TextEditingController();
  final creditsController = TextEditingController();

  String? selectedSemester;
  String? selectedTeacherId;
  String? selectedTeacherName;

  bool isLoading = false;

  Future<void> saveSubject() async {

    if (!_formKey.currentState!.validate()) return;

    if (selectedTeacherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a teacher")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {

      // 🔎 Duplicate Subject Code Check
      final checkCode = await FirebaseFirestore.instance
          .collection("subjects")
          .where("subjectCode", isEqualTo: subjectCodeController.text.trim())
          .get();

      if (checkCode.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Subject Code already exists")),
        );
        setState(() => isLoading = false);
        return;
      }

      await FirebaseFirestore.instance.collection("subjects").add({
        "subjectName": subjectNameController.text.trim(),
        "subjectCode": subjectCodeController.text.trim(),
        "department": departmentController.text.trim(),
        "semester": selectedSemester,
        "credits": creditsController.text.trim(),
        "teacherId": selectedTeacherId,
        "teacherName": selectedTeacherName,
        "createdAt": Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Subject Added Successfully")),
      );

      Navigator.pop(context);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E6),

      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Add Subject",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [

              const SizedBox(height: 20),

              // Subject Name
              TextFormField(
                controller: subjectNameController,
                decoration: buildInput("Subject Name", Icons.book),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Enter subject name";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Subject Code
              TextFormField(
                controller: subjectCodeController,
                decoration: buildInput("Subject Code", Icons.code),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Enter subject code";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Department
              TextFormField(
                controller: departmentController,
                decoration: buildInput("Department", Icons.school),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Enter department";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Semester Dropdown
              DropdownButtonFormField<String>(
                value: selectedSemester,
                decoration: buildInput("Semester", Icons.calendar_today),
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
                validator: (value) =>
                value == null ? "Select semester" : null,
              ),

              const SizedBox(height: 20),

              // Credits
              TextFormField(
                controller: creditsController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: buildInput("Credits", Icons.numbers),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Enter credits";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Teacher Dropdown
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
                    buildInput("Assign Teacher", Icons.person),
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
                    validator: (value) =>
                    value == null ? "Select teacher" : null,
                  );
                },
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: isLoading ? null : saveSubject,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A5F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                    "ADD SUBJECT",
                    style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration buildInput(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
      ),
    );
  }
}