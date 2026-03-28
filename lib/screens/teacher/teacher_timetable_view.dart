import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewTimetable extends StatefulWidget {
  final String teacherId;
  final String teacherName;
  final String collegeId; // ✅

  const ViewTimetable({
    super.key,
    required this.teacherId,
    required this.teacherName,
    required this.collegeId,
  });

  @override
  State<ViewTimetable> createState() => _ViewTimetableState();
}

class _ViewTimetableState extends State<ViewTimetable> {
  // Days order
  static const List<String> _allDays = [
    "Monday", "Tuesday", "Wednesday",
    "Thursday", "Friday", "Saturday"
  ];

  // Today's day name
  String get _todayName {
    const days = [
      "Sunday", "Monday", "Tuesday", "Wednesday",
      "Thursday", "Friday", "Saturday"
    ];
    return days[DateTime.now().weekday % 7];
  }

  late String _selectedDay;

  @override
  void initState() {
    super.initState();
    // Default: aaj ka din select karo (agar weekday ho)
    _selectedDay = _allDays.contains(_todayName) ? _todayName : "Monday";
  }

  // Color per subject — consistent across days
  static const List<Color> _subjectColors = [
    Color(0xFF1E3A5F),
    Color(0xFF2E7D32),
    Color(0xFF6A1B9A),
    Color(0xFFBF360C),
    Color(0xFF00695C),
    Color(0xFF1565C0),
    Color(0xFF4E342E),
    Color(0xFF283593),
  ];

  final Map<String, int> _subjectColorIndex = {};
  int _colorCounter = 0;

  Color _colorForSubject(String subject) {
    if (!_subjectColorIndex.containsKey(subject)) {
      _subjectColorIndex[subject] =
          _colorCounter % _subjectColors.length;
      _colorCounter++;
    }
    return _subjectColors[_subjectColorIndex[subject]!];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E6),

      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "My Timetable",
          style: GoogleFonts.playfairDisplay(
              color: Colors.white, fontSize: 20),
        ),
        centerTitle: true,
      ),

      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection("timetable")
            .where("teacherId", isEqualTo: widget.teacherId)
            .where("collegeId", isEqualTo: widget.collegeId) // ✅
            .get(),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_month,
                      size: 64,
                      color: const Color(0xFF1E3A5F).withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text("No Timetable Found",
                      style: GoogleFonts.montserrat(
                          fontSize: 16, color: Colors.grey)),
                ],
              ),
            );
          }

          // ── Group by day ──
          final Map<String, List<Map<String, dynamic>>> byDay = {};
          for (var day in _allDays) {
            byDay[day] = [];
          }

          for (var doc in snapshot.data!.docs) {
            final d   = doc.data() as Map<String, dynamic>;
            final day = d["day"] as String? ?? "";
            if (byDay.containsKey(day)) {
              byDay[day]!.add(d);
            }
          }

          // Sort each day by lectureNo
          for (var day in _allDays) {
            byDay[day]!.sort((a, b) {
              final an = (a["lectureNo"] as num?)?.toInt() ?? 0;
              final bn = (b["lectureNo"] as num?)?.toInt() ?? 0;
              return an.compareTo(bn);
            });
          }

          final selectedLectures = byDay[_selectedDay] ?? [];

          return Column(
            children: [
              // ── Teacher info strip ──
              Container(
                color: const Color(0xFF1E3A5F),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.person,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.teacherName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14),
                      ),
                    ),
                    // Today badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "Today: $_todayName",
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Day selector tabs ──
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: _allDays.map((day) {
                      final bool isSelected = day == _selectedDay;
                      final bool isToday    = day == _todayName;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedDay = day),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF1E3A5F)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: isToday && !isSelected
                                ? Border.all(
                                color: const Color(0xFF1E3A5F),
                                width: 1.5)
                                : null,
                          ),
                          child: Column(
                            children: [
                              Text(
                                day.substring(0, 3), // Mon, Tue...
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF1E3A5F),
                                ),
                              ),
                              if (isToday)
                                Container(
                                  margin: const EdgeInsets.only(top: 3),
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
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

              // ── Lectures count ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Row(
                  children: [
                    Text(
                      _selectedDay,
                      style: GoogleFonts.playfairDisplay(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E3A5F)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A5F).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "${selectedLectures.length} lecture${selectedLectures.length != 1 ? 's' : ''}",
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1E3A5F),
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Lectures list ──
              Expanded(
                child: selectedLectures.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.free_breakfast_outlined,
                          size: 50,
                          color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        "No lectures on $_selectedDay",
                        style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: selectedLectures.length,
                  itemBuilder: (context, i) {
                    final lec       = selectedLectures[i];
                    final subject   = lec["subjectName"] as String? ?? "Unknown";
                    final course    = lec["course"]      as String? ?? "";
                    final division  = lec["division"]    as String? ?? "";
                    final room      = lec["room"]        as String? ?? "TBA";
                    final startTime = lec["startTime"]   as String? ?? "";
                    final endTime   = lec["endTime"]     as String? ?? "";
                    final lectureNo   = (lec["lectureNo"]   as num?)?.toInt() ?? (i + 1);
                    final lectureType = lec["lectureType"] as String? ?? "LEC";
                    final color       = _colorForSubject(subject);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            // ── Color strip + lecture no ──
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
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "L$lectureNo",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    lectureType,
                                    style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 9,
                                        letterSpacing: 1),
                                  ),
                                ],
                              ),
                            ),

                            // ── Content ──
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      subject,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: color,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        _infoChip(
                                          Icons.school_outlined,
                                          "$course - $division",
                                        ),
                                        const SizedBox(width: 8),
                                        _infoChip(
                                          Icons.room_outlined,
                                          room,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.access_time,
                                          size: 13,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "$startTime – $endTime",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color:
                                            Colors.grey.shade600,
                                            fontWeight:
                                            FontWeight.w500,
                                          ),
                                        ),
                                      ],
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
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey.shade500),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }
}