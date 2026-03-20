import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'add_teacher.dart';
import 'view_teachers.dart';
import 'add_student.dart';
import 'view_students.dart';
import 'add_subjects.dart';
import 'view_subjects.dart';
import 'add_timetable.dart';
import 'view_timetable.dart';
import 'bulk_upload_students.dart';
import '../login_screen.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E6),

      // ================= DRAWER =================
      drawer: Drawer(
        child: Container(
          color: const Color(0xFF1E3A5F),
          child: Column(
            children: [
              const SizedBox(height: 60),
              const Icon(
                Icons.admin_panel_settings,
                size: 80,
                color: Colors.white,
              ),
              const SizedBox(height: 15),
              Text(
                "Admin Panel",
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 40),

              drawerItem(context, Icons.person_add,     "Add Teacher",           const AddTeacher()),
              drawerItem(context, Icons.group,          "View Teachers",         const ViewTeachers()),
              drawerItem(context, Icons.school,         "Add Student",           const AddStudent()),
              drawerItem(context, Icons.upload_file,    "Bulk Upload Students",  const BulkUploadStudents()),
              drawerItem(context, Icons.people,         "View Students",         const ViewStudents()),
              drawerItem(context, Icons.book,           "Add Subjects",          const AddSubject()),
              drawerItem(context, Icons.menu_book,      "View Subjects",         const ViewSubjects()),
              drawerItem(context, Icons.schedule,       "Add Timetable",         const AddTimetable()),
              drawerItem(context, Icons.calendar_month, "View Timetable",        const ViewTimetable()),

              const Spacer(),

              ListTile(
                leading: const Icon(Icons.logout, size: 30, color: Colors.white),
                title: const Text("Logout", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                  );
                },
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),

      // ================= APP BAR =================
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        iconTheme: const IconThemeData(color: Colors.white, size: 32),
        title: Text(
          "Welcome Admin",
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),

      // ================= BODY =================
      body: SingleChildScrollView(
        child: Column(
          children: [

            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: const BoxDecoration(
                color: Color(0xFF1E3A5F),
                borderRadius: BorderRadius.only(
                  bottomLeft:  Radius.circular(35),
                  bottomRight: Radius.circular(35),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    "Admin Dashboard",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 26,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Manage Academic Operations",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ── ACTION GRID ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: const [

                  ActionCard(
                    icon:     Icons.person_add,
                    title:    "Add Teacher",
                    subtitle: "Register faculty members.",
                    page:     AddTeacher(),
                  ),

                  ActionCard(
                    icon:     Icons.group,
                    title:    "View Teachers",
                    subtitle: "Manage faculty profiles.",
                    page:     ViewTeachers(),
                  ),

                  ActionCard(
                    icon:     Icons.school,
                    title:    "Add Student",
                    subtitle: "Register one student.",
                    page:     AddStudent(),
                  ),

                  // ✅ NEW — Bulk Upload
                  ActionCard(
                    icon:     Icons.upload_file_rounded,
                    title:    "Bulk Upload",
                    subtitle: "Upload Excel / CSV file.",
                    page:     BulkUploadStudents(),
                  ),

                  ActionCard(
                    icon:     Icons.people,
                    title:    "View Students",
                    subtitle: "Manage students.",
                    page:     ViewStudents(),
                  ),

                  ActionCard(
                    icon:     Icons.book,
                    title:    "Add Subjects",
                    subtitle: "Allocate subjects.",
                    page:     AddSubject(),
                  ),

                  ActionCard(
                    icon:     Icons.menu_book,
                    title:    "View Subjects",
                    subtitle: "Manage subjects.",
                    page:     ViewSubjects(),
                  ),

                  ActionCard(
                    icon:     Icons.schedule,
                    title:    "Add Timetable",
                    subtitle: "Create timetable.",
                    page:     AddTimetable(),
                  ),

                  ActionCard(
                    icon:     Icons.calendar_month,
                    title:    "View Timetable",
                    subtitle: "See all schedules.",
                    page:     ViewTimetable(),
                  ),

                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget drawerItem(BuildContext context, IconData icon, String title, Widget page) {
    return ListTile(
      leading: Icon(icon, size: 30, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => page),
        );
      },
    );
  }
}

////////////////////////////////////////////////////////////
// ACTION CARD
////////////////////////////////////////////////////////////

class ActionCard extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String   subtitle;
  final Widget   page;

  const ActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.page,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => page),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 10),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: const Color(0xFF1E3A5F)),
            const SizedBox(height: 10),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}