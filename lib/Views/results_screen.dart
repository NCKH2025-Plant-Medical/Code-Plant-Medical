import 'package:flutter/material.dart';
import 'package:thunghiem1/main.dart';

void main(){
  runApp(MaterialApp(
  debugShowCheckedModeBanner: false,
  home: ResultsScreen(result: {},),
  ));
}

class ResultsScreen extends StatefulWidget {
  final Map<String, dynamic> result;

  const ResultsScreen({Key? key, required this.result}) : super(key: key);

  @override
  _ResultsState createState() => _ResultsState();
}

class _ResultsState extends State<ResultsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
          child: Stack(
            children: [
                Positioned.fill(
                bottom: 240,
                child:Expanded(child: Image.asset('assets/img/Banner.jpg', fit: BoxFit.cover,),)
                ),

              Positioned.fill(
                top: 240,
                child: Container(
                  decoration: BoxDecoration(
                      color: Colors.white,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(25.0), topRight: Radius.circular(25.0)),
                    boxShadow: [BoxShadow(
                      offset: Offset(0.0, 5.0),
                      color: Colors.grey,
                      blurRadius: 15.0,
                      spreadRadius: 4.0,
                    ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline_rounded, color: Color.fromRGBO(111, 208, 44, 1), shadows: [BoxShadow(offset: Offset(0.3, 0.6),
                              color: Colors.black12, blurRadius: 1, spreadRadius: 1,)],),
                            Text('Successfully Identified', style: TextStyle(color: Color.fromRGBO(111, 208, 44, 1), shadows: [BoxShadow(offset: Offset(0.1, 0.6),
                            color: Colors.black12, blurRadius: 3, spreadRadius: 0.5,)])),
                          ],
                        ),
                      ),
                      Padding(
                      padding: EdgeInsets.fromLTRB(20, 10, 0, 15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text('Loài Cây', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600 , fontSize: 24, shadows: [BoxShadow(offset: Offset(0.1, 0.6),
                            color: Colors.black12, blurRadius: 3, spreadRadius: 0.5,)])),
                        ],
                      ),),
                      Padding(
                        padding: EdgeInsets.fromLTRB(20, 0, 0, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Expanded(child: Text( softWrap: true,style: TextStyle(color: Colors.black87 , fontSize: 20, ) , widget.result.toString())),
                          ],
                        ),),
                      Padding(
                        padding: EdgeInsets.fromLTRB(20, 15, 0, 15),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Text('Mô Tả', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600 , fontSize: 24, shadows: [BoxShadow(offset: Offset(0.1, 0.6),
                              color: Colors.black12, blurRadius: 3, spreadRadius: 0.5,)])),
                          ],
                        ),),
                      Padding(
                        padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Expanded(child: Text(widget.result.toString(), style: TextStyle(color: Colors.black87, fontSize: 17,))),
                          ],
                        ),),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 25.0,
                left: 20.0,
                child: GestureDetector(
                  onTap: (){
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const master_screen()),
                          (route) => false,
                    );
                  },
                  child: Icon(Icons.arrow_back, color: Colors.white,),
                ),
              ),
            ],
          ),
      ),
    );
  }
}
