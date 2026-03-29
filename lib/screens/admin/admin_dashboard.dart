import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'add_teacher.dart';
import 'view_teachers.dart';
import 'view_students.dart';
import 'add_subjects.dart';
import 'view_subjects.dart';
import 'add_timetable.dart';
import 'view_timetable.dart';
import 'bulk_upload_students.dart';
import '../login_screen.dart';

class AdminDashboard extends StatefulWidget {
  final String collegeId;
  final String adminDocId; // ✅ users collection doc ID

  const AdminDashboard({
    super.key,
    required this.collegeId,
    required this.adminDocId,
  });

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E6),

      // ================= DRAWER =================
      drawer: Drawer(
        child: Container(
          color: const Color(0xFF1E3A5F),
          child: SafeArea(
            child: Column(children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(children: [
                    const SizedBox(height: 30),
                    const Icon(Icons.admin_panel_settings, size: 70, color: Colors.white),
                    const SizedBox(height: 10),
                    Text("Admin Panel",
                        style: GoogleFonts.playfairDisplay(fontSize: 22, color: Colors.white)),
                    const SizedBox(height: 20),
                    _drawerItem(context, Icons.person_add, "Add Teacher",
                        AddTeacher(collegeId: widget.collegeId)),
                    _drawerItem(context, Icons.group, "View Teachers",
                        ViewTeachers(collegeId: widget.collegeId)),
                    _drawerItem(context, Icons.upload_file, "Bulk Upload Students",
                        BulkUploadStudents(collegeId: widget.collegeId)),
                    _drawerItem(context, Icons.people, "View Students",
                        ViewStudents(collegeId: widget.collegeId)),
                    _drawerItem(context, Icons.book, "Add Subjects",
                        AddSubject(collegeId: widget.collegeId)),
                    _drawerItem(context, Icons.menu_book, "View Subjects",
                        ViewSubjectsPage(collegeId: widget.collegeId)),
                    _drawerItem(context, Icons.schedule, "Add Timetable",
                        AddTimetable(collegeId: widget.collegeId)),
                    _drawerItem(context, Icons.calendar_month, "View Timetable",
                        ViewTimetable(collegeId: widget.collegeId)),
                    const SizedBox(height: 20),
                  ]),
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              ListTile(
                leading: const Icon(Icons.logout, size: 26, color: Colors.white),
                title: const Text("Logout", style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                ),
              ),
              const SizedBox(height: 10),
            ]),
          ),
        ),
      ),

      // ================= APP BAR =================
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        iconTheme: const IconThemeData(color: Colors.white, size: 32),
        title: Text("Welcome Admin",
            style: GoogleFonts.playfairDisplay(
                fontSize: 20, color: Colors.white, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),

      // ================= BODY =================
      body: SingleChildScrollView(
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: const BoxDecoration(
              color: Color(0xFF1E3A5F),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(35),
                bottomRight: Radius.circular(35),
              ),
            ),
            child: Column(children: [
              Text("Admin Dashboard",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(
                      fontSize: 26, color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text("Manage Academic Operations",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(fontSize: 14, color: Colors.white70)),
              const SizedBox(height: 12),
            ]),
          ),

          const SizedBox(height: 30),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(builder: (context, constraints) {
              final w     = constraints.maxWidth;
              final ratio = w < 320 ? 0.85 : w < 360 ? 0.90 : 1.0;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: ratio,
                children: [
                  _actionCard(context, Icons.person_add, "Add Teacher",
                      "Register faculty members.",
                      AddTeacher(collegeId: widget.collegeId)),
                  _actionCard(context, Icons.group, "View Teachers",
                      "Manage faculty profiles.",
                      ViewTeachers(collegeId: widget.collegeId)),
                  _actionCard(context, Icons.upload_file_rounded,
                      "Bulk Upload\nStudents", "Upload Excel / CSV file.",
                      BulkUploadStudents(collegeId: widget.collegeId)),
                  _actionCard(context, Icons.people, "View Students",
                      "Manage students.",
                      ViewStudents(collegeId: widget.collegeId)),
                  _actionCard(context, Icons.book, "Add Subjects",
                      "Allocate subjects.",
                      AddSubject(collegeId: widget.collegeId)),
                  _actionCard(context, Icons.menu_book, "View Subjects",
                      "Manage subjects.",
                      ViewSubjectsPage(collegeId: widget.collegeId)),
                  _actionCard(context, Icons.schedule, "Add Timetable",
                      "Create timetable.",
                      AddTimetable(collegeId: widget.collegeId)),
                  _actionCard(context, Icons.calendar_month, "View Timetable",
                      "See all schedules.",
                      ViewTimetable(collegeId: widget.collegeId)),
                ],
              );
            }),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _drawerItem(BuildContext context, IconData icon, String title, Widget page) {
    return ListTile(
        leading: Icon(icon, size: 30, color: Colors.white),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        onTap: () {
          Navigator.pop(context); // Close the drawer before navigating
          Navigator.push(context, MaterialPageRoute(builder: (_) => page));
        }
    );
  }

  Widget _actionCard(BuildContext context, IconData icon,
      String title, String subtitle, Widget page) {
    final w        = MediaQuery.of(context).size.width;
    final iconSize = w < 360 ? 32.0 : 40.0;
    final titleSz  = w < 360 ? 11.0 : 13.0;
    final subSz    = w < 360 ? 10.0 : 11.0;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      child: Container(
        padding: EdgeInsets.all(w < 360 ? 12 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: iconSize, color: const Color(0xFF1E3A5F)),
          const SizedBox(height: 8),
          Text(title, textAlign: TextAlign.center, maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: titleSz)),
          const SizedBox(height: 4),
          Text(subtitle, textAlign: TextAlign.center, maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey, fontSize: subSz)),
        ]),
      ),
    );
  }
}