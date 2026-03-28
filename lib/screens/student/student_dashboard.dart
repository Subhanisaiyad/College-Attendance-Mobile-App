import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../login_screen.dart';
import 'student_attendance_view.dart';
import 'student_marks_view.dart';
import 'student_views.dart';

class StudentDashboard extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String course;
  final String division;
  final String collegeId; // ✅

  const StudentDashboard({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.course,
    required this.division,
    required this.collegeId,
  });

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  double _overallAttendance = 0;
  int    _totalSubjects     = 0;
  bool   _statsLoaded       = false;

  @override
  void initState() { super.initState(); _loadStats(); }

  Future<void> _loadStats() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection("attendance")
          .where("studentId", isEqualTo: widget.studentId)
          .get();

      if (snap.docs.isEmpty) { setState(() => _statsLoaded = true); return; }

      final Map<String, Map<String, int>> bySubject = {};
      for (var doc in snap.docs) {
        final d       = doc.data();
        final subject = d["subject"] as String? ?? "";
        final status  = d["status"]  as String? ?? "absent";
        bySubject.putIfAbsent(subject, () => {"p": 0, "t": 0});
        bySubject[subject]!["t"] = bySubject[subject]!["t"]! + 1;
        if (status == "present") bySubject[subject]!["p"] = bySubject[subject]!["p"]! + 1;
      }

      int totalP = 0, totalT = 0;
      for (var s in bySubject.values) { totalP += s["p"]!; totalT += s["t"]!; }

      setState(() {
        _overallAttendance = totalT > 0 ? totalP / totalT * 100 : 0;
        _totalSubjects = bySubject.length;
        _statsLoaded   = true;
      });
    } catch (_) { setState(() => _statsLoaded = true); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E6),
      drawer: Drawer(
        child: Container(
          color: const Color(0xFF1E3A5F),
          child: SafeArea(child: Column(children: [
            Expanded(child: SingleChildScrollView(child: Column(children: [
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                child: Text(
                  widget.studentName.isNotEmpty ? widget.studentName[0].toUpperCase() : "S",
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(height: 14),
              Text(widget.studentName,
                  style: GoogleFonts.playfairDisplay(fontSize: 22, color: Colors.white)),
              const SizedBox(height: 6),
              Text("${widget.course}  ·  Div ${widget.division}",
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
              const SizedBox(height: 20),
              Divider(color: Colors.white.withValues(alpha: 0.15)),
              const SizedBox(height: 8),
              _dItem(context, Icons.dashboard_rounded, "Dashboard", () => Navigator.pop(context)),
              _dItem(context, Icons.bar_chart_rounded, "My Attendance", () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => StudentAttendanceView(studentId: widget.studentId)));
              }),
              _dItem(context, Icons.score_rounded, "My Marks", () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => StudentMarksView(studentId: widget.studentId)));
              }),
              _dItem(context, Icons.campaign_rounded, "Notice Board", () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => StudentNoticeView(
                        course: widget.course, division: widget.division, collegeId: widget.collegeId)));
              }),
              _dItem(context, Icons.calendar_month_rounded, "My Timetable", () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => StudentTimetableView(
                        course: widget.course, division: widget.division, collegeId: widget.collegeId)));
              }),
            ]))),
            const Divider(color: Colors.white24, height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.white),
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
        title: Text("Welcome ${widget.studentName}",
            style: GoogleFonts.playfairDisplay(color: Colors.white, fontSize: 18)),
        centerTitle: true,
        actions: [IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => setState(() { _statsLoaded = false; _loadStats(); }))],
      ),
      body: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF1E3A5F),
              borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            child: Column(children: [
              Text("Manage Academics & Attendance",
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
              const SizedBox(height: 20),
              if (_statsLoaded)
                Row(children: [
                  _statCard("${_overallAttendance.toStringAsFixed(0)}%", "Attendance",
                      _overallAttendance >= 75 ? Icons.check_circle_outline : Icons.warning_amber_outlined,
                      _overallAttendance >= 75 ? Colors.greenAccent : Colors.redAccent),
                  const SizedBox(width: 12),
                  _statCard("$_totalSubjects", "Subjects", Icons.book_outlined, Colors.lightBlueAccent),
                  const SizedBox(width: 12),
                  _statCard(widget.course, widget.division, Icons.school_outlined, Colors.amberAccent),
                ])
              else
                const CircularProgressIndicator(color: Colors.white),
            ]),
          ),

          const SizedBox(height: 28),

          // Action Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Quick Access",
                  style: GoogleFonts.playfairDisplay(
                      fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1E3A5F))),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2, shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 1.1,
                children: [
                  _actionCard(icon: Icons.bar_chart_rounded, label: "My Attendance",
                      color: const Color(0xFF1565C0),
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => StudentAttendanceView(studentId: widget.studentId)))),
                  _actionCard(icon: Icons.score_rounded, label: "My Marks",
                      color: const Color(0xFF2E7D32),
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => StudentMarksView(studentId: widget.studentId)))),
                  _actionCard(icon: Icons.campaign_rounded, label: "Notice Board",
                      color: const Color(0xFF6A1B9A),
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => StudentNoticeView(
                              course: widget.course, division: widget.division, collegeId: widget.collegeId)))),
                  _actionCard(icon: Icons.calendar_month_rounded, label: "My Timetable",
                      color: const Color(0xFFBF360C),
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => StudentTimetableView(
                              course: widget.course, division: widget.division, collegeId: widget.collegeId)))),
                ],
              ),
            ]),
          ),

          const SizedBox(height: 28),

          // Today's Lectures
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(children: [
              const Icon(Icons.fact_check_rounded, color: Color(0xFF1E3A5F), size: 20),
              const SizedBox(width: 8),
              Text("Today's Lectures",
                  style: GoogleFonts.playfairDisplay(
                      fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E3A5F))),
            ]),
          ),
          _todayLectures(),

          // Low attendance warning
          if (_statsLoaded && _overallAttendance < 75 && _totalSubjects > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity, padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade200)),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red.shade400, size: 28),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text("Low Attendance",
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700, fontSize: 14)),
                    const SizedBox(height: 3),
                    Text("Your attendance is ${_overallAttendance.toStringAsFixed(1)}%. Minimum 75% required.",
                        style: TextStyle(fontSize: 12, color: Colors.red.shade600)),
                  ])),
                ]),
              ),
            ),

          const SizedBox(height: 30),
        ]),
      ),
    );
  }

  Widget _todayLectures() {
    final days      = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"];
    final todayName = days[DateTime.now().weekday % 7];
    final now       = DateTime.now();

    return FutureBuilder<QuerySnapshot>(
      // ✅ Filter by collegeId
      future: FirebaseFirestore.instance
          .collection("timetable")
          .where("course",    isEqualTo: widget.course)
          .where("division",  isEqualTo: widget.division)
          .where("day",       isEqualTo: todayName)
          .where("collegeId", isEqualTo: widget.collegeId)
          .get(),
      builder: (context, ttSnap) {
        if (ttSnap.connectionState == ConnectionState.waiting) {
          return const Padding(padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()));
        }

        final lectures = (ttSnap.data?.docs ?? []).toList()
          ..sort((a, b) {
            final an = ((a.data() as Map)["lectureNo"] as num?)?.toInt() ?? 0;
            final bn = ((b.data() as Map)["lectureNo"] as num?)?.toInt() ?? 0;
            return an.compareTo(bn);
          });

        if (lectures.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A5F), Color(0xFF2D5B8E)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(children: [
                const Text("🎉", style: TextStyle(fontSize: 36)),
                const SizedBox(height: 10),
                Text("No lectures today!",
                    style: GoogleFonts.montserrat(
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                Text("Enjoy your free day",
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
              ]),
            ),
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("attendance")
              .where("studentId", isEqualTo: widget.studentId)
              .snapshots(),
          builder: (context, attSnap) {
            final Map<String, String> attMap = {};
            if (attSnap.hasData) {
              for (var doc in attSnap.data!.docs) {
                final d = doc.data() as Map<String, dynamic>;
                final date = d["date"];
                if (date is Timestamp) {
                  final dt = date.toDate();
                  if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
                    final subject = d["subject"]    as String? ?? "";
                    final lNo     = (d["lectureNo"] as num?)?.toInt() ?? 1;
                    attMap["${subject}__$lNo"] = d["status"] as String? ?? "absent";
                  }
                }
              }
            }

            int presentCount = 0, absentCount = 0, pendingCount = 0;
            for (var lec in lectures) {
              final d       = lec.data() as Map<String, dynamic>;
              final subject = d["subjectName"] as String? ?? "";
              final lNo     = (d["lectureNo"]  as num?)?.toInt() ?? 1;
              final status  = attMap["${subject}__$lNo"];
              if (status == "present") presentCount++;
              else if (status == "absent") absentCount++;
              else pendingCount++;
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: [
                // Summary bar
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _pill("${lectures.length}", "Total",   Colors.white.withValues(alpha: 0.9)),
                      _vDiv(),
                      _pill("$presentCount", "Present", const Color(0xFF4ADE80)),
                      _vDiv(),
                      _pill("$absentCount",  "Absent",  const Color(0xFFFF6B6B)),
                      _vDiv(),
                      _pill("$pendingCount", "Pending", const Color(0xFFFFB347)),
                    ],
                  ),
                ),

                ...List.generate(lectures.length, (i) {
                  final d           = lectures[i].data() as Map<String, dynamic>;
                  final subject     = d["subjectName"] as String? ?? "-";
                  final room        = d["room"]        as String? ?? "TBA";
                  final startTime   = d["startTime"]   as String? ?? "";
                  final endTime     = d["endTime"]     as String? ?? "";
                  final lNo         = (d["lectureNo"]  as num?)?.toInt() ?? (i + 1);
                  final lectureType = d["lectureType"] as String? ?? "LEC"; // ✅ Fetching LAB/LEC dynamically from database
                  final status      = attMap["${subject}__$lNo"];
                  final cfg         = _statusCfg(status);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(
                          color: (cfg["color"] as Color).withValues(alpha: 0.12),
                          blurRadius: 16, offset: const Offset(0, 5))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: IntrinsicHeight(child: Row(children: [
                        Container(width: 5, decoration: BoxDecoration(
                            gradient: LinearGradient(
                                colors: [cfg["color"] as Color,
                                  (cfg["color"] as Color).withValues(alpha: 0.4)],
                                begin: Alignment.topCenter, end: Alignment.bottomCenter))),
                        Container(
                          width: 56,
                          color: (cfg["color"] as Color).withValues(alpha: 0.06),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text("$lNo", style: TextStyle(fontSize: 22,
                                fontWeight: FontWeight.w900, color: cfg["color"] as Color)),

                            // ✅ Dynamic Lecture Type (LEC or LAB)
                            Text(lectureType, style: TextStyle(fontSize: 8, letterSpacing: 1.5,
                                fontWeight: FontWeight.w700,
                                color: (cfg["color"] as Color).withValues(alpha: 0.6))),
                          ]),
                        ),
                        Expanded(child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(subject,
                                style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w700, fontSize: 14,
                                    color: const Color(0xFF1A1A2E)),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 6),
                            Wrap(spacing: 8, children: [
                              _tag(Icons.access_time_rounded, "$startTime – $endTime"),
                              _tag(Icons.meeting_room_outlined, room),
                            ]),
                          ]),
                        )),
                        Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                  color: (cfg["color"] as Color).withValues(alpha: 0.12),
                                  shape: BoxShape.circle),
                              child: Icon(cfg["icon"] as IconData,
                                  color: cfg["color"] as Color, size: 22),
                            ),
                            const SizedBox(height: 4),
                            Text(cfg["label"] as String,
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5, color: cfg["color"] as Color)),
                          ]),
                        ),
                      ])),
                    ),
                  );
                }),
              ]),
            );
          },
        );
      },
    );
  }

  Map<String, dynamic> _statusCfg(String? status) {
    if (status == "present") return {"color": const Color(0xFF22C55E), "icon": Icons.check_circle_rounded, "label": "PRESENT"};
    if (status == "absent")  return {"color": const Color(0xFFEF4444), "icon": Icons.cancel_rounded, "label": "ABSENT"};
    return {"color": const Color(0xFFF59E0B), "icon": Icons.schedule_rounded, "label": "PENDING"};
  }

  Widget _tag(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: const Color(0xFF1E3A5F).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 10, color: const Color(0xFF1E3A5F)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF1E3A5F), fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _pill(String value, String label, Color color) => Column(children: [
    Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18)),
    const SizedBox(height: 2),
    Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.w500)),
  ]);

  Widget _vDiv() => Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.15));

  Widget _statCard(String value, String label, IconData icon, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 5),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ]),
    ),
  );

  Widget _actionCard({required IconData icon, required String label,
    required Color color, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 56, height: 56,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 28)),
            const SizedBox(height: 12),
            Text(label, textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1A1A2E))),
          ]),
        ),
      );

  Widget _dItem(BuildContext ctx, IconData icon, String label, VoidCallback onTap) =>
      ListTile(leading: Icon(icon, color: Colors.white),
          title: Text(label, style: const TextStyle(color: Colors.white)), onTap: onTap);
}