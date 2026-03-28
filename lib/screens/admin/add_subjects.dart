import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class AddSubject extends StatefulWidget {
  final String collegeId; // ✅
  const AddSubject({super.key, required this.collegeId});

  @override
  State<AddSubject> createState() => _AddSubjectState();
}

class _AddSubjectState extends State<AddSubject> {
  final _formKey            = GlobalKey<FormState>();
  final subjectNameCtrl     = TextEditingController();
  final subjectCodeCtrl     = TextEditingController();
  final departmentCtrl      = TextEditingController();
  final creditsCtrl         = TextEditingController();
  String? selectedSemester, selectedTeacherId, selectedTeacherName;
  bool isLoading = false;

  Future<void> saveSubject() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedTeacherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a teacher")));
      return;
    }
    setState(() => isLoading = true);
    try {
      // Duplicate check within same college
      final check = await FirebaseFirestore.instance
          .collection("subjects")
          .where("subjectCode", isEqualTo: subjectCodeCtrl.text.trim())
          .where("collegeId",   isEqualTo: widget.collegeId) // ✅
          .get();
      if (check.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Subject Code already exists")));
        setState(() => isLoading = false);
        return;
      }
      await FirebaseFirestore.instance.collection("subjects").add({
        "subjectName":  subjectNameCtrl.text.trim(),
        "subjectCode":  subjectCodeCtrl.text.trim(),
        "department":   departmentCtrl.text.trim(),
        "semester":     selectedSemester,
        "credits":      creditsCtrl.text.trim(),
        "teacherId":    selectedTeacherId,
        "teacherName":  selectedTeacherName,
        "collegeId":    widget.collegeId, // ✅
        "createdAt":    Timestamp.now(),
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Subject Added Successfully")));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
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
        title: const Text("Add Subject", style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(key: _formKey, child: Column(children: [
          const SizedBox(height: 20),
          TextFormField(controller: subjectNameCtrl, decoration: _inp("Subject Name", Icons.book),
              validator: (v) => v == null || v.trim().isEmpty ? "Enter subject name" : null),
          const SizedBox(height: 20),
          TextFormField(controller: subjectCodeCtrl, decoration: _inp("Subject Code", Icons.code),
              validator: (v) => v == null || v.trim().isEmpty ? "Enter subject code" : null),
          const SizedBox(height: 20),
          TextFormField(controller: departmentCtrl, decoration: _inp("Department", Icons.school),
              validator: (v) => v == null || v.trim().isEmpty ? "Enter department" : null),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: selectedSemester,
            decoration: _inp("Semester", Icons.calendar_today),
            items: List.generate(8, (i) => DropdownMenuItem(
                value: "Semester ${i + 1}", child: Text("Semester ${i + 1}"))),
            onChanged: (v) => setState(() => selectedSemester = v),
            validator: (v) => v == null ? "Select semester" : null,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: creditsCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _inp("Credits", Icons.numbers),
            validator: (v) => v == null || v.isEmpty ? "Enter credits" : null,
          ),
          const SizedBox(height: 20),
          // ✅ Filter teachers by collegeId
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("teachers")
                .where("collegeId", isEqualTo: widget.collegeId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              return DropdownButtonFormField<String>(
                decoration: _inp("Assign Teacher", Icons.person),
                items: snapshot.data!.docs.map((doc) => DropdownMenuItem<String>(
                    value: doc.id, child: Text((doc.data() as Map)["name"] ?? ""))).toList(),
                onChanged: (v) {
                  final t = snapshot.data!.docs.firstWhere((doc) => doc.id == v);
                  setState(() { selectedTeacherId = v; selectedTeacherName = (t.data() as Map)["name"]; });
                },
                validator: (v) => v == null ? "Select teacher" : null,
              );
            },
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity, height: 55,
            child: ElevatedButton(
              onPressed: isLoading ? null : saveSubject,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A5F),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text("ADD SUBJECT", style: GoogleFonts.montserrat(
                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ])),
      ),
    );
  }

  InputDecoration _inp(String label, IconData icon) => InputDecoration(
    labelText: label, prefixIcon: Icon(icon),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
  );
}