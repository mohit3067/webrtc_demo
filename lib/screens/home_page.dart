import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:webrtc_demo/home_view.dart';
import 'package:webrtc_demo/screens/chat_page.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  String userType = 'H';
  final db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 50,
                width: 400,
                child: ElevatedButton(
                  style: ButtonStyle(
                    foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
                    backgroundColor: MaterialStateProperty.all<Color>(Colors.lightBlue),
                  ),
                  onPressed: () async{
                    User? currentUser = FirebaseAuth.instance.currentUser;
                    DocumentSnapshot snapshot =
                        await FirebaseFirestore.instance.collection('user').doc(currentUser!.uid).get();
                    String documentId = snapshot.id;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const HomePage(userType: 'H'),
                      ),
                    );
                  },
                  child: const Text("start video Call"),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 50,
                width: 400,
                child: ElevatedButton(
                  style: ButtonStyle(
                    foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
                    backgroundColor: MaterialStateProperty.all<Color>(Colors.lightBlue),
                  ),
                  onPressed: () async => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const HomePage(userType: 'V'),
                    ),
                  ),
                  child: const Text("video call join"),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 50,
                width: 400,
                child: ElevatedButton(
                  style: ButtonStyle(
                    foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
                    backgroundColor: MaterialStateProperty.all<Color>(Colors.lightBlue),
                  ),
                  onPressed: () async => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>  ChatPage(),
                    ),
                  ),
                  child: const Text("Chat"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }}


