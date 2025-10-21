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
      backgroundColor: Color(0xFF12212D),
      appBar: AppBar(backgroundColor: Color(0xFF12212D),
          title: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(child: const Text('Schedule Me',
              style: TextStyle(
                  color: Color(0xFFCCD0CF),
                  fontSize: 50,
               fontFamily: 'IngridDarling'),
            )),
          )),
      body: SingleChildScrollView(
        child: Container(color: Color(0xFF12212D),
          child: Padding(
            padding: const EdgeInsets.only(left: 40,right: 40,top: 70,bottom: 40),
            child: Container(
              decoration: BoxDecoration(
              color: Color(0xFFCCD0CF),
              borderRadius: BorderRadius.circular(30.0),
            ),
              padding: EdgeInsets.all(40.0),
              height: 450,
              child: Column(children: [
                Center(child: Text("Login",style: TextStyle(color: Color(0xFF12212D), fontSize: 20,),),),
                Container(child: TextField(controller: _name, decoration: InputDecoration(labelStyle: TextStyle(color: Color(0xFF12212D)),labelText: 'Username'))),
                TextField(controller: _email, decoration: InputDecoration(labelStyle: TextStyle(color: Color(0xFF12212D)),labelText: 'Email')),
                TextField(controller: _pass, decoration: InputDecoration(labelStyle: TextStyle(color: Color(0xFF12212D)),labelText: 'Password'), obscureText: true),
                SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  items: ['student','teacher','admin'].map((r) => DropdownMenuItem(child: Text(r,style: TextStyle(color: Color(0xFFCCD0CF),),), value: r)).toList(),
                  onChanged: (v) { if (v!=null) setState(()=>_role=v); },
                    dropdownColor: Color(0xFF12212D),
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
                      fillColor: Color(0xFF12212D),
                  ),
                ),
                SizedBox(height: 12),
                ElevatedButton(
                    onPressed: _loading ? null : _onLogin,
                    child: _loading ? CircularProgressIndicator() : Text('Login / Register'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF12212D), // Background color
                    foregroundColor: Color(0xFFCCD0CF), // Text color
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

