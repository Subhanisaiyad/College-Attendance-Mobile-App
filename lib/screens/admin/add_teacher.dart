import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddTeacher extends StatefulWidget {
  final String collegeId; // ✅

  const AddTeacher({super.key, required this.collegeId});

  @override
  State<AddTeacher> createState() => _AddTeacherState();
}

class _AddTeacherState extends State<AddTeacher> {
  final _formKey         = GlobalKey<FormState>();
  final nameCtrl         = TextEditingController();
  final emailCtrl        = TextEditingController();
  final contactCtrl      = TextEditingController();
  final usernameCtrl     = TextEditingController();
  final passwordCtrl     = TextEditingController();
  bool isLoading         = false;

  Future<void> saveTeacher() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);

    try {
      // Check duplicate username within same college
      final check = await FirebaseFirestore.instance
          .collection("teachers")
          .where("username",  isEqualTo: usernameCtrl.text.trim())
          .where("collegeId", isEqualTo: widget.collegeId)
          .get();

      if (check.docs.isNotEmpty) {
        _snack("Username already exists");
        setState(() => isLoading = false);
        return;
      }

      await FirebaseFirestore.instance.collection("teachers").add({
        "name":      nameCtrl.text.trim(),
        "email":     emailCtrl.text.trim(),
        "contact":   contactCtrl.text.trim(),
        "username":  usernameCtrl.text.trim(),
        "password":  passwordCtrl.text.trim(),
        "role":      "teacher",
        "collegeId": widget.collegeId, // ✅
        "createdAt": Timestamp.now(),
      });

      _snack("Teacher Added Successfully");
      if (mounted) Navigator.pop(context);

    } catch (e) {
      _snack("Error: $e");
    }

    setState(() => isLoading = false);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Add Teacher",
            style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(children: [
            const SizedBox(height: 20),

            TextFormField(
              controller: nameCtrl,
              decoration: _input("Teacher Name", Icons.person),
              validator: (v) =>
              v == null || v.trim().isEmpty ? "Enter teacher name" : null,
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: emailCtrl,
              decoration: _input("Email", Icons.email),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) return "Enter email";
                if (!RegExp(r'^[\w.]+@[\w.]+\.[a-z]{2,}$').hasMatch(v.trim()))
                  return "Enter valid email";
                return null;
              },
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: contactCtrl,
              decoration: _input("Contact Number", Icons.phone),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              validator: (v) {
                if (v == null || v.isEmpty) return "Enter contact";
                if (v.length != 10) return "Must be 10 digits";
                return null;
              },
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: usernameCtrl,
              decoration: _input("Username", Icons.account_circle),
              validator: (v) =>
              v == null || v.isEmpty ? "Enter username" : null,
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: passwordCtrl,
              decoration: _input("Password", Icons.lock),
              validator: (v) {
                if (v == null || v.isEmpty) return "Enter password";
                if (v.length < 6) return "Min 6 characters";
                return null;
              },
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: isLoading ? null : saveTeacher,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A5F),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text("ADD TEACHER",
                    style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  InputDecoration _input(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
  );
}