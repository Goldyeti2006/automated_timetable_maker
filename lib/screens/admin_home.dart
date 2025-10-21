import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/classroom.dart';
import '../models/course.dart';
import '../models/timetable_entry.dart';
import '../services/db_service.dart';
import 'login_screen.dart';
import 'dart:math';

// NEW: The missing TimeSlot helper class
class TimeSlot {
  final int id;
  final String label;
  TimeSlot({required this.id, required this.label});
}

// Helper class for a specific class instance to be scheduled
class SchedulableEvent {
  final Course course;
  final String eventType;
  final int duration;
  final int instance;
  bool isScheduled = false; // To track if this specific event has been placed

  SchedulableEvent({
    required this.course,
    required this.eventType,
    this.duration = 1,
    required this.instance,
  });
}

class AdminHome extends StatefulWidget {
  @override
  _AdminHomeState createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  final DBService _db = DBService();
  bool _isLoading = false;

  final _roomIdController = TextEditingController();
  final _capacityController = TextEditingController();
  String _roomType = "Lecture";

  // Boilerplate functions are unchanged
  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginScreen()),
          (Route<dynamic> route) => false,
    );
  }

  void _addClassroom() async {
    if (_roomIdController.text.isEmpty || _capacityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please fill all fields')));
      return;
    }
    final classroom = Classroom(
      roomId: _roomIdController.text.trim(),
      capacity: int.parse(_capacityController.text),
      type: _roomType,
    );
    await _db.addClassroom(classroom);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Classroom Added Successfully')));
    _roomIdController.clear();
    _capacityController.clear();
  }

  // =======================================================================
  // ================= THE NEW TIMETABLE ALGORITHM V16 =====================
  // =======================================================================
  Future<void> _generateTimetable() async {
    setState(() => _isLoading = true);

    final courses = await _db.getCourses();
    final rooms = await _db.getClassrooms();

    if (courses.isEmpty || rooms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannot generate: No courses or rooms found.')));
      setState(() => _isLoading = false);
      return;
    }
    await _db.clearTimetable();

    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    final timeSlots = [
      TimeSlot(id: 0, label: "09:00-09:55"), TimeSlot(id: 1, label: "10:00-10:55"),
      TimeSlot(id: 2, label: "11:00-11:55"), TimeSlot(id: 3, label: "12:00-12:55"),
      TimeSlot(id: 4, label: "13:00-13:55"), TimeSlot(id: 5, label: "14:00-14:55"),
      TimeSlot(id: 6, label: "15:00-15:55"), TimeSlot(id: 7, label: "16:00-16:55"),
    ];

    // 1. Prepare all events that need to be scheduled
    List<SchedulableEvent> eventsToSchedule = [];
    for (var course in courses) {
      int lectureHours = course.hoursPerWeek;
      if (course.hasLab) {
        eventsToSchedule.add(SchedulableEvent(course: course, eventType: "Lab", duration: 2, instance: 0));
        lectureHours -= 2;
      }
      if (course.hasTutorial) {
        eventsToSchedule.add(SchedulableEvent(course: course, eventType: "Tutorial", instance: 0));
        lectureHours--;
      }
      for (int i = 0; i < lectureHours; i++) {
        eventsToSchedule.add(SchedulableEvent(course: course, eventType: "Lecture", instance: i));
      }
    }

    // This is the single, permanent "notebook" for the schedule's state
    // It makes double-booking logically impossible.
    Set<String> busySlots = {}; // Format: "ResourceType-ResourceID-Day-SlotID"

    // 2. The Main "Grid-First" Loop
    for (var day in days) {
      for (var startSlot in timeSlots) {

        // Is this specific slot already occupied? If so, skip it.
        if (busySlots.any((key) => key.endsWith("-$day-${startSlot.id}"))) continue;

        // Shuffle events to ensure fairness and distribution
        final unscheduledEvents = eventsToSchedule.where((e) => !e.isScheduled).toList()..shuffle();

        for (var event in unscheduledEvents) {
          final startIndex = timeSlots.indexOf(startSlot);
          if (startIndex + event.duration > timeSlots.length) continue;

          final blockSlots = timeSlots.sublist(startIndex, startIndex + event.duration);

          // --- CHECK CONSTRAINTS ---
          bool canSchedule = true;
          Classroom? availableRoom;

          // Soft Constraints
          if (event.eventType == "Lab" && busySlots.any((k) => k.startsWith("LabDay-$day"))) continue;
          if (event.eventType == "Lecture" && busySlots.any((k) => k.startsWith("LectureDay-${event.course.courseId}-$day"))) continue;

          // Hard Constraints: Check Teacher and Room availability for the entire block
          for (var slot in blockSlots) {
            final teacherKey = "Teacher-${event.course.teacherId}-$day-${slot.id}";
            if (busySlots.contains(teacherKey)) {
              canSchedule = false;
              break;
            }
          }
          if (!canSchedule) continue;

          // Find a free room
          for (var room in rooms..shuffle()) {
            bool typeMatch = (event.eventType == "Lab" && room.type == "Lab") || (event.eventType != "Lab" && room.type == "Lecture");
            if (!typeMatch) continue;

            bool roomIsFree = true;
            for (var slot in blockSlots) {
              final roomKey = "Room-${room.roomId}-$day-${slot.id}";
              if (busySlots.contains(roomKey)) {
                roomIsFree = false;
                break;
              }
            }
            if (roomIsFree) {
              availableRoom = room;
              break;
            }
          }

          // If all checks pass, place the event and LOCK the slots
          if (canSchedule && availableRoom != null) {
            for (var slot in blockSlots) {
              busySlots.add("Teacher-${event.course.teacherId}-$day-${slot.id}");
              busySlots.add("Room-${availableRoom.roomId}-$day-${slot.id}");

              final entry = TimetableEntry(
                courseId: "${event.course.courseId} (${event.eventType})", baseCourseId: event.course.courseId, courseName: "${event.course.courseName} (${event.eventType})",
                teacherId: event.course.teacherId, roomId: availableRoom.roomId, day: day, slot: slot.label,
              );
              await _db.addTimetableEntry(entry);
            }

            if (event.eventType == "Lab") busySlots.add("LabDay-$day");
            if (event.eventType == "Lecture") busySlots.add("LectureDay-${event.course.courseId}-$day");

            event.isScheduled = true;
            break; // A class was scheduled in this slot, move to the next slot in the grid
          }
        }
      }
    }

    final totalRequired = eventsToSchedule.length;
    final totalScheduled = eventsToSchedule.where((e) => e.isScheduled).length;

    setState(() => _isLoading = false);
    if (totalScheduled >= totalRequired) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Timetable Generated Successfully! All ${eventsToSchedule.map((e) => e.duration).reduce((a,b)=>a+b)} hours scheduled.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Timetable Generated, but only ${totalScheduled}/${totalRequired} classes could be scheduled. Please add more rooms/slots.'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF12212D),
      appBar: AppBar(
        backgroundColor: Color(0xFF577389),
        title: Center(
          child: Text("Admin Dashboard",style: TextStyle(
            color: Color(0xFFFFFFFF))),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout,color: Color(0xFFFFFFFF),),
            tooltip: 'Log Out',
            onPressed: _signOut,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _roomIdController, decoration: InputDecoration(labelStyle: TextStyle(color: Color(0xFFCCD0CF)),labelText: "Room ID (e.g., C-101)")),
            TextField(controller: _capacityController, decoration: InputDecoration(labelStyle: TextStyle(color: Color(0xFFCCD0CF)),labelText: "Capacity"), keyboardType: TextInputType.number),
            DropdownButtonFormField<String>(
              value: _roomType,
              isExpanded: true,
              items: ["Lecture", "Lab", "Tutorial"].map((type) => DropdownMenuItem(value: type, child: Text(type,style: TextStyle(color: Color(0xFF12212D),),))).toList(),
              onChanged: (val) => setState(() => _roomType = val!),
              dropdownColor: Color(0xFFCCD0CF),
              borderRadius: BorderRadius.circular(12.0),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: const BorderSide(color: Color(0xFF305979), width: 4.0),
                ),
                filled: true,
                fillColor: Color(0xFFCCD0CF),
              ),
            ),
            SizedBox(height: 12),
            ElevatedButton(onPressed: _addClassroom, child: Text("Add Classroom",style: TextStyle(color: Color(0xFF12212D),)),style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFCCD0CF)),),
            Divider(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _generateTimetable,
              child: _isLoading
                  ? CircularProgressIndicator(color: Color(0xFFCCD0CF))
                  : Text("Generate Timetable",style: TextStyle(color: Color(0xFF12212D),)),
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFCCD0CF)),
            ),
            Divider(height: 20),
            Expanded(
              child: _buildRawTimetableStream(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRawTimetableStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.getTimetableStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text("Press 'Generate Timetable' to see raw data.",style: TextStyle(
              color: Color(0xFFFFFFFF))));
        }

        final docs = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text("Live Timetable Output (${docs.length} classes scheduled)", style: TextStyle(
                  color: Color(0xFFFFFFFF))),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final courseName = data['courseName'] ?? 'N/A';
                  final day = data['day'] ?? 'N/A';
                  final slot = data['slot'] ?? 'N/A';
                  final room = data['roomId'] ?? 'N/A';

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: ListTile(
                      dense: true,
                      title: Text('$courseName'),
                      subtitle: Text('$day at $slot in Room: $room'),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}