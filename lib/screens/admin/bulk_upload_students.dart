import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border, BorderStyle;

class BulkUploadStudents extends StatefulWidget {
  final String collegeId; // ✅
  const BulkUploadStudents({super.key, required this.collegeId});

  @override
  State<BulkUploadStudents> createState() => _BulkUploadStudentsState();
}

class _BulkUploadStudentsState extends State<BulkUploadStudents> {
  List<Map<String, String>> _parsedStudents = [];
  List<Map<String, String>> _errorRows      = [];
  String? _fileName;
  bool    _isParsing   = false;
  bool    _isUploading = false;
  int     _uploadedCount = 0;
  int     _totalCount    = 0;
  bool    _uploadDone  = false;

  static const List<String> _requiredFields = [
    "name", "rollnumber", "course", "division", "username", "password"
  ];

  Future<void> _pickFile() async {
    setState(() { _parsedStudents = []; _errorRows = []; _fileName = null; _uploadDone = false; });
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['xlsx', 'xls', 'csv'], withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    setState(() { _isParsing = true; _fileName = file.name; });
    try {
      if ((file.extension ?? '').toLowerCase() == 'csv') {
        await _parseCSV(file.bytes!);
      } else {
        await _parseExcel(file.bytes!);
      }
    } catch (e) { _showSnack("Error: $e", isError: true); }
    setState(() => _isParsing = false);
  }

  Future<void> _parseExcel(List<int> bytes) async {
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables[excel.tables.keys.first];
    if (sheet == null) { _showSnack("Sheet not found", isError: true); return; }
    final rows = sheet.rows;
    if (rows.isEmpty) return;
    final headers = rows[0].map((c) => (c?.value?.toString() ?? '').toLowerCase().trim()).toList();
    final missing = _requiredFields.where((f) => !headers.contains(f)).toList();
    if (missing.isNotEmpty) { _showSnack("Missing: ${missing.join(', ')}", isError: true); return; }
    final parsed = <Map<String, String>>[], errors = <Map<String, String>>[];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      final student = <String, String>{};
      for (int j = 0; j < headers.length && j < row.length; j++) {
        student[headers[j]] = row[j]?.value?.toString().trim() ?? '';
      }
      if (_requiredFields.any((f) => (student[f] ?? '').isEmpty)) {
        student['_error'] = 'Row ${i + 1}: Missing fields';
        errors.add(student);
      } else { parsed.add(student); }
    }
    setState(() { _parsedStudents = parsed; _errorRows = errors; });
  }

  Future<void> _parseCSV(List<int> bytes) async {
    final lines = String.fromCharCodes(bytes).split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return;
    final headers = _splitCSV(lines[0]).map((h) => h.toLowerCase().trim()).toList();
    final missing = _requiredFields.where((f) => !headers.contains(f)).toList();
    if (missing.isNotEmpty) { _showSnack("Missing: ${missing.join(', ')}", isError: true); return; }
    final parsed = <Map<String, String>>[], errors = <Map<String, String>>[];
    for (int i = 1; i < lines.length; i++) {
      final cells = _splitCSV(lines[i]);
      final student = <String, String>{};
      for (int j = 0; j < headers.length && j < cells.length; j++) student[headers[j]] = cells[j].trim();
      if (_requiredFields.any((f) => (student[f] ?? '').isEmpty)) {
        student['_error'] = 'Row ${i + 1}: Missing fields'; errors.add(student);
      } else { parsed.add(student); }
    }
    setState(() { _parsedStudents = parsed; _errorRows = errors; });
  }

  List<String> _splitCSV(String line) {
    final result = <String>[]; bool inQ = false; String curr = '';
    for (final ch in line.characters) {
      if (ch == '"') { inQ = !inQ; }
      else if (ch == ',' && !inQ) { result.add(curr); curr = ''; }
      else { curr += ch; }
    }
    result.add(curr); return result;
  }

  Future<void> _uploadToFirebase() async {
    if (_parsedStudents.isEmpty) return;
    setState(() { _isUploading = true; _uploadedCount = 0; _totalCount = _parsedStudents.length; _uploadDone = false; });
    int success = 0, skipped = 0;
    for (final student in _parsedStudents) {
      try {
        // Check duplicate within same college
        final existing = await FirebaseFirestore.instance
            .collection("students")
            .where("username",  isEqualTo: student["username"])
            .where("collegeId", isEqualTo: widget.collegeId) // ✅
            .limit(1).get();
        if (existing.docs.isNotEmpty) {
          skipped++;
        } else {
          await FirebaseFirestore.instance.collection("students").add({
            "name":        student["name"]       ?? "",
            "rollNumber":  student["rollnumber"] ?? "",
            "course":      student["course"]     ?? "",
            "division":    student["division"]   ?? "",
            "username":    student["username"]   ?? "",
            "password":    student["password"]   ?? "",
            "collegeId":   widget.collegeId,  // ✅
            "createdAt":   DateTime.now().toString(),
          });
          success++;
        }
        setState(() => _uploadedCount++);
      } catch (e) { skipped++; setState(() => _uploadedCount++); }
    }
    setState(() { _isUploading = false; _uploadDone = true; });
    _showSnack("✅ $success added, $skipped skipped", isError: false);
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text("Bulk Upload Students",
            style: GoogleFonts.playfairDisplay(color: Colors.white, fontSize: 20)),
        centerTitle: true,
        actions: [
          // ✅ Refresh Button Added Here
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: "Refresh Screen",
            onPressed: () {
              setState(() {
                _parsedStudents = [];
                _errorRows = [];
                _fileName = null;
                _isParsing = false;
                _isUploading = false;
                _uploadedCount = 0;
                _totalCount = 0;
                _uploadDone = false;
              });
              _showSnack("Screen refreshed", isError: false);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Format guide
          Container(
            width: double.infinity, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF1E3A5F), borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.info_outline, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Text("File Format Guide", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ]),
              const SizedBox(height: 8),
              Text("Supported: .xlsx  .xls  .csv", style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 4,
                  children: ["name","rollNumber","course","division","username","password"].map((f) =>
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                        child: Text(f, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                      )).toList()),
            ]),
          ),
          const SizedBox(height: 16),

          // Pick file
          GestureDetector(
            onTap: _pickFile,
            child: Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1E3A5F).withValues(alpha: 0.3), width: 2),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)]),
              child: Column(children: [
                Icon(_fileName == null ? Icons.upload_file_rounded : Icons.check_circle_rounded,
                    size: 48, color: _fileName == null ? const Color(0xFF1E3A5F) : Colors.green),
                const SizedBox(height: 10),
                Text(_fileName ?? "Tap to select Excel / CSV file",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14,
                        color: _fileName == null ? const Color(0xFF1E3A5F) : Colors.green),
                    textAlign: TextAlign.center),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          if (_isParsing) const Center(child: CircularProgressIndicator()),

          // Preview
          if (_parsedStudents.isNotEmpty && !_isParsing) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200)),
              child: Row(children: [
                const Icon(Icons.people_rounded, color: Colors.green, size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text("${_parsedStudents.length} students ready",
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14))),
              ]),
            ),
            const SizedBox(height: 16),
          ],

          if (_errorRows.isNotEmpty && !_isParsing) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("${_errorRows.length} rows skipped",
                    style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
              ]),
            ),
            const SizedBox(height: 16),
          ],

          // Progress
          if (_isUploading) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)]),
              child: Column(children: [
                Text("Uploading $_uploadedCount / $_totalCount..."),
                const SizedBox(height: 12),
                ClipRRect(borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _totalCount > 0 ? _uploadedCount / _totalCount : 0,
                      minHeight: 12, backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1E3A5F)),
                    )),
              ]),
            ),
            const SizedBox(height: 16),
          ],

          // Upload button
          if (_parsedStudents.isNotEmpty && !_isUploading && !_uploadDone)
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton.icon(
                onPressed: _uploadToFirebase,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A5F),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white),
                label: Text("Upload ${_parsedStudents.length} Students",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),

          // Done
          if (_uploadDone)
            Container(
              width: double.infinity, padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 52),
                const SizedBox(height: 12),
                Text("Upload Complete!", style: GoogleFonts.playfairDisplay(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {
                    _parsedStudents = []; _errorRows = []; _fileName = null; _uploadDone = false;
                  }),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text("Upload Another File",
                      style: TextStyle(color: Color(0xFF1E3A5F), fontWeight: FontWeight.bold)),
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}