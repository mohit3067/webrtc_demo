import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:webrtc_demo/home_page.dart';
import 'package:webrtc_demo/user_model.dart';

class VerifyScreen extends StatefulWidget {
  final String verificationId;

  const VerifyScreen({super.key, required this.verificationId});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  TextEditingController otpcontroller = TextEditingController();
  final auth = FirebaseAuth.instance;
  bool isLoading = false;

@override
  void dispose() {
   otpcontroller.dispose();
    super.dispose();
  }


  void verifyuser() async {
    setState(() {
      isLoading = true;
    });
    final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: otpcontroller.text.toString());
    try {
      final result =  await auth.signInWithCredential(credential);
      Provider.of<UserManager>(context, listen: false)
          .createUser(result.user!.phoneNumber!, result.user!.uid, result.user!.displayName ?? '', result.user!.photoURL ?? '');
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${e.toString()}'),duration: const Duration(seconds: 5)));
    }
  }

  @override
  Widget build(BuildContext context) {

    return Material(
      child: Scaffold(
        appBar: AppBar(
          title: Center(child: Text('Verify')),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 40.0),
                    child: Lottie.asset(
                      "assets/otp.json",
                    ),
                  ),
                  SizedBox(height:100),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Enter otp",
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: 28.0,
                        color: Color.fromARGB(255, 30, 137, 219),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 30,
                  ),
                  TextFormField(
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    controller: otpcontroller,
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.black,
                    ),
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.lock_clock_sharp,
                        color: Colors.deepPurpleAccent,
                      ),
                      label: const Text("OTP"),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(
                          color: Colors.deepPurpleAccent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  InkWell(
                    onTap: () {
                        verifyuser();
                         Future.delayed(Duration.zero, () {
                           SchedulerBinding.instance.addPostFrameCallback((_) { 
         Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => MyHomePage()));
      });
                         });
                    },
                    child: Container(
                      child: isLoading
                          ? Center(
                              child: CircularProgressIndicator(
                              color: Colors.white,
                            ))
                          : Text(
                              'Verify',
                              style: TextStyle(fontSize: 18, color: Colors.white),
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
