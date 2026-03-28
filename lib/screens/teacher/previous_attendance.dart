import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:printing/printing.dart';

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

  // ── Open PDF ──
  Future<void> _openPdf(
      BuildContext context, Uint8List bytes, String fileName) async {
    if (kIsWeb) {
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } else {
      final dir    = await getTemporaryDirectory();
      final file   = File("${dir.path}/$fileName");
      await file.writeAsBytes(bytes);
      final result = await OpenFile.open(file.path);
      if (result.type != ResultType.done && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${result.message}"),
              backgroundColor: Colors.orange),
        );
      }
    }
  }

  // ══════════════════════════
  //  PDF GENERATION
  // ══════════════════════════
  Future<void> _makePdf(BuildContext context, {
    required String subject,
    required String course,
    required String division,
    required String date,
    required dynamic rawDate,
    required int lectureNo,
  }) async {
    // Show loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF1E3A5F))),
    );

    try {
      // ── Fetch ALL attendance of this teacher+subject ──
      final snap = await FirebaseFirestore.instance
          .collection("attendance")
          .where("teacherId", isEqualTo: teacherId)
          .where("subject",   isEqualTo: subject)
          .get();

      // ── Filter by course + division + date (client side) ──
      final List<Map<String, dynamic>> rows = [];

      for (final doc in snap.docs) {
        final d = doc.data();

        // Course & division match
        if ((d["course"]   ?? "") != course)   continue;
        if ((d["division"] ?? "") != division) continue;

        // Date match
        if (rawDate is Timestamp) {
          final t  = rawDate.toDate();
          final dd = d["date"];
          if (dd is Timestamp) {
            final dt = dd.toDate();
            if (dt.year != t.year || dt.month != t.month || dt.day != t.day) continue;
          } else continue;
        }

        // ── Use studentName directly — already saved in Firebase ──
        final name   = d["studentName"] as String? ?? "";
        final status = d["status"]      as String? ?? "absent";
        final sid    = d["studentId"]   as String? ?? "";

        // Get rollNumber from students collection
        String roll = "";
        try {
          final sDoc = await FirebaseFirestore.instance
              .collection("students").doc(sid).get();
          if (sDoc.exists) {
            roll = (sDoc.data() as Map)["rollNumber"] as String? ?? "";
          }
        } catch (_) {}

        rows.add({
          "name":   name.isNotEmpty ? name : sid,
          "roll":   roll,
          "status": status,
        });
      }

      // Sort by roll number
      rows.sort((a, b) => (a["roll"] as String).compareTo(b["roll"] as String));

      final presentRows = rows.where((r) => r["status"] == "present").toList();
      final absentRows  = rows.where((r) => r["status"] == "absent").toList();
      final total       = rows.length;
      final p           = presentRows.length;
      final ab          = absentRows.length;
      final pct         = total > 0 ? p / total * 100.0 : 0.0;

      // ── Build PDF ──
      final navy      = PdfColor.fromHex("1E3A5F");
      final navyLight = PdfColor.fromHex("F0F5FF");
      final navyBord  = PdfColor.fromHex("BBCCEE");

      final pdf = pw.Document();
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => [

          // ── Header ──
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: pw.BoxDecoration(
                color: navy, borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("Attendance Report",
                    style: pw.TextStyle(fontSize: 20,
                        fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                pw.SizedBox(height: 4),
                pw.Text("CampusHub  ·  Generated: ${formatDate(Timestamp.now())}",
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.white)),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // ── Info box ──
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: navyLight,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: navyBord, width: 0.8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(subject,
                    style: pw.TextStyle(fontSize: 15,
                        fontWeight: pw.FontWeight.bold, color: navy)),
                pw.SizedBox(height: 3),
                pw.Text("Lecture No. $lectureNo",
                    style: pw.TextStyle(fontSize: 10, color: navy)),
                pw.SizedBox(height: 8),
                pw.Row(children: [
                  _iCell("Course",   "$course - $division", navy),
                  pw.SizedBox(width: 24),
                  _iCell("Date", date, navy),
                  pw.SizedBox(width: 24),
                  _iCell("Present", "$p", PdfColors.green800),
                  pw.SizedBox(width: 24),
                  _iCell("Absent",  "$ab", PdfColors.red700),
                  pw.SizedBox(width: 24),
                  _iCell("Total",   "$total", navy),
                  pw.SizedBox(width: 24),
                  _iCell("Attendance", "${pct.toStringAsFixed(1)}%",
                      pct >= 75 ? PdfColors.green800 : PdfColors.red700),
                ]),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // ── Table heading ──
          pw.Text("Student-wise Attendance",
              style: pw.TextStyle(fontSize: 12,
                  fontWeight: pw.FontWeight.bold, color: navy)),
          pw.SizedBox(height: 6),

          // ── Table ──
          pw.Table(
            border: pw.TableBorder.all(color: navyBord, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(26),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(1.5),
            },
            children: [
              // Header row
              pw.TableRow(
                decoration: pw.BoxDecoration(color: navy),
                children: [
                  _tCell("#",            true, null),
                  _tCell("Student Name", true, null),
                  _tCell("Roll No.",     true, null),
                  _tCell("Status",       true, null),
                ],
              ),
              // Data rows
              ...rows.asMap().entries.map((e) {
                final i  = e.key;
                final r  = e.value;
                final ok = r["status"] == "present";
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                      color: i.isEven ? PdfColors.white
                          : PdfColor.fromHex("F7FAFF")),
                  children: [
                    _tCell("${i + 1}", false, null),
                    _tCell(r["name"] as String, false, null),
                    _tCell(r["roll"] as String, false, null),
                    _tCell(ok ? "Present ✓" : "Absent ✗",
                        false,
                        ok ? PdfColors.green800 : PdfColors.red700),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 14),

          // ── Absent list ──
          if (absentRows.isNotEmpty) ...[
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex("FFF0F0"),
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(
                    color: PdfColor.fromHex("FFCCCC"), width: 0.8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Absent (${absentRows.length})",
                      style: pw.TextStyle(fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red800)),
                  pw.SizedBox(height: 6),
                  pw.Wrap(
                    spacing: 6, runSpacing: 4,
                    children: absentRows.map((r) {
                      final roll = r["roll"] as String;
                      final name = r["name"] as String;
                      return pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: pw.BorderRadius.circular(4),
                          border: pw.Border.all(
                              color: PdfColors.red300, width: 0.5),
                        ),
                        child: pw.Text(
                          roll.isNotEmpty ? roll : name,
                          style: const pw.TextStyle(
                              fontSize: 9, color: PdfColors.red800),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
          ],

          // ── Present list ──
          if (presentRows.isNotEmpty)
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex("F0FFF4"),
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(
                    color: PdfColor.fromHex("AADDBB"), width: 0.8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Present (${presentRows.length})",
                      style: pw.TextStyle(fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green800)),
                  pw.SizedBox(height: 6),
                  pw.Wrap(
                    spacing: 6, runSpacing: 4,
                    children: presentRows.map((r) {
                      final roll = r["roll"] as String;
                      final name = r["name"] as String;
                      return pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: pw.BorderRadius.circular(4),
                          border: pw.Border.all(
                              color: PdfColors.green300, width: 0.5),
                        ),
                        child: pw.Text(
                          roll.isNotEmpty ? roll : name,
                          style: const pw.TextStyle(
                              fontSize: 9, color: PdfColors.green800),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

          pw.SizedBox(height: 10),
          pw.Divider(color: navyBord, thickness: 0.5),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text("Present: $p  |  Absent: $ab  |  Total: $total",
                  style: pw.TextStyle(fontSize: 9,
                      fontWeight: pw.FontWeight.bold, color: navy)),
              pw.Text("Attendance: ${pct.toStringAsFixed(1)}%",
                  style: pw.TextStyle(fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: pct >= 75
                          ? PdfColors.green800 : PdfColors.red700)),
            ],
          ),
        ],
      ));

      if (context.mounted) Navigator.pop(context);

      final Uint8List pdfBytes = await pdf.save();
      final fileName = "${subject}_${course}_${division}_$date.pdf"
          .replaceAll(" ", "_").replaceAll("/", "-");
      await _openPdf(context, pdfBytes, fileName);

    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  pw.Widget _iCell(String label, String value, PdfColor color) =>
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(label,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        pw.SizedBox(height: 2),
        pw.Text(value,
            style: pw.TextStyle(fontSize: 10,
                fontWeight: pw.FontWeight.bold, color: color)),
      ]);

  pw.Widget _tCell(String text, bool header, PdfColor? color) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(text,
            style: pw.TextStyle(
              fontSize: header ? 9 : 8,
              fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: header ? PdfColors.white : (color ?? PdfColors.black),
            )),
      );

  // ══════════════════════════
  //  BUILD
  // ══════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text("Previous Attendance",
            style: GoogleFonts.playfairDisplay(
                color: Colors.white, fontSize: 20)),
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
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.history, size: 60,
                    color: const Color(0xFF1E3A5F).withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                Text("No Attendance Records Found",
                    style: GoogleFonts.montserrat(
                        fontSize: 16, color: Colors.grey)),
              ]),
            );
          }

          final docs = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final ad = (a.data() as Map)["date"];
              final bd = (b.data() as Map)["date"];
              if (ad is Timestamp && bd is Timestamp) return bd.compareTo(ad);
              return 0;
            });

          // Group records
          final Map<String, Map<String, dynamic>> grouped = {};
          for (var doc in docs) {
            final d       = doc.data() as Map<String, dynamic>;
            final subject = d["subject"]  as String? ?? "";
            final course  = d["course"]   as String? ?? "";
            final div     = d["division"] as String? ?? "";
            final rawDate = d["date"];
            final dateStr = formatDate(rawDate);
            final lNo     = (d["lectureNo"] as num?)?.toInt() ?? 1;
            final key     = "$subject||$course||$div||$dateStr||$lNo";

            grouped.putIfAbsent(key, () => {
              "subject":   subject,
              "course":    course,
              "division":  div,
              "date":      dateStr,
              "rawDate":   rawDate,
              "lectureNo": lNo,
              "present":   (d["present"] as num?)?.toInt() ?? 0,
              "absent":    (d["absent"]  as num?)?.toInt() ?? 0,
            });
          }

          final list = grouped.values.toList();

          return Column(children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFF1E3A5F).withValues(alpha: 0.07),
              child: Row(children: [
                const Icon(Icons.touch_app,
                    color: Color(0xFF1E3A5F), size: 16),
                const SizedBox(width: 8),
                Text("Tap any record to open PDF",
                    style: TextStyle(fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic)),
              ]),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final item = list[i];
                  final int p   = item["present"] as int;
                  final int a   = item["absent"]  as int;
                  final int t   = p + a;
                  final int lNo = item["lectureNo"] as int? ?? 1;

                  return GestureDetector(
                    onTap: () => _makePdf(context,
                      subject:   item["subject"],
                      course:    item["course"],
                      division:  item["division"],
                      date:      item["date"],
                      rawDate:   item["rawDate"],
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
                      child: Row(children: [
                        Container(
                          width: 50, height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A5F)
                                .withValues(alpha: 0.1),
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
                              ]),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item["subject"],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Color(0xFF1A1A2E))),
                                const SizedBox(height: 3),
                                Text(
                                  "${item["course"]} - ${item["division"]}  ·  ${item["date"]}",
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500),
                                ),
                                const SizedBox(height: 6),
                                Row(children: [
                                  _badge("P: $p", Colors.green),
                                  const SizedBox(width: 6),
                                  _badge("A: $a", Colors.red),
                                  const SizedBox(width: 6),
                                  _badge("T: $t",
                                      const Color(0xFF1E3A5F)),
                                ]),
                              ]),
                        ),
                        Column(children: [
                          const Icon(Icons.picture_as_pdf_rounded,
                              color: Colors.red, size: 26),
                          Text("PDF",
                              style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.red.shade400,
                                  fontWeight: FontWeight.bold)),
                        ]),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(text,
        style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600)),
  );
}