import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewStudents extends StatefulWidget {
  const ViewStudents({super.key});

  @override
  State<ViewStudents> createState() => _ViewStudentsState();
}

class _ViewStudentsState extends State<ViewStudents> {
  final _searchCtrl = TextEditingController();
  String _search         = "";
  String _filterCourse   = "All";
  String _filterDivision = "All";

  // ── Selection mode ──
  bool               _selectMode = false;
  Set<String>        _selected   = {};

  static const _staticCourses   = ["All","BCA","MCA","MSIT","BSIT"];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Bulk delete confirm ──
  void _confirmBulkDelete(BuildContext context, List<Map<String, dynamic>> allStudents) {
    final toDelete = allStudents.where((s) => _selected.contains(s["id"])).toList();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red),
          SizedBox(width: 8),
          Text("Delete Students"),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${toDelete.length} students will be permanently deleted:",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: toDelete.map((s) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(child: Text(
                        "${s["name"]}  (${s["rollNumber"]})",
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      )),
                    ]),
                  )).toList(),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _bulkDelete();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text("Delete ${toDelete.length}",
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _bulkDelete() async {
    final batch = FirebaseFirestore.instance.batch();
    for (final id in _selected) {
      batch.delete(FirebaseFirestore.instance.collection("students").doc(id));
    }
    await batch.commit();
    setState(() {
      _selected.clear();
      _selectMode = false;
    });
  }

  // ── Select all filtered ──
  void _selectAll(List<Map<String, dynamic>> filtered) {
    setState(() {
      if (_selected.length == filtered.length) {
        _selected.clear();
      } else {
        _selected = filtered.map((s) => s["id"] as String).toSet();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        iconTheme: const IconThemeData(color: Colors.white),
        title: _selectMode
            ? Text("${_selected.length} selected",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
            : const Text("All Students",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          if (!_selectMode)
          // Enter select mode
            IconButton(
              icon: const Icon(Icons.checklist_rounded, color: Colors.white),
              tooltip: "Select to delete",
              onPressed: () => setState(() {
                _selectMode = true;
                _selected.clear();
              }),
            ),
          if (_selectMode) ...[
            // Cancel
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => setState(() {
                _selectMode = false;
                _selected.clear();
              }),
            ),
          ],
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection("students").snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = snapshot.data!.docs.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            return {
              "id":         doc.id,
              "doc":        doc,
              "name":       (d["name"]       as String? ?? "-").toUpperCase(),
              "rollNumber": d["rollNumber"]  as String? ?? "-",
              "course":     d["course"]      as String? ?? "-",
              "division":   d["division"]    as String? ?? "-",
              "username":   d["username"]    as String? ?? "-",
              "email":      d["email"]       as String? ?? "",
              "contact":    d["contact"]     as String? ?? "",
            };
          }).toList();

          all.sort((a, b) =>
              (a["rollNumber"] as String).compareTo(b["rollNumber"] as String));

          final divisions = <String>{
            "All",
            ...all.map((s) => s["division"] as String).where((d) => d != "-")
          };
          final courses = <String>{
            ..._staticCourses,
            ...all.map((s) => s["course"] as String).where((c) => c != "-"),
          };

          final filtered = all.where((s) {
            final q = _search.toLowerCase();
            final matchSearch = q.isEmpty ||
                (s["name"] as String).toLowerCase().contains(q) ||
                (s["rollNumber"] as String).toLowerCase().contains(q) ||
                (s["username"] as String).toLowerCase().contains(q);
            final matchCourse   = _filterCourse   == "All" || s["course"]   == _filterCourse;
            final matchDivision = _filterDivision == "All" || s["division"] == _filterDivision;
            return matchSearch && matchCourse && matchDivision;
          }).toList();

          final allSelected = _selected.length == filtered.length && filtered.isNotEmpty;

          return Column(
            children: [

              // ── Search bar ──
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: "Search by name, roll no, username...",
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF1E3A5F)),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                        onPressed: () { _searchCtrl.clear(); setState(() => _search = ""); })
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),

              // ── Course + Division filters ──
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: courses.map((c) {
                            final sel = c == _filterCourse;
                            return GestureDetector(
                              onTap: () => setState(() => _filterCourse = c),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: sel ? const Color(0xFF1E3A5F) : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(c,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: sel ? Colors.white : Colors.grey.shade700)),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _filterDivision,
                          isDense: true,
                          style: const TextStyle(
                              color: Color(0xFF1E3A5F), fontSize: 12, fontWeight: FontWeight.w600),
                          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF1E3A5F), size: 18),
                          items: divisions.map((d) =>
                              DropdownMenuItem(value: d, child: Text("Div: $d"))).toList(),
                          onChanged: (v) => setState(() => _filterDivision = v!),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Select mode toolbar ──
              if (_selectMode)
                Container(
                  color: const Color(0xFF1E3A5F).withValues(alpha: 0.05),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      // Select all checkbox
                      GestureDetector(
                        onTap: () => _selectAll(filtered),
                        child: Row(children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 22, height: 22,
                            decoration: BoxDecoration(
                              color: allSelected ? const Color(0xFF1E3A5F) : Colors.white,
                              border: Border.all(color: const Color(0xFF1E3A5F), width: 2),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: allSelected
                                ? const Icon(Icons.check, color: Colors.white, size: 14)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            allSelected ? "Deselect All" : "Select All (${filtered.length})",
                            style: const TextStyle(
                                color: Color(0xFF1E3A5F),
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                          ),
                        ]),
                      ),
                      const Spacer(),
                      if (_selected.isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: () => _confirmBulkDelete(context, all),
                          icon: const Icon(Icons.delete_rounded, size: 16, color: Colors.white),
                          label: Text("Delete ${_selected.length}",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                        ),
                    ],
                  ),
                ),

              // ── Count bar ──
              Container(
                color: const Color(0xFFF5F0E6),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text("${filtered.length} students",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A5F),
                            fontSize: 13)),
                    const Spacer(),
                    if (_search.isNotEmpty || _filterCourse != "All" || _filterDivision != "All")
                      GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() { _search = ""; _filterCourse = "All"; _filterDivision = "All"; });
                        },
                        child: const Row(children: [
                          Icon(Icons.close, size: 14, color: Colors.red),
                          SizedBox(width: 3),
                          Text("Clear filters",
                              style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500)),
                        ]),
                      ),
                  ],
                ),
              ),

              // ── Student list ──
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.search_off, size: 60, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text("No students found",
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
                    ]))
                    : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final s      = filtered[index];
                    final doc    = s["doc"] as QueryDocumentSnapshot;
                    final id     = s["id"]  as String;
                    final isSel  = _selected.contains(id);

                    return GestureDetector(
                      onLongPress: () {
                        // Long press to enter select mode
                        setState(() {
                          _selectMode = true;
                          _selected.add(id);
                        });
                      },
                      onTap: _selectMode
                          ? () => setState(() {
                        isSel ? _selected.remove(id) : _selected.add(id);
                      })
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSel
                              ? const Color(0xFF1E3A5F).withValues(alpha: 0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: isSel
                              ? Border.all(color: const Color(0xFF1E3A5F), width: 1.5)
                              : null,
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 2))
                          ],
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            children: [
                              // ── Left: checkbox or serial ──
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 46,
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? const Color(0xFF1E3A5F)
                                      : const Color(0xFF1E3A5F).withValues(alpha: 0.07),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(14),
                                    bottomLeft: Radius.circular(14),
                                  ),
                                ),
                                child: Center(
                                  child: _selectMode
                                      ? Icon(
                                    isSel ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                    color: isSel ? Colors.white : const Color(0xFF1E3A5F),
                                    size: 22,
                                  )
                                      : Text("${index + 1}",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E3A5F),
                                          fontSize: 14)),
                                ),
                              ),

                              // ── Content ──
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(s["name"] as String,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Color(0xFF1A1A2E))),
                                      const SizedBox(height: 4),
                                      Row(children: [
                                        const Icon(Icons.badge_outlined, size: 11, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(s["rollNumber"] as String,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF1E3A5F),
                                                fontWeight: FontWeight.w600)),
                                        const SizedBox(width: 12),
                                        const Icon(Icons.school_outlined, size: 11, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text("${s["course"]}  ·  Div ${s["division"]}",
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                      ]),
                                    ],
                                  ),
                                ),
                              ),

                              // ── Actions (only when not in select mode) ──
                              if (!_selectMode)
                                PopupMenuButton(
                                  icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                                  onSelected: (value) {
                                    if (value == "edit") {
                                      Navigator.push(context, MaterialPageRoute(
                                        builder: (_) => EditStudent(studentId: id, data: doc),
                                      ));
                                    }
                                    if (value == "delete") {
                                      showDialog(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: const Text("Delete Student"),
                                          content: Text("Delete ${s["name"]}?"),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                                            TextButton(
                                              onPressed: () {
                                                FirebaseFirestore.instance.collection("students").doc(id).delete();
                                                Navigator.pop(context);
                                              },
                                              child: const Text("Delete", style: TextStyle(color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(value: "edit", child: Row(children: [
                                      Icon(Icons.edit_outlined, size: 16, color: Color(0xFF1E3A5F)),
                                      SizedBox(width: 8), Text("Edit"),
                                    ])),
                                    PopupMenuItem(value: "delete", child: Row(children: [
                                      Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                      SizedBox(width: 8), Text("Delete", style: TextStyle(color: Colors.red)),
                                    ])),
                                  ],
                                ),
                            ],
                          ),
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

      // ── FAB hint when not in select mode ──
      floatingActionButton: !_selectMode
          ? FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1E3A5F),
        icon: const Icon(Icons.checklist_rounded, color: Colors.white),
        label: const Text("Select & Delete",
            style: TextStyle(color: Colors.white, fontSize: 12)),
        onPressed: () => setState(() {
          _selectMode = true;
          _selected.clear();
        }),
      )
          : null,
    );
  }
}

////////////////////////////////////////////////////////////
/// EDIT STUDENT PAGE
////////////////////////////////////////////////////////////

class EditStudent extends StatefulWidget {
  final String studentId;
  final QueryDocumentSnapshot data;

  const EditStudent({super.key, required this.studentId, required this.data});

  @override
  State<EditStudent> createState() => _EditStudentState();
}

class _EditStudentState extends State<EditStudent> {
  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController contactController;
  late TextEditingController usernameController;
  late TextEditingController rollNumberController;

  static const _courses   = ["BCA","MCA","MSIT","BSIT"];
  static const _divisions = ["A","B","C","D"];

  String? _selectedCourse;
  String? _selectedDivision;

  @override
  void initState() {
    super.initState();
    final d = widget.data.data() as Map<String, dynamic>;
    nameController       = TextEditingController(text: d["name"]       as String? ?? "");
    emailController      = TextEditingController(text: d["email"]      as String? ?? "");
    contactController    = TextEditingController(text: d["contact"]    as String? ?? "");
    usernameController   = TextEditingController(text: d["username"]   as String? ?? "");
    rollNumberController = TextEditingController(text: d["rollNumber"] as String? ?? "");
    final course   = d["course"]   as String? ?? "";
    final division = d["division"] as String? ?? "";
    _selectedCourse   = _courses.contains(course)     ? course   : null;
    _selectedDivision = _divisions.contains(division) ? division : null;
  }

  Future<void> updateStudent() async {
    await FirebaseFirestore.instance.collection("students").doc(widget.studentId).update({
      "name":       nameController.text.trim(),
      "email":      emailController.text.trim(),
      "contact":    contactController.text.trim(),
      "course":     _selectedCourse   ?? "",
      "division":   _selectedDivision ?? "",
      "username":   usernameController.text.trim(),
      "rollNumber": rollNumberController.text.trim(),
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E6),
      appBar: AppBar(
        title: const Text("Edit Student", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E3A5F),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          _field(nameController,       "Name"),
          _field(rollNumberController, "Roll Number"),
          _dropdown("Course",   _courses,   _selectedCourse,   (v) => setState(() => _selectedCourse   = v)),
          _dropdown("Division", _divisions, _selectedDivision, (v) => setState(() => _selectedDivision = v)),
          _field(usernameController, "Username"),
          _field(emailController,    "Email (optional)"),
          _field(contactController,  "Contact (optional)"),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: updateStudent,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Update", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 2),
          ),
        ),
      ),
    );
  }

  Widget _dropdown(String label, List<String> items, String? value, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 2),
          ),
        ),
        items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}