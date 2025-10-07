class Course {
  final String courseId;
  final String teacherId;
  final String courseName;
  final int credits;
  final int hoursPerWeek;
  final bool hasLab;
  final bool hasTutorial;

  Course({
    required this.courseId,
    required this.teacherId,
    required this.courseName,
    required this.credits,
    required this.hoursPerWeek,
    required this.hasLab,
    required this.hasTutorial,
  });

  // To Firestore
  Map<String, dynamic> toMap() {
    return {
      'courseId': courseId,
      'teacherId': teacherId,
      'courseName': courseName,
      'credits': credits,
      'hoursPerWeek': hoursPerWeek,
      'hasLab': hasLab,
      'hasTutorial': hasTutorial,
    };
  }

  // From Firestore
  factory Course.fromMap(Map<String, dynamic> map) {
    return Course(
      courseId: map['courseId'] ?? '',
      teacherId: map['teacherId'] ?? '',
      courseName: map['courseName'] ?? '',
      credits: map['credits'] ?? 0,
      hoursPerWeek: map['hoursPerWeek'] ?? 0,
      hasLab: map['hasLab'] ?? false,
      hasTutorial: map['hasTutorial'] ?? false,
    );
  }
}

