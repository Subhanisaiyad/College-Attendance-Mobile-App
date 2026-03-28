import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ══════════════════════════════════════════
//  STUDENT NOTICE VIEW
// ══════════════════════════════════════════
class StudentNoticeView extends StatefulWidget {
  final String course;
  final String division;
  final String collegeId; // ✅

  const StudentNoticeView({
    super.key,
    required this.course,
    required this.division,
    required this.collegeId,
  });

  @override
  State<StudentNoticeView> createState() => _StudentNoticeViewState();
}

class _StudentNoticeViewState extends State<StudentNoticeView> {
  static const List<Map<String, dynamic>> _categories = [
    {"label": "All",        "color": 0xFF1E3A5F, "icon": Icons.all_inbox},
    {"label": "General",    "color": 0xFF1E3A5F, "icon": Icons.info_outline},
    {"label": "Exam",       "color": 0xFFBF360C, "icon": Icons.edit_note},
    {"label": "Holiday",    "color": 0xFF2E7D32, "icon": Icons.celebration},
    {"label": "Assignment", "color": 0xFF6A1B9A, "icon": Icons.assignment},
    {"label": "Urgent",     "color": 0xFFB71C1C, "icon": Icons.warning_amber},
  ];

  String _filter = "All";

  String _timeAgo(dynamic value) {
    if (value is! Timestamp) return "";
    final dt   = value.toDate();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours   < 24) return "${diff.inHours}h ago";
    if (diff.inDays    < 7)  return "${diff.inDays}d ago";
    return "${dt.day.toString().padLeft(2,'0')}-"
        "${dt.month.toString().padLeft(2,'0')}-${dt.year}";
  }

  bool _isForMe(String target) {
    if (target == "All Students") return true;
    if (target == widget.course)  return true;
    if (target == "${widget.course} - ${widget.division}") return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text("Notices",
            style: GoogleFonts.playfairDisplay(
                color: Colors.white, fontSize: 20)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Filter tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: _categories.map((cat) {
                  final bool sel = _filter == cat["label"];
                  final color    = Color(cat["color"] as int);
                  return GestureDetector(
                    onTap: () => setState(() => _filter = cat["label"]),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel ? color : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(cat["icon"] as IconData,
                              size: 13,
                              color: sel ? Colors.white : Colors.grey.shade600),
                          const SizedBox(width: 5),
                          Text(cat["label"] as String,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: sel ? Colors.white : Colors.grey.shade700)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("notices")
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _empty("No notices yet");
                }

                // Filter: for me + category
                var docs = snapshot.data!.docs.where((doc) {
                  final d      = doc.data() as Map<String, dynamic>;
                  final target = d["target"] as String? ?? "All Students";
                  final cat    = d["category"] as String? ?? "General";
                  final matchTarget = _isForMe(target);
                  final matchCat    = _filter == "All" || cat == _filter;
                  return matchTarget && matchCat;
                }).toList();

                // Sort newest first
                docs.sort((a, b) {
                  final at = (a.data() as Map)["postedAt"];
                  final bt = (b.data() as Map)["postedAt"];
                  if (at is Timestamp && bt is Timestamp) return bt.compareTo(at);
                  return 0;
                });

                if (docs.isEmpty) return _empty("No notices for you");

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final d          = docs[i].data() as Map<String, dynamic>;
                    final catLabel   = d["category"]    as String? ?? "General";
                    final catData    = _categories.firstWhere(
                            (c) => c["label"] == catLabel,
                        orElse: () => _categories[1]);
                    final color      = Color(catData["color"] as int);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(
                            color: color.withValues(alpha: 0.08),
                            blurRadius: 10, offset: const Offset(0, 3))],
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            Container(
                              width: 5,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  bottomLeft: Radius.circular(16),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(catData["icon"] as IconData,
                                                  size: 11, color: color),
                                              const SizedBox(width: 4),
                                              Text(catLabel,
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: color,
                                                      fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(_timeAgo(d["postedAt"]),
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey.shade400)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(d["title"] as String? ?? "",
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: Color(0xFF1A1A2E))),
                                    const SizedBox(height: 5),
                                    Text(d["message"] as String? ?? "",
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                            height: 1.4)),
                                    const SizedBox(height: 8),
                                    Text(
                                      "By ${d["teacherName"] ?? "Teacher"}",
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade400,
                                          fontStyle: FontStyle.italic),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
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
    );
  }

  Widget _empty(String msg) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.campaign_outlined,
            size: 64,
            color: const Color(0xFF1E3A5F).withValues(alpha: 0.3)),
        const SizedBox(height: 16),
        Text(msg,
            style: GoogleFonts.montserrat(
                fontSize: 16, color: Colors.grey)),
      ],
    ),
  );
}

// ══════════════════════════════════════════
//  STUDENT TIMETABLE VIEW
// ══════════════════════════════════════════
class StudentTimetableView extends StatefulWidget {
  final String course;
  final String division;
  final String collegeId; // ✅

  const StudentTimetableView({
    super.key,
    required this.course,
    required this.division,
    required this.collegeId,
  });

  @override
  State<StudentTimetableView> createState() => _StudentTimetableViewState();
}

class _StudentTimetableViewState extends State<StudentTimetableView> {
  static const List<String> _days = [
    "Monday", "Tuesday", "Wednesday",
    "Thursday", "Friday", "Saturday"
  ];

  static const List<Color> _colors = [
    Color(0xFF1E3A5F), Color(0xFF2E7D32), Color(0xFF6A1B9A),
    Color(0xFFBF360C), Color(0xFF00695C), Color(0xFF1565C0),
  ];

  final Map<String, int> _colorIdx = {};
  int _colorCount = 0;

  Color _colorFor(String subject) {
    _colorIdx.putIfAbsent(subject, () => _colorCount++ % _colors.length);
    return _colors[_colorIdx[subject]!];
  }

  String get _todayName {
    const d = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"];
    return d[DateTime.now().weekday % 7];
  }

  late String _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _days.contains(_todayName) ? _todayName : "Monday";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text("My Timetable",
            style: GoogleFonts.playfairDisplay(
                color: Colors.white, fontSize: 20)),
        centerTitle: true,
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection("timetable")
            .where("course",    isEqualTo: widget.course)
            .where("division",  isEqualTo: widget.division)
            .where("collegeId", isEqualTo: widget.collegeId) // ✅
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final Map<String, List<Map<String, dynamic>>> byDay = {};
          for (var day in _days) byDay[day] = [];

          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              final d   = doc.data() as Map<String, dynamic>;
              final day = d["day"] as String? ?? "";
              if (byDay.containsKey(day)) byDay[day]!.add(d);
            }
            for (var day in _days) {
              byDay[day]!.sort((a, b) {
                final an = (a["lectureNo"] as num?)?.toInt() ?? 0;
                final bn = (b["lectureNo"] as num?)?.toInt() ?? 0;
                return an.compareTo(bn);
              });
            }
          }

          final lectures = byDay[_selectedDay] ?? [];

          return Column(
            children: [
              // Info strip
              Container(
                color: const Color(0xFF1E3A5F),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    const Icon(Icons.school, color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    Text("${widget.course} - Division ${widget.division}",
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text("Today: $_todayName",
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11)),
                    ),
                  ],
                ),
              ),

              // Day tabs
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: _days.map((day) {
                      final bool sel   = day == _selectedDay;
                      final bool today = day == _todayName;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedDay = day),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel
                                ? const Color(0xFF1E3A5F)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: today && !sel
                                ? Border.all(
                                color: const Color(0xFF1E3A5F),
                                width: 1.5)
                                : null,
                          ),
                          child: Column(
                            children: [
                              Text(day.substring(0, 3),
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: sel
                                          ? Colors.white
                                          : const Color(0xFF1E3A5F))),
                              if (today)
                                Container(
                                  margin: const EdgeInsets.only(top: 3),
                                  width: 5, height: 5,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: sel
                                        ? Colors.white
                                        : const Color(0xFF1E3A5F),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Text(_selectedDay,
                        style: GoogleFonts.playfairDisplay(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E3A5F))),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A5F).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "${lectures.length} lecture${lectures.length != 1 ? 's' : ''}",
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1E3A5F),
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: lectures.isEmpty
                    ? Center(
                    child: Text("No lectures on $_selectedDay",
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 15)))
                    : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: lectures.length,
                  itemBuilder: (context, i) {
                    final l         = lectures[i];
                    final subject   = l["subjectName"] as String? ?? "";
                    final room      = l["room"]        as String? ?? "TBA";
                    final startTime   = l["startTime"]   as String? ?? "";
                    final endTime     = l["endTime"]     as String? ?? "";
                    final lectureNo   = (l["lectureNo"]  as num?)?.toInt() ?? (i + 1);
                    final lectureType = l["lectureType"] as String? ?? "LEC";
                    final color       = _colorFor(subject);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(
                            color: color.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 3))],
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  bottomLeft: Radius.circular(16),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text("L$lectureNo",
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18)),
                                  Text(lectureType,
                                      style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 9,
                                          letterSpacing: 1)),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(subject,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: color)),
                                    const SizedBox(height: 6),
                                    Row(children: [
                                      const Icon(Icons.room_outlined,
                                          size: 13, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(room,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600)),
                                      const SizedBox(width: 12),
                                      const Icon(Icons.access_time,
                                          size: 13, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text("$startTime – $endTime",
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600)),
                                    ]),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}