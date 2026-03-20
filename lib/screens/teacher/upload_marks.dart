import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UploadMarks extends StatefulWidget {
  final String course;
  final String division;
  final String subject;
  final String teacherId; // ✅ teacherId added

  const UploadMarks({
    super.key,
    required this.course,
    required this.division,
    required this.subject,
    required this.teacherId,
  });

  @override
  State<UploadMarks> createState() => _UploadMarksState();
}

class _UploadMarksState extends State<UploadMarks> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _subjectCtrl;
  late TextEditingController _courseCtrl;
  late TextEditingController _divisionCtrl;
  final TextEditingController _examTypeCtrl   = TextEditingController();
  final TextEditingController _totalMarksCtrl = TextEditingController();
  final TextEditingController _dateCtrl       = TextEditingController();

  bool _formSubmitted = false;
  Map<String, TextEditingController> marksControllers = {};
  Map<String, String> studentNames = {}; // ✅ id → name
  bool isSaving = false;

  late String _confirmedSubject;
  late String _confirmedCourse;
  late String _confirmedDivision;
  late String _confirmedExamType;
  late String _confirmedTotalMarks;
  late String _confirmedDate;

  @override
  void initState() {
    super.initState();
    _subjectCtrl  = TextEditingController(text: widget.subject);
    _courseCtrl   = TextEditingController(text: widget.course);
    _divisionCtrl = TextEditingController(text: widget.division);
    _dateCtrl.text = _today();
  }

  String _today() {
    final now = DateTime.now();
    return "${now.day.toString().padLeft(2,'0')}-"
        "${now.month.toString().padLeft(2,'0')}-${now.year}";
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _courseCtrl.dispose();
    _divisionCtrl.dispose();
    _examTypeCtrl.dispose();
    _totalMarksCtrl.dispose();
    _dateCtrl.dispose();
    for (var c in marksControllers.values) c.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _confirmedSubject    = _subjectCtrl.text.trim();
        _confirmedCourse     = _courseCtrl.text.trim();
        _confirmedDivision   = _divisionCtrl.text.trim();
        _confirmedExamType   = _examTypeCtrl.text.trim();
        _confirmedTotalMarks = _totalMarksCtrl.text.trim();
        _confirmedDate       = _dateCtrl.text.trim();
        _formSubmitted       = true;
      });
    }
  }

  Future<void> saveMarks() async {
    bool anyEmpty =
    marksControllers.values.any((c) => c.text.trim().isEmpty);
    if (anyEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter marks for all students"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      for (var entry in marksControllers.entries) {
        // Student ka naam dhundo
        final String studentName = studentNames[entry.key] ?? "";
        await FirebaseFirestore.instance.collection("marks").add({
          "studentId":   entry.key,
          "studentName": studentName,  // ✅ Name save karo
          "marks":       entry.value.text.trim(),
          "totalMarks":  _confirmedTotalMarks,
          "examType":    _confirmedExamType,
          "course":      _confirmedCourse,
          "division":    _confirmedDivision,
          "subject":     _confirmedSubject,
          "date":        _confirmedDate,
          "teacherId":   widget.teacherId,
          "uploadedAt":  DateTime.now().toString(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Marks Uploaded Successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Error: $e"),
              backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) setState(() => isSaving = false);
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F).withOpacity(0.07),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: Color(0xFF1E3A5F), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Fill exam details first, then enter marks for each student.",
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _sectionLabel("Subject Details"),
            const SizedBox(height: 12),
            _inputField(
              controller: _subjectCtrl,
              label: "Subject Name",
              icon: Icons.menu_book,
              validator: (v) => v!.isEmpty ? "Enter subject name" : null,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _inputField(
                    controller: _courseCtrl,
                    label: "Course",
                    icon: Icons.school,
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _inputField(
                    controller: _divisionCtrl,
                    label: "Division",
                    icon: Icons.group,
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _sectionLabel("Exam Details"),
            const SizedBox(height: 12),
            _inputField(
              controller: _examTypeCtrl,
              label: "Exam Type  (e.g. Mid-Term, Final)",
              icon: Icons.assignment,
              validator: (v) => v!.isEmpty ? "Enter exam type" : null,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _inputField(
                    controller: _totalMarksCtrl,
                    label: "Total Marks",
                    icon: Icons.score,
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _inputField(
                    controller: _dateCtrl,
                    label: "Date",
                    icon: Icons.calendar_today,
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A5F),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _submitForm,
                icon: const Icon(Icons.arrow_forward, color: Colors.white),
                label: const Text(
                  "Proceed to Enter Marks",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarksList() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A5F).withOpacity(0.07),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_confirmedSubject,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1E3A5F))),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _chip("${_confirmedCourse}-${_confirmedDivision}",
                      Icons.school),
                  _chip(_confirmedExamType, Icons.assignment),
                  _chip("Out of $_confirmedTotalMarks", Icons.score),
                  _chip(_confirmedDate, Icons.calendar_today),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("students")
                .where("course",   isEqualTo: _confirmedCourse)
                .where("division", isEqualTo: _confirmedDivision)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text(
                    "No Students Found\n$_confirmedCourse - $_confirmedDivision",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 15),
                  ),
                );
              }
              final students = snapshot.data!.docs;
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                itemCount: students.length,
                itemBuilder: (context, index) {
                  final Map<String, dynamic> sData =
                  students[index].data() as Map<String, dynamic>;
                  final String id         = students[index].id;
                  final String name       = sData["name"]       as String? ?? "Unknown";
                  final String rollNumber = sData["rollNumber"] as String? ?? "-";
                  marksControllers.putIfAbsent(id, () => TextEditingController());
                  studentNames[id] = name; // ✅ naam store karo
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 6)
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                          const Color(0xFF1E3A5F).withOpacity(0.1),
                          child: Text(name[0].toUpperCase(),
                              style: const TextStyle(
                                  color: Color(0xFF1E3A5F),
                                  fontWeight: FontWeight.bold)),
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
                              Text("Roll: $rollNumber",
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: marksControllers[id],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              hintText: "/ $_confirmedTotalMarks",
                              hintStyle: TextStyle(
                                  color: Colors.grey.shade400, fontSize: 12),
                              filled: true,
                              fillColor:
                              const Color(0xFF1E3A5F).withOpacity(0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 10),
                            ),
                          ),
                        ),
                      ],
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
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: isSaving ? null : saveMarks,
              icon: isSaving
                  ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.cloud_upload, color: Colors.white),
              label: Text(
                isSaving ? "Saving..." : "Save Marks",
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _formSubmitted ? "Enter Student Marks" : "Upload Marks",
          style: GoogleFonts.playfairDisplay(
              color: Colors.white, fontSize: 20),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (_formSubmitted) {
              setState(() => _formSubmitted = false);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF1E3A5F),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: [
                _stepDot(1, "Exam Details", !_formSubmitted),
                Expanded(
                  child: Container(
                      height: 2,
                      color: _formSubmitted ? Colors.white : Colors.white38),
                ),
                _stepDot(2, "Enter Marks", _formSubmitted),
              ],
            ),
          ),
          Expanded(
            child: _formSubmitted ? _buildMarksList() : _buildForm(),
          ),
        ],
      ),
    );
  }

  Widget _stepDot(int num, String label, bool active) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? Colors.white : Colors.white38,
          ),
          child: Center(
            child: Text("$num",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: active
                        ? const Color(0xFF1E3A5F)
                        : Colors.white60)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                color: active ? Colors.white : Colors.white54,
                fontSize: 11)),
      ],
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E3A5F)));

  Widget _chip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF1E3A5F)),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF1E3A5F),
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1E3A5F), size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}