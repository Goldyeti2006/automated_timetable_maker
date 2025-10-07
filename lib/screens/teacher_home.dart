import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/course.dart';
import '../services/db_service.dart';
import 'login_screen.dart'; // Import the login screen to navigate back to it

class TeacherHome extends StatefulWidget {
  @override
  _TeacherHomeState createState() => _TeacherHomeState();
}

class _TeacherHomeState extends State<TeacherHome> {
  final _formKey = GlobalKey<FormState>();
  final DBService _db = DBService();
  final _courseIdController = TextEditingController();
  final _courseNameController = TextEditingController();
  final _creditsController = TextEditingController();
  final _hoursController = TextEditingController();
  bool _hasLab = false;
  bool _hasTutorial = false;
  bool _isLoading = false;

  // THIS IS THE NEW LOGOUT FUNCTION
  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    // This will take you back to the login screen and prevent you from going "back"
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginScreen()),
          (Route<dynamic> route) => false,
    );
  }

  void _saveCourse() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final String? teacherId = FirebaseAuth.instance.currentUser?.uid;
      if (teacherId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: Not logged in!')),
        );
        setState(() => _isLoading = false);
        return;
      }

      final course = Course(
        courseId: _courseIdController.text.trim().toUpperCase(),
        teacherId: teacherId,
        courseName: _courseNameController.text.trim(),
        credits: int.parse(_creditsController.text),
        hoursPerWeek: int.parse(_hoursController.text),
        hasLab: _hasLab,
        hasTutorial: _hasTutorial,
      );

      await _db.addCourse(course);

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Course Added Successfully')));

      _formKey.currentState?.reset();
      _courseIdController.clear();
      _courseNameController.clear();
      _creditsController.clear();
      _hoursController.clear();
      setState(() {
        _hasLab = false;
        _hasTutorial = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Teacher - Add Course"),
        // THIS IS THE NEW LOGOUT BUTTON
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
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _courseIdController,
                decoration: InputDecoration(labelText: "Course ID (e.g., CSE101)"),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              TextFormField(
                controller: _courseNameController,
                decoration: InputDecoration(labelText: "Course Name"),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              TextFormField(
                controller: _creditsController,
                decoration: InputDecoration(labelText: "Credits"),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              TextFormField(
                controller: _hoursController,
                decoration: InputDecoration(labelText: "Hours per Week"),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              SwitchListTile(
                title: Text("Has Lab"),
                value: _hasLab,
                onChanged: (val) => setState(() => _hasLab = val),
              ),
              SwitchListTile(
                title: Text("Has Tutorial"),
                value: _hasTutorial,
                onChanged: (val) => setState(() => _hasTutorial = val),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveCourse,
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text("Save Course"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

