import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NoticeBoard extends StatefulWidget {
  final String teacherId;
  final String teacherName;
  final String collegeId; // ✅

  const NoticeBoard({
    super.key,
    required this.teacherId,
    required this.teacherName,
    required this.collegeId,
  });

  @override
  State<NoticeBoard> createState() => _NoticeBoardState();
}

class _NoticeBoardState extends State<NoticeBoard> {
  static const List<Map<String, dynamic>> _categories = [
    {"label": "General",    "color": 0xFF1E3A5F, "icon": Icons.info_outline},
    {"label": "Exam",       "color": 0xFFBF360C, "icon": Icons.edit_note},
    {"label": "Holiday",    "color": 0xFF2E7D32, "icon": Icons.celebration},
    {"label": "Assignment", "color": 0xFF6A1B9A, "icon": Icons.assignment},
    {"label": "Urgent",     "color": 0xFFB71C1C, "icon": Icons.warning_amber},
  ];

  String _filterCategory = "All";

  String _formatDate(dynamic value) {
    if (value == null) return "";
    if (value is Timestamp) {
      final dt = value.toDate();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1)  return "Just now";
      if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
      if (diff.inHours   < 24) return "${diff.inHours}h ago";
      if (diff.inDays    < 7)  return "${diff.inDays}d ago";
      return "${dt.day.toString().padLeft(2,'0')}-${dt.month.toString().padLeft(2,'0')}-${dt.year}";
    }
    return value.toString();
  }

  void _showPostDialog() {
    final titleCtrl = TextEditingController(), messageCtrl = TextEditingController();
    String selectedCategory = "General", selectedTarget = "All Students";
    bool isPosting = false;
    final targets = ["All Students","MCA","BCA","MCA - A","MCA - B","MCA - C","BCA - A","BCA - B","BCA - C"];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          height: MediaQuery.of(ctx).size.height * 0.88,
          decoration: const BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                const Icon(Icons.campaign_rounded, color: Color(0xFF1E3A5F), size: 26),
                const SizedBox(width: 10),
                Text("Post Notice", style: GoogleFonts.playfairDisplay(
                    fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1E3A5F))),
              ]),
            ),
            const Divider(height: 24),
            Expanded(child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("Category", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                SingleChildScrollView(scrollDirection: Axis.horizontal,
                  child: Row(children: _categories.map((cat) {
                    final bool sel = selectedCategory == cat["label"];
                    return GestureDetector(
                      onTap: () => setModal(() => selectedCategory = cat["label"] as String),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                            color: sel ? Color(cat["color"] as int) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20)),
                        child: Row(children: [
                          Icon(cat["icon"] as IconData, size: 14,
                              color: sel ? Colors.white : Colors.grey.shade600),
                          const SizedBox(width: 5),
                          Text(cat["label"] as String, style: TextStyle(fontSize: 12,
                              color: sel ? Colors.white : Colors.grey.shade700, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    );
                  }).toList()),
                ),
                const SizedBox(height: 18),
                const Text("Send To", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200)),
                  child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                    value: selectedTarget, isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF1E3A5F)),
                    items: targets.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setModal(() => selectedTarget = v!),
                  )),
                ),
                const SizedBox(height: 18),
                const Text("Title", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(controller: titleCtrl, maxLength: 80,
                    decoration: InputDecoration(hintText: "Notice title...", filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade200)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade200)),
                        counterText: "")),
                const SizedBox(height: 14),
                const Text("Message", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(controller: messageCtrl, maxLines: 5,
                    decoration: InputDecoration(hintText: "Write your announcement here...", filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade200)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade200)))),
                const SizedBox(height: 24),
                SizedBox(width: double.infinity, height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A5F),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: isPosting ? null : () async {
                      if (titleCtrl.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a title"))); return; }
                      if (messageCtrl.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a message"))); return; }
                      setModal(() => isPosting = true);
                      try {
                        await FirebaseFirestore.instance.collection("notices").add({
                          "title":       titleCtrl.text.trim(),
                          "message":     messageCtrl.text.trim(),
                          "category":    selectedCategory,
                          "target":      selectedTarget,
                          "teacherId":   widget.teacherId,
                          "teacherName": widget.teacherName,
                          "collegeId":   widget.collegeId, // ✅
                          "postedAt":    Timestamp.now(),
                        });
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Notice posted!"), backgroundColor: Colors.green));
                        }
                      } catch (e) { setModal(() => isPosting = false); }
                    },
                    icon: isPosting
                        ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send_rounded, color: Colors.white),
                    label: Text(isPosting ? "Posting..." : "Post Notice",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ]),
            )),
          ]),
        ),
      ),
    );
  }

  Future<void> _deleteNotice(String docId) async {
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text("Delete Notice"),
      content: const Text("Are you sure you want to delete this notice?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
        TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red))),
      ],
    ));
    if (confirm == true) {
      await FirebaseFirestore.instance.collection("notices").doc(docId).delete();
    }
  }

  Map<String, dynamic>? _catFor(String label) {
    try { return _categories.firstWhere((c) => c["label"] == label); }
    catch (_) { return _categories[0]; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text("Notice Board", style: GoogleFonts.playfairDisplay(color: Colors.white, fontSize: 20)),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1E3A5F),
        onPressed: _showPostDialog,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Post Notice", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(children: [
        Container(color: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10),
            child: SingleChildScrollView(scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(children: [
                  _filterTab("All", null, 0xFF1E3A5F),
                  ..._categories.map((cat) => _filterTab(cat["label"] as String,
                      cat["icon"] as IconData, cat["color"] as int)),
                ]))),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            // ✅ Filter notices by collegeId
            stream: FirebaseFirestore.instance
                .collection("notices")
                .where("teacherId", isEqualTo: widget.teacherId)
                .where("collegeId", isEqualTo: widget.collegeId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.campaign_outlined, size: 64,
                      color: const Color(0xFF1E3A5F).withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text("No notices yet", style: GoogleFonts.montserrat(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text("Tap + to post your first notice",
                      style: GoogleFonts.montserrat(fontSize: 13, color: Colors.grey.shade400)),
                ]));

              final allDocs = snapshot.data!.docs.toList()
                ..sort((a, b) {
                  final at = (a.data() as Map)["postedAt"];
                  final bt = (b.data() as Map)["postedAt"];
                  if (at is Timestamp && bt is Timestamp) return bt.compareTo(at);
                  return 0;
                });

              final docs = allDocs.where((doc) {
                if (_filterCategory == "All") return true;
                return (doc.data() as Map<String, dynamic>)["category"] == _filterCategory;
              }).toList();

              if (docs.isEmpty) return Center(child: Text("No $_filterCategory notices",
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 14)));

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final d   = doc.data() as Map<String, dynamic>;
                  final cat = _catFor(d["category"] as String? ?? "General");
                  final color = Color(cat!["color"] as int);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 3))]),
                    child: IntrinsicHeight(child: Row(children: [
                      Container(width: 5, decoration: BoxDecoration(color: color,
                          borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)))),
                      Expanded(child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(cat["icon"] as IconData, size: 11, color: color),
                                const SizedBox(width: 4),
                                Text(d["category"] as String? ?? "General",
                                    style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
                              ]),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.group_outlined, size: 11, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(d["target"] as String? ?? "All",
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                              ]),
                            ),
                            const Spacer(),
                            Text(_formatDate(d["postedAt"]),
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                          ]),
                          const SizedBox(height: 8),
                          Text(d["title"] as String? ?? "",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A1A2E))),
                          const SizedBox(height: 5),
                          Text(d["message"] as String? ?? "",
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4)),
                          const SizedBox(height: 10),
                          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                            GestureDetector(
                              onTap: () => _deleteNotice(doc.id),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8)),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.delete_outline, size: 13, color: Colors.red.shade400),
                                  const SizedBox(width: 4),
                                  Text("Delete", style: TextStyle(fontSize: 11, color: Colors.red.shade400, fontWeight: FontWeight.w600)),
                                ]),
                              ),
                            ),
                          ]),
                        ]),
                      )),
                    ])),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _filterTab(String label, IconData? icon, int colorHex) {
    final bool isSelected = _filterCategory == label;
    final color = Color(colorHex);
    return GestureDetector(
      onTap: () => setState(() => _filterCategory = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
            color: isSelected ? color : Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: isSelected ? Colors.white : Colors.grey.shade600),
            const SizedBox(width: 5),
          ],
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey.shade700)),
        ]),
      ),
    );
  }
}