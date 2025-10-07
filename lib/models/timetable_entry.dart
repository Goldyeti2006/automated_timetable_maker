class TimetableEntry {
  final String courseId;
  final String baseCourseId;
  final String courseName; // <-- NEW FIELD
  final String teacherId;
  final String roomId;
  final String day;
  final String slot;

  TimetableEntry({
    required this.courseId,
    required this.baseCourseId,
    required this.courseName, // <-- Added to constructor
    required this.teacherId,
    required this.roomId,
    required this.day,
    required this.slot,
  });

  Map<String, dynamic> toMap() {
    return {
      'courseId': courseId,
      'baseCourseId': baseCourseId,
      'courseName': courseName, // <-- Added to map
      'teacherId': teacherId,
      'roomId': roomId,
      'day': day,
      'slot': slot,
    };
  }

  factory TimetableEntry.fromMap(Map<String, dynamic> map) {
    return TimetableEntry(
      courseId: map['courseId'] ?? '',
      baseCourseId: map['baseCourseId'] ?? '',
      courseName: map['courseName'] ?? '', // <-- Added from map
      teacherId: map['teacherId'] ?? '',
      roomId: map['roomId'] ?? '',
      day: map['day'] ?? '',
      slot: map['slot'] ?? '',
    );
  }
}

