class Classroom {
  final String roomId;
  final int capacity;
  final String type; // "Lecture", "Lab", etc.

  Classroom({
    required this.roomId,
    required this.capacity,
    required this.type,
  });

  // To Firestore
  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'capacity': capacity,
      'type': type,
    };
  }

  // From Firestore
  factory Classroom.fromMap(Map<String, dynamic> map) {
    return Classroom(
      roomId: map['roomId'] ?? '',
      capacity: map['capacity'] ?? 0,
      type: map['type'] ?? 'Lecture',
    );
  }
}

