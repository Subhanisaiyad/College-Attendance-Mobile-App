import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import 'admin/admin_dashboard.dart';
import 'teacher/teacher_dashboard.dart';
import 'student/student_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading       = false;
  bool obscurePassword = true;

  Future<void> loginUser() async {
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showSnack("Enter Username and Password");
      return;
    }

    setState(() => isLoading = true);

    try {
      // ── ADMIN LOGIN ──
      final adminQuery = await FirebaseFirestore.instance
          .collection("users")
          .where("username", isEqualTo: username)
          .where("password", isEqualTo: password)
          .get();

      if (adminQuery.docs.isNotEmpty) {
        final ad        = adminQuery.docs.first.data();
        final collegeId = ad["collegeId"] as String? ?? ""; // ✅
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => AdminDashboard(collegeId: collegeId),
        ));
        setState(() => isLoading = false);
        return;
      }

      // ── TEACHER LOGIN ──
      final teacherQuery = await FirebaseFirestore.instance
          .collection("teachers")
          .where("username", isEqualTo: username)
          .where("password", isEqualTo: password)
          .get();

      if (teacherQuery.docs.isNotEmpty) {
        final teacher   = teacherQuery.docs.first;
        final td        = teacher.data() as Map<String, dynamic>;
        final collegeId = td["collegeId"] as String? ?? ""; // ✅
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => TeacherDashboard(
            teacherId:   teacher.id,
            teacherName: td["name"] as String? ?? "",
            collegeId:   collegeId, // ✅
          ),
        ));
        setState(() => isLoading = false);
        return;
      }

      // ── STUDENT LOGIN ──
      final studentQuery = await FirebaseFirestore.instance
          .collection("students")
          .where("username", isEqualTo: username)
          .where("password", isEqualTo: password)
          .get();

      if (studentQuery.docs.isNotEmpty) {
        final student   = studentQuery.docs.first;
        final sd        = student.data() as Map<String, dynamic>;
        final collegeId = sd["collegeId"] as String? ?? ""; // ✅
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => StudentDashboard(
            studentId:   student.id,
            studentName: sd["name"]     as String? ?? "Student",
            course:      sd["course"]   as String? ?? "",
            division:    sd["division"] as String? ?? "",
            collegeId:   collegeId, // ✅
          ),
        ));
        setState(() => isLoading = false);
        return;
      }

      _showSnack("Invalid Username or Password");

    } catch (e) {
      _showSnack("Login Failed: $e");
    }

    setState(() => isLoading = false);
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset("assets/images/login.png", fit: BoxFit.cover),
          ),
          // Overlay
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.25)),
          ),
          // Title
          Positioned(
            top: 120, left: 0, right: 0,
            child: Column(children: [
              Text("CampusHub",
                  style: GoogleFonts.greatVibes(
                      fontSize: 56, color: const Color(0xFF1E2D4F))),
              const SizedBox(height: 6),
              Text("CONNECTING UNIVERSITY LIFE",
                  style: GoogleFonts.montserrat(
                      fontSize: 13, letterSpacing: 4,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1E2D4F))),
            ]),
          ),
          // Login Card
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: 350,
              margin: const EdgeInsets.only(bottom: 80),
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20, offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.person),
                    hintText: "Username",
                    border: UnderlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock),
                    hintText: "Password",
                    border: const UnderlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(obscurePassword
                          ? Icons.visibility_off : Icons.visibility),
                      onPressed: () =>
                          setState(() => obscurePassword = !obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity, height: 55,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : loginUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("LOGIN",
                        style: TextStyle(fontSize: 18,
                            fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}