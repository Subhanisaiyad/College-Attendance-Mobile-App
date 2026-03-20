import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../../utils/pdf_download.dart'; // ✅ conditional import

class PreviousAttendance extends StatelessWidget {
  final String teacherId;

  const PreviousAttendance({
    super.key,
    required this.teacherId,
  });

  String formatDate(dynamic value) {
    if (value == null) return "Unknown";
    if (value is Timestamp) {
      final dt = value.toDate();
      return "${dt.day.toString().padLeft(2, '0')}-"
          "${dt.month.toString().padLeft(2, '0')}-${dt.year}";
    }
    return value.toString();
  }

  static final PdfColor _navy       = PdfColor.fromHex("1E3A5F");
  static final PdfColor _navyLight  = PdfColor.fromHex("F0F5FF");
  static final PdfColor _navyBorder = PdfColor.fromHex("BBCCEE");
  static final PdfColor _rowAlt     = PdfColor.fromHex("F7FAFF");

  Future<void> _generateAndOpenPdf(
      BuildContext context, {
        required String subject,
        required String course,
        required String division,
        required String date,
        required dynamic rawDate,
        required int present,
        required int absent,
        required int lectureNo,
      }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF1E3A5F)),
      ),
    );

    try {
      final snap = await FirebaseFirestore.instance
          .collection("attendance")
          .where("teacherId", isEqualTo: teacherId)
          .where("subject",   isEqualTo: subject)
          .get();

      final allDocs = snap.docs.where((doc) {
        final d           = doc.data() as Map<String, dynamic>;
        final docCourse   = d["course"]   as String? ?? "";
        final docDivision = d["division"] as String? ?? "";
        if (docCourse != course || docDivision != division) return false;

        if (rawDate is Timestamp) {
          final dt         = rawDate.toDate();
          final startOfDay = DateTime(dt.year, dt.month, dt.day, 0, 0, 0);
          final endOfDay   = DateTime(dt.year, dt.month, dt.day, 23, 59, 59);
          final docDate    = d["date"];
          if (docDate is Timestamp) {
            final docDt = docDate.toDate();
            if (docDt.isBefore(startOfDay) || docDt.isAfter(endOfDay)) {
              return false;
            }
          }
        }
        return true;
      }).toList();

      final List<Map<String, dynamic>> rows = [];
      for (var doc in allDocs) {
        final d         = doc.data() as Map<String, dynamic>;
        final studentId = d["studentId"] as String? ?? "";
        final status    = d["status"]    as String? ?? "absent";

        String name       = studentId;
        String rollNumber = "-";

        if (studentId.isNotEmpty) {
          try {
            final sDoc = await FirebaseFirestore.instance
                .collection("students")
                .doc(studentId)
                .get();
            if (sDoc.exists) {
              final sd  = sDoc.data() as Map<String, dynamic>;
              name       = sd["username"]   as String? ??
                  sd["name"]       as String? ?? studentId;
              rollNumber = sd["rollnumber"] as String? ?? "-";
            }
          } catch (_) {}
        }

        rows.add({
          "name":       name,
          "rollNumber": rollNumber,
          "status":     status,
        });
      }

      rows.sort((a, b) =>
          (a["name"] as String).compareTo(b["name"] as String));

      final int    total = present + absent;
      final double pct   = total > 0 ? (present / total * 100) : 0.0;

      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (pw.Context ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [

              // ── Header ──
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
                decoration: pw.BoxDecoration(
                  color: _navy,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "Attendance Report",
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      "CampusHub · Generated: ${formatDate(Timestamp.now())}",
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 16),

              // ── Info Box ──
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: _navyLight,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: _navyBorder, width: 0.8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(subject,
                        style: pw.TextStyle(
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold,
                          color: _navy,
                        )),
                    pw.SizedBox(height: 4),
                    pw.Text("Lecture No. $lectureNo",
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: _navy,
                        )),
                    pw.SizedBox(height: 10),
                    pw.Row(children: [
                      _infoCell("Course", "$course - $division"),
                      pw.SizedBox(width: 30),
                      _infoCell("Date", date),
                    ]),
                    pw.SizedBox(height: 8),
                    pw.Row(children: [
                      _infoCell("Present", "$present",
                          valueColor: PdfColors.green800),
                      pw.SizedBox(width: 30),
                      _infoCell("Absent", "$absent",
                          valueColor: PdfColors.red700),
                      pw.SizedBox(width: 30),
                      _infoCell("Total", "$total", valueColor: _navy),
                      pw.SizedBox(width: 30),
                      _infoCell(
                        "Attendance %",
                        "${pct.toStringAsFixed(1)}%",
                        valueColor: pct >= 75
                            ? PdfColors.green800
                            : PdfColors.red700,
                      ),
                    ]),
                  ],
                ),
              ),

              pw.SizedBox(height: 18),

              pw.Text("Student-wise Attendance",
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: _navy,
                  )),

              pw.SizedBox(height: 8),

              // ── Table ──
              pw.Table(
                border: pw.TableBorder.all(color: _navyBorder, width: 0.5),
                columnWidths: {
                  0: const pw.FixedColumnWidth(28),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: _navy),
                    children: [
                      _cell("#",            isHeader: true),
                      _cell("Student Name", isHeader: true),
                      _cell("Roll No.",     isHeader: true),
                      _cell("Status",       isHeader: true),
                    ],
                  ),
                  ...rows.asMap().entries.map((e) {
                    final i       = e.key;
                    final r       = e.value;
                    final bool ok = r["status"] == "present";
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: i.isEven ? PdfColors.white : _rowAlt,
                      ),
                      children: [
                        _cell("${i + 1}"),
                        _cell(r["name"]       as String? ?? "-"),
                        _cell(r["rollNumber"] as String? ?? "-"),
                        _cell(
                          ok ? "Present" : "Absent",
                          valueColor: ok
                              ? PdfColors.green800
                              : PdfColors.red700,
                          bold: true,
                        ),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 16),
              pw.Divider(color: _navyBorder, thickness: 0.6),
              pw.SizedBox(height: 6),

              // ── Footer ──
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "Present: $present  |  Absent: $absent  |  Total: $total",
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _navy,
                    ),
                  ),
                  pw.Text(
                    "Attendance: ${pct.toStringAsFixed(1)}%",
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: pct >= 75
                          ? PdfColors.green800
                          : PdfColors.red700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      if (context.mounted) Navigator.pop(context);

      final pdfBytes = await pdf.save();
      final fileName = "${subject}_${course}_${division}_$date.pdf"
          .replaceAll(" ", "_")
          .replaceAll("/", "-");

      if (kIsWeb) {
        // ✅ Web pe browser download
        await downloadPdfWeb(pdfBytes, fileName);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("PDF downloaded!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // ✅ Mobile pe open
        final dir  = await getTemporaryDirectory();
        final file = File("${dir.path}/$fileName");
        await file.writeAsBytes(pdfBytes);
        final result = await OpenFile.open(file.path);
        if (result.type != ResultType.done && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Could not open PDF: ${result.message}"),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  pw.Widget _infoCell(String label, String value,
      {PdfColor valueColor = PdfColors.black}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: const pw.TextStyle(
                fontSize: 8, color: PdfColors.grey600)),
        pw.SizedBox(height: 2),
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: valueColor)),
      ],
    );
  }

  pw.Widget _cell(
      String text, {
        bool isHeader    = false,
        PdfColor? valueColor,
        bool bold        = false,
      }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 9 : 8,
          fontWeight: (isHeader || bold)
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
          color: isHeader
              ? PdfColors.white
              : (valueColor ?? PdfColors.black),
        ),
      ),
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
          "Previous Attendance",
          style: GoogleFonts.playfairDisplay(
              color: Colors.white, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("attendance")
            .where("teacherId", isEqualTo: teacherId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history,
                      size: 60,
                      color: const Color(0xFF1E3A5F).withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text("No Attendance Records Found",
                      style: GoogleFonts.montserrat(
                          fontSize: 16, color: Colors.grey)),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final ad = (a.data() as Map)["date"];
              final bd = (b.data() as Map)["date"];
              if (ad is Timestamp && bd is Timestamp) {
                return bd.compareTo(ad);
              }
              return 0;
            });

          final Map<String, Map<String, dynamic>> grouped = {};
          for (var doc in docs) {
            final d         = doc.data() as Map<String, dynamic>;
            final subject   = d["subject"]   as String? ?? "Unknown";
            final course    = d["course"]    as String? ?? "";
            final div       = d["division"]  as String? ?? "";
            final rawDate   = d["date"];
            final dateStr   = formatDate(rawDate);
            final lectureNo = (d["lectureNo"] as num?)?.toInt() ?? 1;
            final key       = "$subject||$course||$div||$dateStr||$lectureNo";

            grouped.putIfAbsent(key, () => {
              "subject":   subject,
              "course":    course,
              "division":  div,
              "date":      dateStr,
              "rawDate":   rawDate,
              "lectureNo": lectureNo,
              "present":   (d["present"] as num?)?.toInt() ?? 0,
              "absent":    (d["absent"]  as num?)?.toInt() ?? 0,
            });
          }

          final list = grouped.values.toList();

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                color: const Color(0xFF1E3A5F).withOpacity(0.07),
                child: Row(
                  children: [
                    const Icon(Icons.touch_app,
                        color: Color(0xFF1E3A5F), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      kIsWeb
                          ? "Tap to download PDF"
                          : "Tap to open PDF",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final item    = list[index];
                    final int p   = item["present"] as int;
                    final int a   = item["absent"]  as int;
                    final int t   = p + a;
                    final int lNo = item["lectureNo"] as int? ?? 1;

                    return GestureDetector(
                      onTap: () => _generateAndOpenPdf(
                        context,
                        subject:   item["subject"],
                        course:    item["course"],
                        division:  item["division"],
                        date:      item["date"],
                        rawDate:   item["rawDate"],
                        present:   p,
                        absent:    a,
                        lectureNo: lNo,
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 8)
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E3A5F).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.calendar_today_rounded,
                                      color: Color(0xFF1E3A5F), size: 18),
                                  Text("L$lNo",
                                      style: const TextStyle(
                                          color: Color(0xFF1E3A5F),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item["subject"],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Color(0xFF1A1A2E),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    "${item["course"]} - ${item["division"]}  ·  ${item["date"]}",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(children: [
                                    _badge("P: $p", Colors.green),
                                    const SizedBox(width: 6),
                                    _badge("A: $a", Colors.red),
                                    const SizedBox(width: 6),
                                    _badge("T: $t", const Color(0xFF1E3A5F)),
                                  ]),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                const Icon(Icons.picture_as_pdf_rounded,
                                    color: Colors.red, size: 26),
                                const SizedBox(height: 2),
                                Text(
                                  "PDF",
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.red.shade400,
                                    fontWeight: FontWeight.bold,
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
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}