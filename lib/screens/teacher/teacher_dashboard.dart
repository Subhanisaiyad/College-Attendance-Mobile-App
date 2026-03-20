import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../login_screen.dart';
import 'attendance_screen.dart';
import 'upload_marks.dart';
import 'view_marks.dart';
import 'teacher_timetable_view.dart';
import 'notice_board.dart';
import '../admin/view_students.dart';
import 'previous_attendance.dart';

class TeacherDashboard extends StatefulWidget {
  final String teacherId;
  final String teacherName;

  const TeacherDashboard({
    super.key,
    required this.teacherId,
    required this.teacherName,
  });

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  final Set<String> _attendanceTaken = {};

  // ✅ Past 7 days pending attendance list
  List<Map<String, dynamic>> _pendingLectures = [];
  bool _pendingLoading = true;

  // ✅ Today's lectures — drawer ke liye bhi accessible
  List<QueryDocumentSnapshot> _todayLectures = [];

  @override
  void initState() {
    super.initState();
    _loadPendingAttendance();
  }

  String getTodayDay() {
    const days = [
      "Sunday", "Monday", "Tuesday", "Wednesday",
      "Thursday", "Friday", "Saturday"
    ];
    return days[DateTime.now().weekday % 7];
  }

  String _dayName(int weekday) {
    const days = [
      "Sunday", "Monday", "Tuesday", "Wednesday",
      "Thursday", "Friday", "Saturday"
    ];
    return days[weekday % 7];
  }

  String _formatDate(DateTime dt) {
    return "${dt.day.toString().padLeft(2, '0')}-"
        "${dt.month.toString().padLeft(2, '0')}-${dt.year}";
  }

  // ✅ Past 7 days ke lectures check karo — attendance missing hai toh pending mein daalo
  Future<void> _loadPendingAttendance() async {
    try {
      setState(() => _pendingLoading = true);

      final now     = DateTime.now();
      final pending = <Map<String, dynamic>>[];

      // Timetable fetch karo — is teacher ki saari entries
      final ttSnap = await FirebaseFirestore.instance
          .collection("timetable")
          .where("teacherId", isEqualTo: widget.teacherId)
          .get();

      if (ttSnap.docs.isEmpty) {
        setState(() => _pendingLoading = false);
        return;
      }

      // Last 7 days check karo (aaj ko chhod ke)
      for (int i = 1; i <= 7; i++) {
        final date    = now.subtract(Duration(days: i));
        final dayName = _dayName(date.weekday);

        // Is din ke lectures
        final dayLectures = ttSnap.docs.where((doc) {
          final d = doc.data();
          return (d["day"] as String? ?? "") == dayName;
        }).toList();

        if (dayLectures.isEmpty) continue;

        final startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
        final endOfDay   = DateTime(date.year, date.month, date.day, 23, 59, 59);

        for (var lecture in dayLectures) {
          final ld          = lecture.data();
          final String subjectName = ld["subjectName"] as String? ?? "";

          // Check karo — is subject ki is date ko attendance li thi?
          final attSnap = await FirebaseFirestore.instance
              .collection("attendance")
              .where("teacherId", isEqualTo: widget.teacherId)
              .where("subject",   isEqualTo: subjectName)
              .where("date", isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
              .where("date", isLessThanOrEqualTo:   Timestamp.fromDate(endOfDay))
              .limit(1)
              .get();

          if (attSnap.docs.isEmpty) {
            // ✅ Attendance nahi li — pending mein add karo
            pending.add({
              "subjectName": subjectName,
              "course":      ld["course"]    as String? ?? "",
              "division":    ld["division"]  as String? ?? "",
              "room":        ld["room"]      as String? ?? "",
              "startTime":   ld["startTime"] as String? ?? "",
              "endTime":     ld["endTime"]   as String? ?? "",
              "date":        date,
              "dateStr":     _formatDate(date),
              "dayName":     dayName,
              "daysAgo":     i,
            });
          }
        }
      }

      // Sort by date descending (recent first)
      pending.sort((a, b) =>
          (b["date"] as DateTime).compareTo(a["date"] as DateTime));

      if (mounted) {
        setState(() {
          _pendingLectures = pending;
          _pendingLoading  = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _pendingLoading = false);
    }
  }

  Future<bool> checkAttendanceTaken(String subject) async {
    try {
      final now        = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
      final endOfDay   = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final query = await FirebaseFirestore.instance
          .collection("attendance")
          .where("teacherId", isEqualTo: widget.teacherId)
          .where("subject",   isEqualTo: subject)
          .where("date", isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where("date", isLessThanOrEqualTo:   Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // ✅ Saare days ke unique subjects fetch karke dikhao
  Future<void> _showSubjectPicker(BuildContext context) async {
    // Loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Saare timetable entries is teacher ki
      final snap = await FirebaseFirestore.instance
          .collection("timetable")
          .where("teacherId", isEqualTo: widget.teacherId)
          .get();

      if (context.mounted) Navigator.pop(context); // close loader

      // Unique subjects — key = "subject||course||division"
      final Map<String, Map<String, String>> unique = {};
      for (var doc in snap.docs) {
        final d        = doc.data();
        final subject  = d["subjectName"] as String? ?? "";
        final course   = d["course"]      as String? ?? "";
        final division = d["division"]    as String? ?? "";
        if (subject.isEmpty) continue;
        final key = "$subject||$course||$division";
        unique.putIfAbsent(key, () => {
          "subject":  subject,
          "course":   course,
          "division": division,
        });
      }

      final subjects = unique.values.toList()
        ..sort((a, b) => a["subject"]!.compareTo(b["subject"]!));

      if (!context.mounted) return;

      if (subjects.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No subjects found in timetable")),
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          maxChildSize: 0.85,
          minChildSize: 0.3,
          builder: (_, scrollCtrl) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text("Select Subject",
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text("${subjects.length} subjects found",
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500)),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    controller: scrollCtrl,
                    itemCount: subjects.length,
                    separatorBuilder: (_, __) =>
                        Divider(color: Colors.grey.shade100, height: 1),
                    itemBuilder: (ctx, i) {
                      final s        = subjects[i];
                      final subject  = s["subject"]!;
                      final course   = s["course"]!;
                      final division = s["division"]!;
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A5F)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.menu_book,
                              color: Color(0xFF1E3A5F), size: 20),
                        ),
                        title: Text(subject,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                        subtitle: Text("$course - $division",
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500)),
                        trailing: const Icon(Icons.arrow_forward_ios,
                            size: 14, color: Colors.grey),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UploadMarks(
                                course:    course,
                                division:  division,
                                subject:   subject,
                                teacherId: widget.teacherId,
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
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String today = getTodayDay();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E6),

      // ══════════════ DRAWER ══════════════
      drawer: Drawer(
        child: Container(
          color: const Color(0xFF1E3A5F),
          child: Column(
            children: [
              const SizedBox(height: 60),
              const Icon(Icons.person, size: 80, color: Colors.white),
              const SizedBox(height: 15),
              Text(widget.teacherName,
                  style: GoogleFonts.playfairDisplay(
                      fontSize: 22, color: Colors.white)),
              const SizedBox(height: 40),
              _drawerItem(context, Icons.dashboard, "Dashboard",
                      () => Navigator.pop(context)),
              _drawerItem(context, Icons.upload, "Upload Marks", () {
                Navigator.pop(context);
                _showSubjectPicker(context);
              }),
              _drawerItem(context, Icons.bar_chart, "View Marks", () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) =>
                            ViewMarks(teacherId: widget.teacherId)));
              }),
              _drawerItem(context, Icons.calendar_month, "My Timetable", () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => ViewTimetable(
                            teacherId:   widget.teacherId,
                            teacherName: widget.teacherName)));
              }),
              _drawerItem(context, Icons.campaign_rounded,
                  "Notice Board", () {
                    Navigator.pop(context);
                    Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => NoticeBoard(
                                teacherId:   widget.teacherId,
                                teacherName: widget.teacherName)));
                  }),
              _drawerItem(context, Icons.people, "View Students", () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const ViewStudents()));
              }),
              _drawerItem(context, Icons.history, "Previous Attendance", () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => PreviousAttendance(
                            teacherId: widget.teacherId)));
              }),
              const Spacer(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.white),
                title: const Text("Logout",
                    style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),

      // ══════════════ APP BAR ══════════════
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text("Welcome ${widget.teacherName}",
            style: GoogleFonts.playfairDisplay(
                color: Colors.white, fontSize: 20)),
        centerTitle: true,
        actions: [
          // ✅ Refresh pending button
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadPendingAttendance,
          ),
        ],
      ),

      // ══════════════ BODY ══════════════
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("timetable")
            .where("teacherId", isEqualTo: widget.teacherId)
            .where("day", isEqualTo: today)
            .snapshots(),

        builder: (context, ttSnap) {
          final lectures = ttSnap.hasData
              ? (ttSnap.data!.docs.toList()
            ..sort((a, b) {
              final aNo =
                  (a.data() as Map)["lectureNo"] as int? ?? 0;
              final bNo =
                  (b.data() as Map)["lectureNo"] as int? ?? 0;
              return aNo.compareTo(bNo);
            }))
              : <QueryDocumentSnapshot>[];

          // ✅ State mein save karo — drawer use karega
          if (_todayLectures.length != lectures.length) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _todayLectures = lectures);
            });
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                // ── Header ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E3A5F),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(35),
                      bottomRight: Radius.circular(35),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text("Teacher Dashboard",
                          style: GoogleFonts.playfairDisplay(
                              fontSize: 26, color: Colors.white)),
                      const SizedBox(height: 8),
                      Text("Manage Lectures & Attendance",
                          style: GoogleFonts.montserrat(
                              fontSize: 14, color: Colors.white70)),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // ── Action Grid ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _actionCard(context, Icons.upload, "Upload Marks",
                              () {
                            _showSubjectPicker(context);
                          }),
                      _actionCard(
                          context, Icons.bar_chart, "View Marks", () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ViewMarks(
                                    teacherId: widget.teacherId)));
                      }),
                      _actionCard(
                          context, Icons.people, "View Students", () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ViewStudents()));
                      }),
                      _actionCard(context, Icons.history,
                          "Previous Attendance", () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => PreviousAttendance(
                                        teacherId: widget.teacherId)));
                          }),

                      // ✅ My Timetable card
                      _actionCard(context, Icons.calendar_month,
                          "My Timetable", () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => ViewTimetable(
                                        teacherId:   widget.teacherId,
                                        teacherName: widget.teacherName)));
                          }),

                      // ✅ 6th card — Notice Board
                      _actionCard(context, Icons.campaign_rounded,
                          "Notice\nBoard", () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => NoticeBoard(
                                        teacherId:   widget.teacherId,
                                        teacherName: widget.teacherName)));
                          }),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // ══════════════════════════════════
                // ✅ PENDING ATTENDANCE SECTION
                // ══════════════════════════════════
                if (_pendingLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: CircularProgressIndicator(),
                  )
                else if (_pendingLectures.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.warning_amber_rounded,
                              color: Colors.red, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "Pending Attendance",
                          style: GoogleFonts.playfairDisplay(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade700),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "${_pendingLectures.length}",
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _pendingLectures.length,
                    itemBuilder: (context, index) {
                      final p = _pendingLectures[index];
                      final int daysAgo = p["daysAgo"] as int;

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.red.shade200, width: 1.2),
                            boxShadow: const [
                              BoxShadow(
                                  color: Colors.black12, blurRadius: 6)
                            ],
                          ),
                          child: Row(
                            children: [
                              // Date badge
                              Container(
                                width: 52,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      (p["date"] as DateTime)
                                          .day
                                          .toString()
                                          .padLeft(2, '0'),
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                    Text(
                                      _monthShort(
                                          (p["date"] as DateTime).month),
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.red.shade400),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 14),

                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p["subjectName"],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      "${p["course"]}-${p["division"]}  ·  ${p["dayName"]}",
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500),
                                    ),
                                    Text(
                                      "${p["startTime"]} - ${p["endTime"]}  ·  Room: ${p["room"]}",
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                              ),

                              // Days ago badge + Mark button
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius:
                                      BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      daysAgo == 1
                                          ? "Yesterday"
                                          : "$daysAgo days ago",
                                      style: const TextStyle(
                                          color: Colors.red,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AttendanceScreen(
                                            course:        p["course"],
                                            division:      p["division"],
                                            subject:       p["subjectName"],
                                            teacherId:     widget.teacherId,
                                            skipDateCheck: true,
                                            forDate:       p["date"] as DateTime,
                                            lectureNo:     p["lectureNo"] as int? ?? 1,
                                          ),
                                        ),
                                      );
                                      // Refresh pending list
                                      _loadPendingAttendance();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E3A5F),
                                        borderRadius:
                                        BorderRadius.circular(10),
                                      ),
                                      child: const Text(
                                        "Mark Now",
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 10),
                ],

                // ══════════════════════════════════
                // TODAY'S LECTURES
                // ══════════════════════════════════
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Today's Lectures",
                        style: GoogleFonts.playfairDisplay(
                            fontSize: 20,
                            fontWeight: FontWeight.w600)),
                  ),
                ),

                const SizedBox(height: 10),

                if (ttSnap.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.all(30),
                    child: CircularProgressIndicator(),
                  )
                else if (lectures.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(30),
                    child: Text("No Lectures Today"),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: lectures.length,
                    itemBuilder: (context, index) {
                      final Map<String, dynamic> data =
                      lectures[index].data() as Map<String, dynamic>;

                      final String subjectName =
                          data["subjectName"] as String? ?? "Unknown";
                      final String course =
                          data["course"]    as String? ?? "";
                      final String division =
                          data["division"]  as String? ?? "";
                      final String room =
                          data["room"]      as String? ?? "TBA";
                      final String startTime =
                          data["startTime"] as String? ?? "";
                      final String endTime =
                          data["endTime"]   as String? ?? "";
                      final int lectureNo =                       // ✅
                      data["lectureNo"] as int? ?? (index + 1);
                      final bool taken =
                      _attendanceTaken.contains(subjectName);

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                  color: Colors.black12, blurRadius: 10)
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(subjectName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                  ),
                                  // ✅ Lecture No badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E3A5F)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text("L$lectureNo",
                                        style: const TextStyle(
                                            color: Color(0xFF1E3A5F),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 6),
                                  if (taken)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color:
                                        Colors.green.withOpacity(0.1),
                                        borderRadius:
                                        BorderRadius.circular(20),
                                      ),
                                      child: const Text("✓ Done",
                                          style: TextStyle(
                                              color: Colors.green,
                                              fontSize: 12,
                                              fontWeight:
                                              FontWeight.bold)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text("Course: $course - $division"),
                              Text("Room: $room"),
                              Text("Time: $startTime - $endTime"),
                              const SizedBox(height: 10),
                              FutureBuilder<bool>(
                                future: checkAttendanceTaken(subjectName),
                                builder: (context, futureSnap) {
                                  final bool alreadyDone =
                                      futureSnap.data ?? taken;
                                  if (alreadyDone &&
                                      !_attendanceTaken
                                          .contains(subjectName)) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      if (mounted) {
                                        setState(() => _attendanceTaken
                                            .add(subjectName));
                                      }
                                    });
                                  }
                                  return SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: alreadyDone
                                            ? Colors.grey.shade400
                                            : const Color(0xFF1E3A5F),
                                        padding:
                                        const EdgeInsets.symmetric(
                                            vertical: 12),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(
                                                12)),
                                      ),
                                      onPressed: alreadyDone
                                          ? null
                                          : () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                AttendanceScreen(
                                                  course:    course,
                                                  division:  division,
                                                  subject:   subjectName,
                                                  teacherId: widget.teacherId,
                                                  lectureNo: lectureNo,
                                                ),
                                          ),
                                        );
                                        if (mounted) setState(() {});
                                      },
                                      icon: Icon(
                                        alreadyDone
                                            ? Icons.check_circle
                                            : Icons.fact_check,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      label: Text(
                                        alreadyDone
                                            ? "Attendance Taken"
                                            : "Take Attendance",
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  String _monthShort(int month) {
    const months = [
      "Jan","Feb","Mar","Apr","May","Jun",
      "Jul","Aug","Sep","Oct","Nov","Dec"
    ];
    return months[month - 1];
  }

  Widget _drawerItem(BuildContext context, IconData icon, String title,
      VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
    );
  }

  Widget _actionCard(BuildContext context, IconData icon, String title,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 10)
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: const Color(0xFF1E3A5F)),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}