import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border, BorderStyle;

// ══════════════════════════════════════════════════════
//  BULK UPLOAD STUDENTS
//  Supports: .xlsx, .xls, .csv
//  Fields: name, rollNumber, course, division, username, password
// ══════════════════════════════════════════════════════

class BulkUploadStudents extends StatefulWidget {
  const BulkUploadStudents({super.key});

  @override
  State<BulkUploadStudents> createState() => _BulkUploadStudentsState();
}

class _BulkUploadStudentsState extends State<BulkUploadStudents> {
  // ── State ──
  List<Map<String, String>> _parsedStudents = [];
  List<Map<String, String>> _errorRows      = [];
  String?  _fileName;
  bool     _isParsing    = false;
  bool     _isUploading  = false;
  int      _uploadedCount = 0;
  int      _totalCount    = 0;
  bool     _uploadDone   = false;

  static const List<String> _requiredFields = [
    "name", "rollnumber", "course", "division", "username", "password"
  ];

  // ══════════════════════════════════════
  //  PICK FILE
  // ══════════════════════════════════════
  Future<void> _pickFile() async {
    setState(() {
      _parsedStudents = [];
      _errorRows      = [];
      _fileName       = null;
      _uploadDone     = false;
    });

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    setState(() {
      _isParsing = true;
      _fileName  = file.name;
    });

    try {
      final ext = file.extension?.toLowerCase() ?? '';
      if (ext == 'csv') {
        await _parseCSV(file.bytes!);
      } else {
        await _parseExcel(file.bytes!);
      }
    } catch (e) {
      _showSnack("Error reading file: $e", isError: true);
    }

    setState(() => _isParsing = false);
  }

  // ══════════════════════════════════════
  //  PARSE EXCEL
  // ══════════════════════════════════════
  Future<void> _parseExcel(List<int> bytes) async {
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables[excel.tables.keys.first];
    if (sheet == null) {
      _showSnack("Excel sheet not found", isError: true);
      return;
    }

    final rows   = sheet.rows;
    if (rows.isEmpty) return;

    // Header row
    final headers = rows[0]
        .map((c) => (c?.value?.toString() ?? '').toLowerCase().trim())
        .toList();

    // Validate headers
    final missing = _requiredFields
        .where((f) => !headers.contains(f))
        .toList();
    if (missing.isNotEmpty) {
      _showSnack("Missing columns: ${missing.join(', ')}", isError: true);
      setState(() => _isParsing = false);
      return;
    }

    final parsed = <Map<String, String>>[];
    final errors = <Map<String, String>>[];

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      final Map<String, String> student = {};
      bool hasError = false;

      for (int j = 0; j < headers.length && j < row.length; j++) {
        student[headers[j]] = row[j]?.value?.toString().trim() ?? '';
      }

      // Validate required fields
      for (final f in _requiredFields) {
        if ((student[f] ?? '').isEmpty) {
          hasError = true;
          break;
        }
      }

      if (hasError) {
        student['_error'] = 'Row ${i + 1}: Missing required fields';
        errors.add(student);
      } else {
        parsed.add(student);
      }
    }

    setState(() {
      _parsedStudents = parsed;
      _errorRows      = errors;
    });
  }

  // ══════════════════════════════════════
  //  PARSE CSV
  // ══════════════════════════════════════
  Future<void> _parseCSV(List<int> bytes) async {
    final content = String.fromCharCodes(bytes);
    final lines   = content
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return;

    // Parse headers
    final headers = _splitCSVLine(lines[0])
        .map((h) => h.toLowerCase().trim())
        .toList();

    final missing = _requiredFields
        .where((f) => !headers.contains(f))
        .toList();
    if (missing.isNotEmpty) {
      _showSnack("Missing columns: ${missing.join(', ')}", isError: true);
      setState(() => _isParsing = false);
      return;
    }

    final parsed = <Map<String, String>>[];
    final errors = <Map<String, String>>[];

    for (int i = 1; i < lines.length; i++) {
      final cells  = _splitCSVLine(lines[i]);
      final student = <String, String>{};
      bool hasError = false;

      for (int j = 0; j < headers.length && j < cells.length; j++) {
        student[headers[j]] = cells[j].trim();
      }

      for (final f in _requiredFields) {
        if ((student[f] ?? '').isEmpty) {
          hasError = true;
          break;
        }
      }

      if (hasError) {
        student['_error'] = 'Row ${i + 1}: Missing fields';
        errors.add(student);
      } else {
        parsed.add(student);
      }
    }

    setState(() {
      _parsedStudents = parsed;
      _errorRows      = errors;
    });
  }

  List<String> _splitCSVLine(String line) {
    final result  = <String>[];
    bool inQuotes = false;
    String curr   = '';
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == ',' && !inQuotes) {
        result.add(curr);
        curr = '';
      } else {
        curr += ch;
      }
    }
    result.add(curr);
    return result;
  }

  // ══════════════════════════════════════
  //  UPLOAD TO FIREBASE
  // ══════════════════════════════════════
  Future<void> _uploadToFirebase() async {
    if (_parsedStudents.isEmpty) return;

    setState(() {
      _isUploading   = true;
      _uploadedCount = 0;
      _totalCount    = _parsedStudents.length;
      _uploadDone    = false;
    });

    int success = 0;
    int skipped = 0;

    for (final student in _parsedStudents) {
      try {
        // Check if username already exists
        final existing = await FirebaseFirestore.instance
            .collection("students")
            .where("username", isEqualTo: student["username"])
            .limit(1)
            .get();

        if (existing.docs.isNotEmpty) {
          skipped++;
        } else {
          await FirebaseFirestore.instance.collection("students").add({
            "name":        student["name"]        ?? "",
            "rollNumber":  student["rollnumber"]  ?? "",
            "course":      student["course"]      ?? "",
            "division":    student["division"]    ?? "",
            "username":    student["username"]    ?? "",
            "password":    student["password"]    ?? "",
            "createdAt":   DateTime.now().toString(),
          });
          success++;
        }

        setState(() => _uploadedCount++);
      } catch (e) {
        skipped++;
        setState(() => _uploadedCount++);
      }
    }

    setState(() {
      _isUploading = false;
      _uploadDone  = true;
    });

    _showSnack(
      "✅ $success added, $skipped skipped (duplicate username)",
      isError: false,
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ══════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text("Bulk Upload Students",
            style: GoogleFonts.playfairDisplay(
                color: Colors.white, fontSize: 20)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Format guide card ──
            _formatGuideCard(),
            const SizedBox(height: 16),

            // ── Pick file button ──
            _pickFileButton(),
            const SizedBox(height: 16),

            // ── Parsed preview ──
            if (_isParsing)
              const Center(child: CircularProgressIndicator()),

            if (_parsedStudents.isNotEmpty && !_isParsing) ...[
              _previewSection(),
              const SizedBox(height: 16),
            ],

            // ── Error rows ──
            if (_errorRows.isNotEmpty && !_isParsing) ...[
              _errorSection(),
              const SizedBox(height: 16),
            ],

            // ── Upload progress ──
            if (_isUploading) ...[
              _uploadProgress(),
              const SizedBox(height: 16),
            ],

            // ── Upload button ──
            if (_parsedStudents.isNotEmpty && !_isUploading && !_uploadDone)
              _uploadButton(),

            // ── Done state ──
            if (_uploadDone)
              _doneCard(),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  //  WIDGETS
  // ══════════════════════════════════════

  Widget _formatGuideCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.info_outline, color: Colors.white70, size: 18),
            const SizedBox(width: 8),
            Text("File Format Guide",
                style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ]),
          const SizedBox(height: 12),
          Text("Supported: .xlsx  .xls  .csv",
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
          const SizedBox(height: 8),
          // Column headers example
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Required columns (Row 1 = Header):",
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11)),
                const SizedBox(height: 6),
                _headerChips(),
                const SizedBox(height: 8),
                Text("Example row:",
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11)),
                const SizedBox(height: 4),
                Text(
                  "Rahul Sharma | 22MCA001 | MCA | A | rahul22 | pass123",
                  style: TextStyle(
                      color: Colors.greenAccent.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerChips() {
    final fields = ["name","rollNumber","course","division","username","password"];
    return Wrap(
      spacing: 6, runSpacing: 6,
      children: fields.map((f) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(f,
            style: const TextStyle(
                color: Colors.white, fontSize: 11,
                fontWeight: FontWeight.w600)),
      )).toList(),
    );
  }

  Widget _pickFileButton() {
    return GestureDetector(
      onTap: _pickFile,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: const Color(0xFF1E3A5F).withValues(alpha: 0.3),
              width: 2,
              style: BorderStyle.solid),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 8)
          ],
        ),
        child: Column(
          children: [
            Icon(
              _fileName == null
                  ? Icons.upload_file_rounded
                  : Icons.check_circle_rounded,
              size: 48,
              color: _fileName == null
                  ? const Color(0xFF1E3A5F)
                  : Colors.green,
            ),
            const SizedBox(height: 10),
            Text(
              _fileName ?? "Tap to select Excel / CSV file",
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: _fileName == null
                      ? const Color(0xFF1E3A5F)
                      : Colors.green),
              textAlign: TextAlign.center,
            ),
            if (_fileName == null) ...[
              const SizedBox(height: 4),
              Text(".xlsx  ·  .xls  ·  .csv",
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade400)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _previewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.people_rounded,
                  color: Colors.green, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "${_parsedStudents.length} students ready to upload",
                  style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
              if (_errorRows.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "${_errorRows.length} errors",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Preview table header
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A5F),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              _th("#", 30),
              _th("Name", 120),
              _th("Roll No", 80),
              _th("Course", 60),
              _th("Div", 40),
            ],
          ),
        ),

        // Preview rows (first 10)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 6)
            ],
          ),
          child: Column(
            children: [
              ...List.generate(
                  _parsedStudents.length > 10
                      ? 10
                      : _parsedStudents.length, (i) {
                final s = _parsedStudents[i];
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                            color: Colors.grey.shade100)),
                  ),
                  child: Row(
                    children: [
                      _td("${i + 1}", 30,
                          color: Colors.grey.shade400),
                      _td(s["name"] ?? "", 120,
                          bold: true),
                      _td(s["rollnumber"] ?? "", 80),
                      _td(s["course"] ?? "", 60),
                      _td(s["division"] ?? "", 40),
                    ],
                  ),
                );
              }),
              if (_parsedStudents.length > 10)
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    "... and ${_parsedStudents.length - 10} more students",
                    style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _errorSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.red.shade600, size: 20),
            const SizedBox(width: 8),
            Text("${_errorRows.length} rows skipped (missing fields)",
                style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ]),
          const SizedBox(height: 8),
          ..._errorRows.take(5).map((e) => Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              "• ${e['_error'] ?? 'Unknown error'}",
              style: TextStyle(
                  color: Colors.red.shade600, fontSize: 12),
            ),
          )),
        ],
      ),
    );
  }

  Widget _uploadProgress() {
    final pct = _totalCount > 0
        ? _uploadedCount / _totalCount
        : 0.0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8)
        ],
      ),
      child: Column(
        children: [
          Text(
            "Uploading $_uploadedCount / $_totalCount students...",
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 12,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF1E3A5F)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "${(pct * 100).toStringAsFixed(0)}%",
            style: const TextStyle(
                color: Color(0xFF1E3A5F),
                fontWeight: FontWeight.bold,
                fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _uploadButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _uploadToFirebase,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E3A5F),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.cloud_upload_rounded,
            color: Colors.white),
        label: Text(
          "Upload ${_parsedStudents.length} Students to Firebase",
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15),
        ),
      ),
    );
  }

  Widget _doneCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: Colors.greenAccent, size: 52),
          const SizedBox(height: 12),
          Text("Upload Complete!",
              style: GoogleFonts.playfairDisplay(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            "${_parsedStudents.length} students processed",
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _parsedStudents = [];
                _errorRows      = [];
                _fileName       = null;
                _uploadDone     = false;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Upload Another File",
                style: TextStyle(
                    color: Color(0xFF1E3A5F),
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _th(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(text,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold)),
    );
  }

  Widget _td(String text, double width,
      {bool bold = false, Color? color}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            fontSize: 12,
            fontWeight:
            bold ? FontWeight.w600 : FontWeight.normal,
            color: color ?? const Color(0xFF1A1A2E)),
      ),
    );
  }
}