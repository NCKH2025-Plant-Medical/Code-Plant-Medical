import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:thunghiem1/Views/camera.dart';
import 'Views/home.dart';
import 'Views/account.dart';
import 'Views/setting.dart';
import '../Services/flutter_integration.dart';


void main() {
  runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: master_screen()));
}

class master_screen extends StatefulWidget {
  const master_screen({Key? key}) : super(key: key);

  @override
  State<master_screen> createState() => _master_screenState();
}

class _master_screenState extends State<master_screen> {
  int myIndex = 0;
  // ImageUploadService fb = ImageUploadService();

  final List<Widget> screens = [
    Home(),
    Camera(),
    Setting(),
    Account(),
  ];
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark, statusBarBrightness: Brightness.light));
    return Scaffold(
      body: screens[myIndex],
      bottomNavigationBar: BottomNavigationBar(
      selectedItemColor: Color.fromRGBO(104, 183, 49, 1),
      backgroundColor: Colors.white,
      type: BottomNavigationBarType.fixed,
      currentIndex: myIndex,
      onTap: (index){
        if(index == 1){
          Navigator.push(context, MaterialPageRoute(builder: (context) => Camera()));
        }
        else{
          setState(() {
            myIndex = index;
          });
        }
      },
      items: const[
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'Camera'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Setting'),
        BottomNavigationBarItem(icon: Icon(Icons.account_circle), label: 'Account'),
      ],
    ),);
  }
}
