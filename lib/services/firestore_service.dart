import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/course.dart';
import '../models/classroom.dart';
import '../models/timetable_entry.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Add a course (teacher input)
  Future<void> addCourse(Course course) async {
    await _db.collection('courses').doc(course.courseId).set({
      'courseId': course.courseId,
      'teacherId': course.teacherId,
      'credits': course.credits,
      'hoursPerWeek': course.hoursPerWeek,
      'hasLab': course.hasLab,
      'hasTutorial': course.hasTutorial,
    });
  }

  // Add a classroom (admin input)
  Future<void> addClassroom(Classroom classroom) async {
    await _db.collection('classrooms').doc(classroom.roomId).set({
      'roomId': classroom.roomId,
      'capacity': classroom.capacity,
      'type': classroom.type,
    });
  }

  // Get all courses
  Future<List<Course>> getCourses() async {
    final snapshot = await _db.collection('courses').get();
    return snapshot.docs.map((d) => Course.fromFirestore(d)).toList();
  }

  // Get all classrooms
  Future<List<Classroom>> getClassrooms() async {
    final snapshot = await _db.collection('classrooms').get();
    return snapshot.docs.map((d) => Classroom.fromFirestore(d)).toList();
  }

  // Add a timetable entry (auto-generated)
  Future<void> addTimetableEntry(TimetableEntry entry) async {
    await _db.collection('timetable').add({
      'courseId': entry.courseId,
      'teacherId': entry.teacherId,
      'roomId': entry.roomId,
      'day': entry.day,
      'slot': entry.slot,
    });
  }

  // Fetch timetable for student view
  Future<List<TimetableEntry>> getTimetable() async {
    final snapshot = await _db.collection('timetable').get();
    return snapshot.docs.map((d) => TimetableEntry.fromFirestore(d)).toList();
  }
}

