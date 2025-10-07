import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/classroom.dart';
import '../models/course.dart';
import '../models/timetable_entry.dart';
import '../services/db_service.dart';
import 'login_screen.dart';
import 'dart:math';

// HELPER CLASS 1: TimeSlot
class TimeSlot {
  final int id;
  final String label;
  TimeSlot({required this.id, required this.label});
}

// HELPER CLASS 2: SchedulableEvent
class SchedulableEvent {
  final Course course;
  final String eventType;
  final int duration;
  final int instance;

  SchedulableEvent({
    required this.course,
    required this.eventType,
    this.duration = 1,
    required this.instance,
  });

  // Unique key for reliably tracking this specific event
  String get uniqueKey => '${course.courseId}-${eventType}-${instance}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is SchedulableEvent &&
              runtimeType == other.runtimeType &&
              uniqueKey == other.uniqueKey;

  @override
  int get hashCode => uniqueKey.hashCode;
}

class AdminHome extends StatefulWidget {
  @override
  _AdminHomeState createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  final DBService _db = DBService();
  List<Classroom> classrooms = [];
  bool _isLoading = false;

  final _roomIdController = TextEditingController();
  final _capacityController = TextEditingController();
  String _roomType = "Lecture";

  @override
  void initState() {
    super.initState();
    _loadClassrooms();
  }

  // Boilerplate functions are unchanged
  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginScreen()),
          (Route<dynamic> route) => false,
    );
  }

  Future<void> _loadClassrooms() async {
    final data = await _db.getClassrooms();
    if (mounted) {
      setState(() {
        classrooms = data;
      });
    }
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
    _loadClassrooms();
  }

  // =======================================================================
  // ================= THE NEW TIMETABLE ALGORITHM V8 ======================
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

    // Data structures for tracking
    Map<String, String> teacherSchedule = {};
    Map<String, String> roomSchedule = {};
    Map<String, bool> isLabDay = {};
    Map<String, bool> lectureScheduledToday = {};
    Set<String> successfullyScheduledKeys = {}; // NEW: Reliable tracking using unique keys

    // ================== PASS 1: The "Ideal" Randomized Pass ==================
    // Prioritize labs first, then shuffle the rest
    final labs = eventsToSchedule.where((e) => e.eventType == "Lab").toList();
    final others = eventsToSchedule.where((e) => e.eventType != "Lab").toList()..shuffle();
    final pass1Events = [...labs, ...others];

    for (var event in pass1Events) {
      final shuffledDays = [...days]..shuffle();
      await _tryScheduleEvent(event, shuffledDays, timeSlots, rooms, teacherSchedule, roomSchedule, isLabDay, lectureScheduledToday, successfullyScheduledKeys, relaxConstraints: false);
    }

    // ================== PASS 2: The "Guarantee" Deterministic Pass ==================
    final unscheduledEvents = eventsToSchedule.where((e) => !successfullyScheduledKeys.contains(e.uniqueKey)).toList();

    if (unscheduledEvents.isNotEmpty) {
      for (var event in unscheduledEvents) {
        // Use the original, non-shuffled list of days and relax the "no consecutive teacher" rule
        await _tryScheduleEvent(event, days, timeSlots, rooms, teacherSchedule, roomSchedule, isLabDay, lectureScheduledToday, successfullyScheduledKeys, relaxConstraints: true);
      }
    }

    final finalUnscheduled = eventsToSchedule.where((e) => !successfullyScheduledKeys.contains(e.uniqueKey)).toList();

    setState(() => _isLoading = false);
    if(finalUnscheduled.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Timetable Generated Successfully! All classes scheduled.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Timetable Generated, but ${finalUnscheduled.length} classes could not be scheduled. Please check constraints or add more rooms/slots.'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<bool> _tryScheduleEvent(
      SchedulableEvent event,
      List<String> daysToTry,
      List<TimeSlot> timeSlots,
      List<Classroom> rooms,
      Map<String, String> teacherSchedule,
      Map<String, String> roomSchedule,
      Map<String, bool> isLabDay,
      Map<String, bool> lectureScheduledToday,
      Set<String> successfullyScheduledKeys,
      {required bool relaxConstraints}) async {

    for (var day in daysToTry) {
      if (event.eventType == "Lab" && isLabDay.containsKey(day)) continue;
      if (event.eventType == "Lecture" && lectureScheduledToday.containsKey("${event.course.courseId}-$day")) continue;

      for (int i = 0; i <= timeSlots.length - event.duration; i++) {
        final blockSlots = timeSlots.sublist(i, i + event.duration);
        bool blockIsFree = true;
        Classroom? availableRoom;

        for (var slot in blockSlots) {
          final teacherKey = "${event.course.teacherId}-$day-${slot.id}";
          if (teacherSchedule.containsKey(teacherKey)) {
            blockIsFree = false;
            break;
          }
          // Only check previous teacher slot if we are NOT relaxing constraints
          if (!relaxConstraints) {
            final prevTeacherKey = "${event.course.teacherId}-$day-${slot.id - 1}";
            if (teacherSchedule.containsKey(prevTeacherKey)) {
              blockIsFree = false;
              break;
            }
          }
        }
        if (!blockIsFree) continue;

        for (var room in rooms) {
          bool roomIsFreeForBlock = true;
          for (var slot in blockSlots) {
            final roomKey = "${room.roomId}-$day-${slot.id}";
            if (roomSchedule.containsKey(roomKey)) {
              roomIsFreeForBlock = false;
              break;
            }
          }
          if (roomIsFreeForBlock) {
            bool typeMatch = (event.eventType == "Lab" && room.type == "Lab") || (event.eventType != "Lab" && room.type == "Lecture");
            if (typeMatch) {
              availableRoom = room;
              break;
            }
          }
        }

        if (blockIsFree && availableRoom != null) {
          for (var slot in blockSlots) {
            final teacherKey = "${event.course.teacherId}-$day-${slot.id}";
            final roomKey = "${availableRoom.roomId}-$day-${slot.id}";
            teacherSchedule[teacherKey] = event.course.courseId;
            roomSchedule[roomKey] = event.course.courseId;

            final entry = TimetableEntry(
              courseId: "${event.course.courseId} (${event.eventType} ${event.instance > 0 ? event.instance + 1 : ''})".trim(),
              baseCourseId: event.course.courseId,
              courseName: "${event.course.courseName} (${event.eventType})",
              teacherId: event.course.teacherId,
              roomId: availableRoom.roomId,
              day: day,
              slot: slot.label,
            );
            await _db.addTimetableEntry(entry);
          }

          if (event.eventType == "Lab") isLabDay[day] = true;
          if (event.eventType == "Lecture") lectureScheduledToday["${event.course.courseId}-$day"] = true;

          successfullyScheduledKeys.add(event.uniqueKey);
          return true;
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // The build method remains unchanged
    return Scaffold(
      appBar: AppBar(
        title: Text("Admin Dashboard"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
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
            TextField(controller: _roomIdController, decoration: InputDecoration(labelText: "Room ID (e.g., C-101)")),
            TextField(controller: _capacityController, decoration: InputDecoration(labelText: "Capacity"), keyboardType: TextInputType.number),
            DropdownButton<String>(
              value: _roomType,
              isExpanded: true,
              items: ["Lecture", "Lab", "Tutorial"].map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
              onChanged: (val) => setState(() => _roomType = val!),
            ),
            SizedBox(height: 12),
            ElevatedButton(onPressed: _addClassroom, child: Text("Add Classroom")),
            Divider(height: 30),
            ElevatedButton(
              onPressed: _isLoading ? null : _generateTimetable,
              child: _isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text("Generate Timetable"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
            SizedBox(height: 10),
            Divider(height: 30),
            Text("Existing Classrooms", style: Theme.of(context).textTheme.titleLarge),
            Expanded(
              child: ListView.builder(
                itemCount: classrooms.length,
                itemBuilder: (context, index) {
                  final room = classrooms[index];
                  return Card(
                    child: ListTile(
                      title: Text(room.roomId),
                      subtitle: Text("Capacity: ${room.capacity}, Type: ${room.type}"),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

