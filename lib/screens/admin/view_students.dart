import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewStudents extends StatefulWidget {
  final String collegeId;
  const ViewStudents({super.key, required this.collegeId});

  @override
  State<ViewStudents> createState() => _ViewStudentsState();
}

class _ViewStudentsState extends State<ViewStudents> {
  final _searchCtrl  = TextEditingController();
  String _search         = "";
  String _filterCourse   = "All";
  String _filterDivision = "All";
  String _filterSemester = "All";
  bool   _selectMode     = false;
  Set<String> _selected  = {};

  String _viewMode       = "Active";

  static const _staticCourses = ["All","BCA","MCA","MSIT","BSIT"];

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  void _confirmBulkDelete(BuildContext ctx, List<Map<String, dynamic>> all) {
    final toDelete = all.where((s) => _selected.contains(s["id"])).toList();
    showDialog(context: ctx, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(children: [
        Icon(Icons.warning_amber_rounded, color: Colors.red),
        SizedBox(width: 8), Text("Delete Students"),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("${toDelete.length} students will be deleted:", style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          child: SingleChildScrollView(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: toDelete.map((s) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(child: Text("${s["name"]}  (${s["rollNumber"]})",
                    style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
              ]),
            )).toList(),
          )),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () async { Navigator.pop(ctx); await _bulkDelete(); },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: Text("Delete ${toDelete.length}", style: const TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  Future<void> _bulkDelete() async {
    final batch = FirebaseFirestore.instance.batch();
    for (final id in _selected) {
      batch.delete(FirebaseFirestore.instance.collection("students").doc(id));
    }
    await batch.commit();
    setState(() { _selected.clear(); _selectMode = false; });
  }

  Future<void> _bulkChangeStatus(String newStatus) async {
    final count = _selected.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(newStatus == "Alumni" ? Icons.school : Icons.restore,
              color: newStatus == "Alumni" ? Colors.green : Colors.orange),
          const SizedBox(width: 8), Text("Mark $newStatus"),
        ]),
        content: Text("Change status of $count selected students to $newStatus?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: newStatus == "Alumni" ? Colors.green : Colors.orange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            ),
            child: const Text("Confirm", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final batch = FirebaseFirestore.instance.batch();
      for (final id in _selected) {
        batch.update(FirebaseFirestore.instance.collection("students").doc(id), {"status": newStatus});
      }
      await batch.commit();
      setState(() { _selected.clear(); _selectMode = false; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ $count students moved to $newStatus"), backgroundColor: Colors.green));
    }
  }

  void _selectAll(List<Map<String, dynamic>> filtered) {
    setState(() {
      if (_selected.length == filtered.length) _selected.clear();
      else _selected = filtered.map((s) => s["id"] as String).toSet();
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
            : const Text("Manage Students",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          if (!_selectMode)
            IconButton(icon: const Icon(Icons.checklist_rounded, color: Colors.white),
                onPressed: () => setState(() { _selectMode = true; _selected.clear(); })),
          if (_selectMode)
            IconButton(icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => setState(() { _selectMode = false; _selected.clear(); })),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection("students")
            .where("collegeId", isEqualTo: widget.collegeId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final all = snapshot.data!.docs.map((doc) {
            final d = doc.data() as Map<String, dynamic>;

            final rawStatus = (d["status"] as String? ?? "Active").trim().toLowerCase();
            final normalizedStatus = rawStatus == "alumni" ? "Alumni" : "Active";

            return {
              "id": doc.id, "doc": doc,
              "name":       (d["name"]       as String? ?? "-").toUpperCase(),
              "rollNumber": d["rollNumber"]  as String? ?? "-",
              "course":     d["course"]      as String? ?? "-",
              "division":   d["division"]    as String? ?? "-",
              "semester":   d["semester"]    as String? ?? "-",
              "username":   d["username"]    as String? ?? "-",
              "status":     normalizedStatus,
            };
          }).where((s) => s["status"] == _viewMode).toList();

          all.sort((a, b) => (a["rollNumber"] as String).compareTo(b["rollNumber"] as String));

          final divisions = <String>{"All", ...all.map((s) => s["division"] as String).where((d) => d != "-")};
          final semesters = <String>{"All", ...all.map((s) => s["semester"] as String).where((sem) => sem != "-").toList()..sort()};
          final courses   = <String>{..._staticCourses, ...all.map((s) => s["course"] as String).where((c) => c != "-")};

          final safeCourse   = courses.contains(_filterCourse) ? _filterCourse : "All";
          final safeSemester = semesters.contains(_filterSemester) ? _filterSemester : "All";
          final safeDivision = divisions.contains(_filterDivision) ? _filterDivision : "All";

          final filtered = all.where((s) {
            final q = _search.toLowerCase();
            final ms = q.isEmpty ||
                (s["name"] as String).toLowerCase().contains(q) ||
                (s["rollNumber"] as String).toLowerCase().contains(q) ||
                (s["username"] as String).toLowerCase().contains(q);

            final mc = safeCourse   == "All" || s["course"]   == safeCourse;
            final md = safeDivision == "All" || s["division"] == safeDivision;
            final mSem = safeSemester == "All" || s["semester"] == safeSemester;

            return ms && mc && md && mSem;
          }).toList();

          final allSel = _selected.length == filtered.length && filtered.isNotEmpty;

          return Column(children: [

            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                Expanded(child: _toggleBtn("Active", Icons.people_alt_rounded)),
                const SizedBox(width: 8),
                Expanded(child: _toggleBtn("Alumni", Icons.school_rounded)),
              ]),
            ),

            Container(color: Colors.white, padding: const EdgeInsets.fromLTRB(12,6,12,0),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: "Search by name, roll no...",
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF1E3A5F)),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                      onPressed: () { _searchCtrl.clear(); setState(() => _search = ""); })
                      : null,
                  filled: true, fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),

            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                  children: [
                    Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(children: courses.map((c) {
                            final sel = c == safeCourse;
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
                                child: Text(c, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                    color: sel ? Colors.white : Colors.grey.shade700)),
                              ),
                            );
                          }).toList()),
                        )
                    ),
                    const SizedBox(width: 8),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                        value: safeSemester,
                        isDense: true,
                        style: const TextStyle(color: Color(0xFF1E3A5F), fontSize: 11, fontWeight: FontWeight.w600),
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF1E3A5F), size: 16),
                        items: semesters.map((s) => DropdownMenuItem(
                            value: s, child: Text(s == "All" ? "Sem: All" : s))).toList(),
                        onChanged: (v) => setState(() => _filterSemester = v!),
                      )),
                    ),
                    const SizedBox(width: 8),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                        value: safeDivision,
                        isDense: true,
                        style: const TextStyle(color: Color(0xFF1E3A5F), fontSize: 11, fontWeight: FontWeight.w600),
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF1E3A5F), size: 16),
                        items: divisions.map((d) => DropdownMenuItem(value: d, child: Text("Div: $d"))).toList(),
                        onChanged: (v) => setState(() => _filterDivision = v!),
                      )),
                    ),
                  ]
              ),
            ),

            if (_selectMode)
              Container(
                color: const Color(0xFF1E3A5F).withValues(alpha: 0.05),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => _selectAll(filtered),
                    child: Row(children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          color: allSel ? const Color(0xFF1E3A5F) : Colors.white,
                          border: Border.all(color: const Color(0xFF1E3A5F), width: 2),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: allSel ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
                      ),
                      const SizedBox(width: 8),
                      Text(allSel ? "Deselect" : "Select All",
                          style: const TextStyle(color: Color(0xFF1E3A5F), fontWeight: FontWeight.w600, fontSize: 13)),
                    ]),
                  ),
                  const Spacer(),
                  if (_selected.isNotEmpty) ...[
                    ElevatedButton.icon(
                      onPressed: () => _bulkChangeStatus(_viewMode == "Active" ? "Alumni" : "Active"),
                      icon: Icon(_viewMode == "Active" ? Icons.school : Icons.restore, size: 14, color: Colors.white),
                      label: Text(_viewMode == "Active" ? "Alumni" : "Restore",
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _viewMode == "Active" ? Colors.green : Colors.orange,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      onPressed: () => _confirmBulkDelete(context, all),
                      icon: const Icon(Icons.delete_rounded, size: 14, color: Colors.white),
                      label: const Text("Delete", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                    ),
                  ]
                ]),
              ),

            Container(color: const Color(0xFFF5F0E6), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                Text("${filtered.length} students", style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Color(0xFF1E3A5F), fontSize: 13)),
                const Spacer(),
                if (_search.isNotEmpty || _filterCourse != "All" || _filterDivision != "All" || _filterSemester != "All")
                  GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() { _search = ""; _filterCourse = "All"; _filterDivision = "All"; _filterSemester = "All"; });
                    },
                    child: const Row(children: [
                      Icon(Icons.close, size: 14, color: Colors.red),
                      SizedBox(width: 3),
                      Text("Clear filters", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500)),
                    ]),
                  ),
              ]),
            ),

            Expanded(
              child: filtered.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.search_off, size: 60, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text("No students found", style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
              ]))
                  : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final s   = filtered[index];
                  final doc = s["doc"] as QueryDocumentSnapshot;
                  final id  = s["id"]  as String;
                  final sel = _selected.contains(id);

                  return GestureDetector(
                    onLongPress: () => setState(() { _selectMode = true; _selected.add(id); }),
                    onTap: _selectMode ? () => setState(() { sel ? _selected.remove(id) : _selected.add(id); }) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: sel ? const Color(0xFF1E3A5F).withValues(alpha: 0.08) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: sel ? Border.all(color: const Color(0xFF1E3A5F), width: 1.5) : null,
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0,2))],
                      ),
                      child: IntrinsicHeight(child: Row(children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 46,
                          decoration: BoxDecoration(
                            color: sel ? const Color(0xFF1E3A5F) : const Color(0xFF1E3A5F).withValues(alpha: 0.07),
                            borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(14), bottomLeft: Radius.circular(14)),
                          ),
                          child: Center(child: _selectMode
                              ? Icon(sel ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                              color: sel ? Colors.white : const Color(0xFF1E3A5F), size: 22)
                              : Text("${index+1}", style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Color(0xFF1E3A5F), fontSize: 14))),
                        ),
                        // ✅ RESPONSIVE FIX IS HERE (Expanded & TextOverflow.ellipsis)
                        Expanded(child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s["name"] as String,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1A2E))),
                            const SizedBox(height: 4),
                            Row(children: [
                              const Icon(Icons.badge_outlined, size: 11, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(s["rollNumber"] as String, style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF1E3A5F), fontWeight: FontWeight.w600)),
                              const SizedBox(width: 8),
                              const Icon(Icons.school_outlined, size: 11, color: Colors.grey),
                              const SizedBox(width: 4),
                              Expanded( // Yahan aab screen size adjust ho jayega
                                child: Text("${s["course"]} · ${s["semester"]} · Div ${s["division"]}",
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                              ),
                            ]),
                          ]),
                        )),
                        if (!_selectMode)
                          PopupMenuButton(
                            icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                            onSelected: (value) async {
                              if (value == "edit") {
                                Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => EditStudent(studentId: id, data: doc)));
                              }
                              else if (value == "alumni") {
                                await FirebaseFirestore.instance.collection("students").doc(id).update({"status": "Alumni"});
                                if(context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${s["name"]} marked as Alumni"), backgroundColor: Colors.green));
                                }
                              }
                              else if (value == "active") {
                                await FirebaseFirestore.instance.collection("students").doc(id).update({"status": "Active"});
                                if(context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${s["name"]} restored to Active"), backgroundColor: Colors.orange));
                                }
                              }
                              else if (value == "delete") {
                                showDialog(context: context, builder: (_) => AlertDialog(
                                  title: const Text("Delete Student"),
                                  content: Text("Delete ${s["name"]}?"),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                                    TextButton(
                                      onPressed: () { FirebaseFirestore.instance.collection("students").doc(id).delete(); Navigator.pop(context); },
                                      child: const Text("Delete", style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ));
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: "edit",   child: Row(children: [Icon(Icons.edit_outlined, size: 16, color: Color(0xFF1E3A5F)), SizedBox(width: 8), Text("Edit")])),
                              if (_viewMode == "Active")
                                const PopupMenuItem(value: "alumni", child: Row(children: [Icon(Icons.school, size: 16, color: Colors.green), SizedBox(width: 8), Text("Mark Alumni")])),
                              if (_viewMode == "Alumni")
                                const PopupMenuItem(value: "active", child: Row(children: [Icon(Icons.restore, size: 16, color: Colors.orange), SizedBox(width: 8), Text("Restore")])),
                              const PopupMenuItem(value: "delete", child: Row(children: [Icon(Icons.delete_outline, size: 16, color: Colors.red), SizedBox(width: 8), Text("Delete", style: TextStyle(color: Colors.red))])),
                            ],
                          ),
                      ])),
                    ),
                  );
                },
              ),
            ),
          ]);
        },
      ),
      floatingActionButton: !_selectMode
          ? FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1E3A5F),
        icon: const Icon(Icons.checklist_rounded, color: Colors.white),
        label: const Text("Select & Manage", style: TextStyle(color: Colors.white, fontSize: 12)),
        onPressed: () => setState(() { _selectMode = true; _selected.clear(); }),
      )
          : null,
    );
  }

  Widget _toggleBtn(String label, IconData icon) {
    final bool isSelected = _viewMode == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _viewMode = label;
          _selected.clear();
          _selectMode = false;
          _filterCourse = "All";
          _filterDivision = "All";
          _filterSemester = "All";
          _searchCtrl.clear();
          _search = "";
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1E3A5F) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? const Color(0xFF1E3A5F) : Colors.grey.shade300)
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey.shade700),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13,
                color: isSelected ? Colors.white : Colors.grey.shade700
            ))
          ],
        ),
      ),
    );
  }
}

class EditStudent extends StatefulWidget {
  final String studentId;
  final QueryDocumentSnapshot data;
  const EditStudent({super.key, required this.studentId, required this.data});

  @override
  State<EditStudent> createState() => _EditStudentState();
}

class _EditStudentState extends State<EditStudent> {
  late TextEditingController nameCtrl, emailCtrl, contactCtrl, usernameCtrl, rollCtrl;
  static const _courses   = ["BCA","MCA","MSIT","BSIT"];
  static const _divisions = ["A","B","C","D"];
  static const _semesters = ["Sem 1", "Sem 2", "Sem 3", "Sem 4", "Sem 5", "Sem 6", "Sem 7", "Sem 8"];

  String? _course, _division, _semester;

  @override
  void initState() {
    super.initState();
    final d = widget.data.data() as Map<String, dynamic>;
    nameCtrl     = TextEditingController(text: d["name"]       as String? ?? "");
    emailCtrl    = TextEditingController(text: d["email"]      as String? ?? "");
    contactCtrl  = TextEditingController(text: d["contact"]    as String? ?? "");
    usernameCtrl = TextEditingController(text: d["username"]   as String? ?? "");
    rollCtrl     = TextEditingController(text: d["rollNumber"] as String? ?? "");

    final c = d["course"]   as String? ?? "";
    final dv = d["division"] as String? ?? "";
    final sm = d["semester"] as String? ?? "";

    _course   = _courses.contains(c)    ? c  : null;
    _division = _divisions.contains(dv) ? dv : null;
    _semester = _semesters.contains(sm) ? sm : null;
  }

  Future<void> update() async {
    await FirebaseFirestore.instance.collection("students").doc(widget.studentId).update({
      "name":       nameCtrl.text.trim(),
      "email":      emailCtrl.text.trim(),
      "contact":    contactCtrl.text.trim(),
      "course":     _course   ?? "",
      "division":   _division ?? "",
      "semester":   _semester ?? "",
      "username":   usernameCtrl.text.trim(),
      "rollNumber": rollCtrl.text.trim(),
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E6),
      appBar: AppBar(title: const Text("Edit Student", style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF1E3A5F), iconTheme: const IconThemeData(color: Colors.white)),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
        _f(nameCtrl,     "Name"),
        _f(rollCtrl,     "Roll Number"),
        _dd("Course",   _courses,   _course,   (v) => setState(() => _course   = v)),
        _dd("Semester", _semesters, _semester, (v) => setState(() => _semester = v)),
        _dd("Division", _divisions, _division, (v) => setState(() => _division = v)),
        _f(usernameCtrl, "Username"),
        _f(emailCtrl,    "Email (optional)"),
        _f(contactCtrl,  "Contact (optional)"),
        const SizedBox(height: 30),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: update,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A5F),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text("Update", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        )),
      ])),
    );
  }

  Widget _f(TextEditingController c, String l) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(controller: c, decoration: InputDecoration(
      labelText: l,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 2)),
    )),
  );

  Widget _dd(String l, List<String> items, String? val, ValueChanged<String?> fn) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: DropdownButtonFormField<String>(
      value: val,
      decoration: InputDecoration(labelText: l,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 2))),
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
      onChanged: fn,
    ),
  );
}