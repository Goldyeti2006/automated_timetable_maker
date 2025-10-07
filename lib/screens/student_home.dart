import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/timetable_entry.dart';
import '../services/db_service.dart';
import 'login_screen.dart';
import 'dart:math';

class StudentHome extends StatefulWidget {
  @override
  _StudentHomeState createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  final DBService _db = DBService();
  Future<List<TimetableEntry>>? _timetableFuture;

  final Map<String, Color> _courseColors = {};

  @override
  void initState() {
    super.initState();
    if (FirebaseAuth.instance.currentUser != null) {
      _timetableFuture = _db.getTimetableForStudent(FirebaseAuth.instance.currentUser!.uid);
    }
  }

  Color _getColorForCourse(String courseId) {
    if (!_courseColors.containsKey(courseId)) {
      _courseColors[courseId] = Colors.primaries[Random().nextInt(Colors.primaries.length)].shade200;
    }
    return _courseColors[courseId]!;
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginScreen()),
          (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    final slots = [
      "09:00-09:55", "10:00-10:55", "11:00-11:55", "12:00-12:55",
      "14:00-14:55", "15:00-15:55", "16:00-16:55"
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text("Your Timetable"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: FutureBuilder<List<TimetableEntry>>(
        future: _timetableFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text("Your timetable is empty."));
          }

          final entries = snapshot.data!;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 10,
              border: TableBorder.all(color: Colors.grey.shade300),
              columns: [
                DataColumn(label: Text('Time')),
                ...days.map((day) => DataColumn(label: Center(child: Text(day, style: TextStyle(fontWeight: FontWeight.bold)))))
              ],
              rows: slots.map((slot) {
                return DataRow(cells: [
                  DataCell(Text(slot, style: TextStyle(fontWeight: FontWeight.bold))),
                  ...days.map((day) {
                    final entry = entries.firstWhere(
                          (e) => e.day == day && e.slot == slot,
                      orElse: () => TimetableEntry(
                          courseId: '',
                          baseCourseId: '',
                          courseName: '',
                          teacherId: '',
                          roomId: '',
                          day: '',
                          slot: ''
                      ),
                    );

                    if (entry.courseId.isEmpty) {
                      return DataCell(Container()); // Empty cell
                    }

                    return DataCell(
                      Container(
                        width: 120, // Give the cell a bit more width for the name
                        color: _getColorForCourse(entry.baseCourseId),
                        padding: EdgeInsets.all(8),
                        child: Center(
                          child: Text(
                            '${entry.courseName}\nRoom: ${entry.roomId}',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ]);
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}


