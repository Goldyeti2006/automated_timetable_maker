import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'student_home.dart';
import 'teacher_home.dart';
import 'admin_home.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _name = TextEditingController();
  String _role = 'student';
  bool _loading = false;

  void _routeForRole(String role) {
    if (role == 'student') Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => StudentHome()));
    else if (role == 'teacher') Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TeacherHome()));
    else Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AdminHome()));
  }

  Future<void> _onLogin() async {
    setState(() => _loading = true);
    try {
      final user = await AuthService.signInOrRegister(_email.text.trim(), _pass.text.trim(), _role, _name.text.trim());
      if (user != null) {
        // fetch role from DB (in case user existed)
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final role = doc.data()?['role'] ?? _role;
        _routeForRole(role);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Auth error: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login / Register')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          TextField(controller: _name, decoration: InputDecoration(labelText: 'Name (for new users)')),
          TextField(controller: _email, decoration: InputDecoration(labelText: 'Email')),
          TextField(controller: _pass, decoration: InputDecoration(labelText: 'Password'), obscureText: true),
          SizedBox(height: 12),
          DropdownButton<String>(
            value: _role,
            items: ['student','teacher','admin'].map((r) => DropdownMenuItem(child: Text(r), value: r)).toList(),
            onChanged: (v) { if (v!=null) setState(()=>_role=v); },
          ),
          SizedBox(height: 12),
          ElevatedButton(
              onPressed: _loading ? null : _onLogin,
              child: _loading ? CircularProgressIndicator() : Text('Login / Register')
          ),
        ]),
      ),
    );
  }
}

