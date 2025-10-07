import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/course.dart';
import '../models/classroom.dart';
import '../models/timetable_entry.dart';

class DBService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---- COURSE OPERATIONS ----
  Future<void> addCourse(Course course) async {
    await _db.collection('courses').doc(course.courseId).set(course.toMap());
  }

  Future<List<Course>> getCourses() async {
    final snapshot = await _db.collection('courses').get();
    // FIX: Changed fromFirestore(doc) to fromMap(doc.data())
    return snapshot.docs.map((doc) => Course.fromMap(doc.data())).toList();
  }

  // ---- CLASSROOM OPERATIONS ----
  Future<void> addClassroom(Classroom room) async {
    await _db.collection('classrooms').doc(room.roomId).set(room.toMap());
  }

  Future<List<Classroom>> getClassrooms() async {
    final snapshot = await _db.collection('classrooms').get();
    // FIX: Changed fromFirestore(doc) to fromMap(doc.data())
    return snapshot.docs.map((doc) => Classroom.fromMap(doc.data())).toList();
  }

  // ---- TIMETABLE OPERATIONS ----
  Future<void> addTimetableEntry(TimetableEntry entry) async {
    await _db.collection('timetable').add(entry.toMap());
  }

  Future<List<TimetableEntry>> getTimetable() async {
    final snapshot = await _db.collection('timetable').get();
    // FIX: Changed fromFirestore(doc) to fromMap(doc.data())
    return snapshot.docs.map((doc) => TimetableEntry.fromMap(doc.data())).toList();
  }

  Future<void> clearTimetable() async {
    final snapshot = await _db.collection('timetable').get();
    final batch = _db.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
// Add this new function to your DBService class

  Future<List<TimetableEntry>> getTimetableForStudent(String studentUid) async {
    // Step 1: Get the student's document to find their registered courses.
    final userDoc = await _db.collection('users').doc(studentUid).get();
    if (!userDoc.exists) {
      return []; // Return empty if the user doesn't exist
    }

    // Step 2: Get the list of course IDs the student is registered for.
    final registeredCourses = List<String>.from(userDoc.data()?['registeredCourses'] ?? []);
    if (registeredCourses.isEmpty) {
      return []; // Return empty if they haven't registered for any courses
    }

    // Step 3: Fetch only the timetable entries that match those course IDs.
    // This is the line to change:
    final timetableSnapshot = await _db
        .collection('timetable')
        .where('baseCourseId', whereIn: registeredCourses) // <-- THIS LINE IS UPDATED
        .get();

    return timetableSnapshot.docs.map((doc) => TimetableEntry.fromMap(doc.data())).toList();
  }
  Future<void> addSampleStudents() async {
    final batch = _db.batch();

    // A list of 15 sample students with their course registrations
    final List<Map<String, dynamic>> students = [
      {
        "uid": "student_uid_01", "name": "Rohan Sharma", "email": "rohan.s@test.com", "role": "student",
        "registeredCourses": ["CS262", "MA261", "CS263"]
      },
      {
        "uid": "student_uid_02", "name": "Priya Patel", "email": "priya.p@test.com", "role": "student",
        "registeredCourses": ["CS262", "MA262"]
      },
      {
        "uid": "student_uid_03", "name": "Amit Singh", "email": "amit.s@test.com", "role": "student",
        "registeredCourses": ["CS263", "MA261", "MA262"]
      },
      {
        "uid": "student_uid_04", "name": "Sneha Reddy", "email": "sneha.r@test.com", "role": "student",
        "registeredCourses": ["CS262", "CS263", "MA261", "MA262"]
      },
      {
        "uid": "student_uid_05", "name": "Vikram Kumar", "email": "vikram.k@test.com", "role": "student",
        "registeredCourses": ["DAA", "MA261"]
      },
      {
        "uid": "student_uid_06", "name": "Anjali Mehta", "email": "anjali.m@test.com", "role": "student",
        "registeredCourses": ["CS262", "MA262"]
      },
      {
        "uid": "student_uid_07", "name": "Sandeep Desai", "email": "sandeep.d@test.com", "role": "student",
        "registeredCourses": ["CS263"]
      },
      {
        "uid": "student_uid_08", "name": "Kavita Joshi", "email": "kavita.j@test.com", "role": "student",
        "registeredCourses": ["MA261", "MA262", "CS262"]
      },
      {
        "uid": "student_uid_09", "name": "Manish Gupta", "email": "manish.g@test.com", "role": "student",
        "registeredCourses": ["CS263", "MA261"]
      },
      {
        "uid": "student_uid_10", "name": "Deepa Iyer", "email": "deepa.i@test.com", "role": "student",
        "registeredCourses": ["CS262", "MA262", "CS263"]
      },
      {
        "uid": "student_uid_11", "name": "Arjun Nair", "email": "arjun.n@test.com", "role": "student",
        "registeredCourses": ["MA261", "MA262"]
      },
      {
        "uid": "student_uid_12", "name": "Pooja Rao", "email": "pooja.r@test.com", "role": "student",
        "registeredCourses": ["CS262", "CS263"]
      },
      {
        "uid": "student_uid_13", "name": "Rajesh Kannan", "email": "rajesh.k@test.com", "role": "student",
        "registeredCourses": ["MA261", "CS263"]
      },
      {
        "uid": "student_uid_14", "name": "Sunita Menon", "email": "sunita.m@test.com", "role": "student",
        "registeredCourses": ["CS262", "MA261", "MA262"]
      },
      {
        "uid": "student_uid_15", "name": "Girish Patil", "email": "girish.p@test.com", "role": "student",
        "registeredCourses": ["CS263", "CS262", "MA261", "MA262"]
      }
    ];

    // Loop through the list and add each student to a batch write
    for (var studentData in students) {
      final docRef = _db.collection('users').doc(studentData['uid'] as String);
      batch.set(docRef, studentData);
    }

    // Commit the batch write to Firestore
    await batch.commit();
    print("Successfully added 15 sample students.");
  }
}


