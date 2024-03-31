import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:webrtc_demo/home_page.dart';
import 'verify_screen.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLoading = false;
  TextEditingController phonecontroller = TextEditingController();
  final auth = FirebaseAuth.instance;

@override
  void dispose() {
    phonecontroller.dispose();
    super.dispose();
  }

@override
  void initState() {
    if (auth.currentUser != null) {
    Future.delayed(Duration(seconds: 3)).then((value) =>  
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MyHomePage(),
      ),
    ),
  );}
    super.initState();
  }

  void loginUser() {
    setState(() {
      isLoading = true;
    });
      auth.verifyPhoneNumber(
      phoneNumber: "+91${phonecontroller.text}",
      verificationCompleted: (_) {
        setState(() {
          isLoading = false;
        });
      },
      verificationFailed: (e) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text("Verification failed: ${e.toString()}"),duration: const Duration(seconds: 5)));
      },
      codeSent: (String verificationId, int? forceResendingToken) {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => VerifyScreen(
                      verificationId: verificationId,
                    )));
      },
      codeAutoRetrievalTimeout: (verificationId) {
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Scaffold(
        appBar: AppBar(
          title: Center(child: Text('Login')),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Lottie.asset(
                    "assets/login.json",
                  ),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Welcome to WebRTC",
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: 28.0,
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 30,
                  ),
                  TextFormField(
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    controller: phonecontroller,
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.black,
                    ),
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.phone,
                        color: Colors.deepPurpleAccent,
                      ),
                      label: const Text("Phone no."),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(
                          color: Colors.deepPurpleAccent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 10,),
                  InkWell(
                    onTap: () {
                        loginUser();
                    },
                    child: Container(
                      child:isLoading
                          ? Center(
                              child: CircularProgressIndicator(
                              color: Colors.white,
                            ))
                          : Text(
                              'log-in',
                              style: TextStyle(fontSize: 18,color: Colors.white),
                            ),

                      width: double.infinity,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.blue,
                      ),
                      height: 65.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
