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
  final String collegeId; // ✅

  const TeacherDashboard({
    super.key,
    required this.teacherId,
    required this.teacherName,
    required this.collegeId,
  });

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  final Set<String> _attendanceTaken = {};
  List<Map<String, dynamic>> _pendingLectures = [];
  bool _pendingLoading = true;
  List<QueryDocumentSnapshot> _todayLectures = [];

  @override
  void initState() {
    super.initState();
    _loadPendingAttendance();
  }

  String getTodayDay() {
    const days = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"];
    return days[DateTime.now().weekday % 7];
  }

  String _dayName(int weekday) {
    const days = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"];
    return days[weekday % 7];
  }

  String _formatDate(DateTime dt) =>
      "${dt.day.toString().padLeft(2,'0')}-${dt.month.toString().padLeft(2,'0')}-${dt.year}";

  String _monthShort(int month) {
    const m = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
    return m[month - 1];
  }

  Future<void> _loadPendingAttendance() async {
    try {
      setState(() => _pendingLoading = true);
      final now     = DateTime.now();
      final pending = <Map<String, dynamic>>[];

      // ✅ Filter by collegeId
      final ttSnap = await FirebaseFirestore.instance
          .collection("timetable")
          .where("teacherId", isEqualTo: widget.teacherId)
          .where("collegeId", isEqualTo: widget.collegeId)
          .get();

      if (ttSnap.docs.isEmpty) { setState(() => _pendingLoading = false); return; }

      for (int i = 1; i <= 7; i++) {
        final date    = now.subtract(Duration(days: i));
        final dayName = _dayName(date.weekday);
        final dayLectures = ttSnap.docs.where((doc) =>
        (doc.data()["day"] as String? ?? "") == dayName).toList();
        if (dayLectures.isEmpty) continue;

        final startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
        final endOfDay   = DateTime(date.year, date.month, date.day, 23, 59, 59);

        for (var lecture in dayLectures) {
          final ld          = lecture.data();
          final subjectName = ld["subjectName"] as String? ?? "";
          final lectureType = ld["lectureType"] as String? ?? "LEC"; // ✅ Added Lecture Type check

          final attSnap = await FirebaseFirestore.instance
              .collection("attendance")
              .where("teacherId",   isEqualTo: widget.teacherId)
              .where("subject",     isEqualTo: subjectName)
              .where("lectureType", isEqualTo: lectureType) // ✅ Must match type to mark as taken
              .where("date", isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
              .where("date", isLessThanOrEqualTo:   Timestamp.fromDate(endOfDay))
              .limit(1).get();

          if (attSnap.docs.isEmpty) {
            pending.add({
              "subjectName": subjectName,
              "lectureType": lectureType, // ✅ Passed to UI
              "course":      ld["course"]    as String? ?? "",
              "division":    ld["division"]  as String? ?? "",
              "room":        ld["room"]      as String? ?? "",
              "startTime":   ld["startTime"] as String? ?? "",
              "endTime":     ld["endTime"]   as String? ?? "",
              "date":        date,
              "dateStr":     _formatDate(date),
              "dayName":     dayName,
              "daysAgo":     i,
              "lectureNo":   (ld["lectureNo"] as num?)?.toInt() ?? 1,
            });
          }
        }
      }

      pending.sort((a, b) => (b["date"] as DateTime).compareTo(a["date"] as DateTime));
      if (mounted) setState(() { _pendingLectures = pending; _pendingLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _pendingLoading = false);
    }
  }

  Future<bool> checkAttendanceTaken(String subject, String lectureType) async {
    try {
      final now        = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
      final endOfDay   = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final query = await FirebaseFirestore.instance
          .collection("attendance")
          .where("teacherId",   isEqualTo: widget.teacherId)
          .where("subject",     isEqualTo: subject)
          .where("lectureType", isEqualTo: lectureType) // ✅ Added lectureType check
          .where("date", isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where("date", isLessThanOrEqualTo:   Timestamp.fromDate(endOfDay))
          .limit(1).get();
      return query.docs.isNotEmpty;
    } catch (_) { return false; }
  }

  Future<void> _showSubjectPicker(BuildContext context) async {
    showDialog(context: context, barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      // ✅ Filter by collegeId
      final snap = await FirebaseFirestore.instance
          .collection("timetable")
          .where("teacherId", isEqualTo: widget.teacherId)
          .where("collegeId", isEqualTo: widget.collegeId)
          .get();

      if (context.mounted) Navigator.pop(context);

      final Map<String, Map<String, String>> unique = {};
      for (var doc in snap.docs) {
        final d = doc.data();
        final subject  = d["subjectName"] as String? ?? "";
        final course   = d["course"]      as String? ?? "";
        final division = d["division"]    as String? ?? "";
        if (subject.isEmpty) continue;
        unique.putIfAbsent("$subject||$course||$division", () =>
        {"subject": subject, "course": course, "division": division});
      }

      final subjects = unique.values.toList()
        ..sort((a, b) => a["subject"]!.compareTo(b["subject"]!));

      if (!context.mounted) return;
      if (subjects.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No subjects found")));
        return;
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => DraggableScrollableSheet(
          expand: false, initialChildSize: 0.5, maxChildSize: 0.85, minChildSize: 0.3,
          builder: (_, ctrl) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text("Select Subject",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(child: ListView.separated(
                controller: ctrl,
                itemCount: subjects.length,
                separatorBuilder: (_, __) => Divider(color: Colors.grey.shade100, height: 1),
                itemBuilder: (ctx, i) {
                  final s = subjects[i];
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: const Color(0xFF1E3A5F).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.menu_book, color: Color(0xFF1E3A5F), size: 20),
                    ),
                    title: Text(s["subject"]!,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text("${s["course"]} - ${s["division"]}",
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => UploadMarks(
                            course:    s["course"]!,
                            division:  s["division"]!,
                            subject:   s["subject"]!,
                            teacherId: widget.teacherId,
                            collegeId: widget.collegeId, // ✅
                          )));
                    },
                  );
                },
              )),
            ]),
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) { Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"))); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = getTodayDay();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E6),
      drawer: Drawer(
        child: Container(
          color: const Color(0xFF1E3A5F),
          child: SafeArea(child: Column(children: [
            Expanded(child: SingleChildScrollView(child: Column(children: [
              const SizedBox(height: 20),
              const Icon(Icons.person, size: 70, color: Colors.white),
              const SizedBox(height: 10),
              Text(widget.teacherName,
                  style: GoogleFonts.playfairDisplay(fontSize: 22, color: Colors.white)),
              const SizedBox(height: 30),
              _dItem(context, Icons.dashboard, "Dashboard", () => Navigator.pop(context)),
              _dItem(context, Icons.upload, "Upload Marks", () {
                Navigator.pop(context); _showSubjectPicker(context);
              }),
              _dItem(context, Icons.bar_chart, "View Marks", () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ViewMarks(teacherId: widget.teacherId, collegeId: widget.collegeId)));
              }),
              _dItem(context, Icons.calendar_month, "My Timetable", () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ViewTimetable(
                        teacherId: widget.teacherId,
                        teacherName: widget.teacherName,
                        collegeId: widget.collegeId)));
              }),
              _dItem(context, Icons.campaign_rounded, "Notice Board", () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => NoticeBoard(
                        teacherId: widget.teacherId,
                        teacherName: widget.teacherName,
                        collegeId: widget.collegeId)));
              }),
              // ✅ Pass collegeId to ViewStudents
              _dItem(context, Icons.people, "View Students", () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ViewStudents(collegeId: widget.collegeId)));
              }),
              _dItem(context, Icons.history, "Previous Attendance", () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => PreviousAttendance(teacherId: widget.teacherId)));
              }),
            ]))),
            const Divider(color: Colors.white24, height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.white),
              title: const Text("Logout", style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pushAndRemoveUntil(context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false),
            ),
            const SizedBox(height: 10),
          ])),
        ),
      ),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text("Welcome ${widget.teacherName}",
            style: GoogleFonts.playfairDisplay(color: Colors.white, fontSize: 20)),
        centerTitle: true,
        actions: [IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadPendingAttendance)],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // ✅ Filter timetable by collegeId
        stream: FirebaseFirestore.instance
            .collection("timetable")
            .where("teacherId", isEqualTo: widget.teacherId)
            .where("collegeId", isEqualTo: widget.collegeId)
            .where("day",       isEqualTo: today)
            .snapshots(),
        builder: (context, ttSnap) {
          final lectures = ttSnap.hasData
              ? (ttSnap.data!.docs.toList()
            ..sort((a, b) {
              final an = ((a.data() as Map)["lectureNo"] as num?)?.toInt() ?? 0;
              final bn = ((b.data() as Map)["lectureNo"] as num?)?.toInt() ?? 0;
              return an.compareTo(bn);
            }))
              : <QueryDocumentSnapshot>[];

          return SingleChildScrollView(child: Column(children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: const BoxDecoration(
                color: Color(0xFF1E3A5F),
                borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(35), bottomRight: Radius.circular(35)),
              ),
              child: Column(children: [
                Text("Teacher Dashboard",
                    style: GoogleFonts.playfairDisplay(fontSize: 26, color: Colors.white)),
                const SizedBox(height: 8),
                Text("Manage Lectures & Attendance",
                    style: GoogleFonts.montserrat(fontSize: 14, color: Colors.white70)),
              ]),
            ),
            const SizedBox(height: 30),

            // Action Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16,
                children: [
                  _aCard(context, Icons.upload,          "Upload Marks",        () => _showSubjectPicker(context)),
                  _aCard(context, Icons.bar_chart,       "View Marks",          () => Navigator.push(context, MaterialPageRoute(builder: (_) => ViewMarks(teacherId: widget.teacherId, collegeId: widget.collegeId)))),
                  // ✅ Pass collegeId
                  _aCard(context, Icons.people,          "View Students",       () => Navigator.push(context, MaterialPageRoute(builder: (_) => ViewStudents(collegeId: widget.collegeId)))),
                  _aCard(context, Icons.history,         "Previous Attendance", () => Navigator.push(context, MaterialPageRoute(builder: (_) => PreviousAttendance(teacherId: widget.teacherId)))),
                  _aCard(context, Icons.calendar_month,  "My Timetable",        () => Navigator.push(context, MaterialPageRoute(builder: (_) => ViewTimetable(teacherId: widget.teacherId, teacherName: widget.teacherName, collegeId: widget.collegeId)))),
                  _aCard(context, Icons.campaign_rounded,"Notice Board",        () => Navigator.push(context, MaterialPageRoute(builder: (_) => NoticeBoard(teacherId: widget.teacherId, teacherName: widget.teacherName, collegeId: widget.collegeId)))),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Pending Attendance
            if (_pendingLoading)
              const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())
            else if (_pendingLectures.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18)),
                  const SizedBox(width: 10),
                  Text("Pending Attendance",
                      style: GoogleFonts.playfairDisplay(
                          fontSize: 20, fontWeight: FontWeight.w600, color: Colors.red.shade700)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                    child: Text("${_pendingLectures.length}",
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _pendingLectures.length,
                itemBuilder: (context, i) {
                  final p = _pendingLectures[i];
                  final daysAgo = p["daysAgo"] as int;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.shade200, width: 1.2),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                      ),
                      child: Row(children: [
                        Container(
                          width: 52, padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12)),
                          child: Column(children: [
                            Text((p["date"] as DateTime).day.toString().padLeft(2,'0'),
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
                            Text(_monthShort((p["date"] as DateTime).month),
                                style: TextStyle(fontSize: 11, color: Colors.red.shade400)),
                          ]),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p["subjectName"], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 3),
                          // ✅ Shows type next to day
                          Text("${p["course"]}-${p["division"]}  ·  ${p["dayName"]} (${p["lectureType"]})",
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                          Text("${p["startTime"]} - ${p["endTime"]}  ·  Room: ${p["room"]}",
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10)),
                            child: Text(daysAgo == 1 ? "Yesterday" : "$daysAgo days ago",
                                style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () async {
                              await Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => AttendanceScreen(
                                    course:        p["course"],
                                    division:      p["division"],
                                    subject:       p["subjectName"],
                                    lectureType:   p["lectureType"], // ✅ Now passes lectureType
                                    teacherId:     widget.teacherId,
                                    collegeId:     widget.collegeId,
                                    skipDateCheck: true,
                                    forDate:       p["date"] as DateTime,
                                    lectureNo:     p["lectureNo"] as int? ?? 1,
                                  )));
                              _loadPendingAttendance();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: const Color(0xFF1E3A5F),
                                  borderRadius: BorderRadius.circular(10)),
                              child: const Text("Mark Now",
                                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ]),
                      ]),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],

            // Today's Lectures
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(alignment: Alignment.centerLeft,
                  child: Text("Today's Lectures",
                      style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.w600))),
            ),
            const SizedBox(height: 10),

            if (ttSnap.connectionState == ConnectionState.waiting)
              const Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())
            else if (lectures.isEmpty)
              const Padding(padding: EdgeInsets.all(30), child: Text("No Lectures Today"))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: lectures.length,
                itemBuilder: (context, index) {
                  final d           = lectures[index].data() as Map<String, dynamic>;
                  final subjectName = d["subjectName"] as String? ?? "Unknown";
                  final course      = d["course"]      as String? ?? "";
                  final division    = d["division"]    as String? ?? "";
                  final room        = d["room"]        as String? ?? "TBA";
                  final startTime   = d["startTime"]   as String? ?? "";
                  final endTime     = d["endTime"]     as String? ?? "";
                  final lectureNo   = (d["lectureNo"]  as num?)?.toInt() ?? (index + 1);
                  final lectureType = d["lectureType"] as String? ?? "LEC"; // ✅ Get lectureType

                  // Create a unique key for tracking taken status locally
                  final trackingKey = "$subjectName||$lectureType";
                  final taken       = _attendanceTaken.contains(trackingKey);

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text("$subjectName ($lectureType)", // ✅ Shows type in UI
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: const Color(0xFF1E3A5F).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8)),
                            child: Text("L$lectureNo",
                                style: const TextStyle(color: Color(0xFF1E3A5F),
                                    fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          if (taken) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20)),
                              child: const Text("✓ Done",
                                  style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ]),
                        const SizedBox(height: 5),
                        Text("Course: $course - $division"),
                        Text("Room: $room"),
                        Text("Time: $startTime - $endTime"),
                        const SizedBox(height: 10),
                        FutureBuilder<bool>(
                          future: checkAttendanceTaken(subjectName, lectureType), // ✅ Use both to check
                          builder: (context, snap) {
                            final done = snap.data ?? taken;
                            if (done && !_attendanceTaken.contains(trackingKey)) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) setState(() => _attendanceTaken.add(trackingKey));
                              });
                            }
                            return SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: done ? Colors.grey.shade400 : const Color(0xFF1E3A5F),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: done ? null : () async {
                                  await Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => AttendanceScreen(
                                        course:      course,
                                        division:    division,
                                        subject:     subjectName,
                                        lectureType: lectureType, // ✅ Pass lectureType to screen
                                        teacherId:   widget.teacherId,
                                        collegeId:   widget.collegeId,
                                        lectureNo:   lectureNo,
                                      )));
                                  if (mounted) setState(() {});
                                },
                                icon: Icon(done ? Icons.check_circle : Icons.fact_check,
                                    color: Colors.white, size: 18),
                                label: Text(done ? "Attendance Taken" : "Take Attendance",
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            );
                          },
                        ),
                      ]),
                    ),
                  );
                },
              ),
            const SizedBox(height: 40),
          ]));
        },
      ),
    );
  }

  Widget _dItem(BuildContext ctx, IconData icon, String title, VoidCallback onTap) =>
      ListTile(leading: Icon(icon, color: Colors.white),
          title: Text(title, style: const TextStyle(color: Colors.white)), onTap: onTap);

  Widget _aCard(BuildContext ctx, IconData icon, String title, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 40, color: const Color(0xFF1E3A5F)),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}