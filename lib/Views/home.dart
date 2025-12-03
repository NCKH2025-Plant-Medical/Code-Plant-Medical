import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main(){
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Home(),
  ));
}

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: SafeArea(
          child: Stack(
              children: [
                //Lớp 1
                Container(
                  color: Color.fromRGBO(245, 246, 250, 0.9),
                ),
                //Lớp 2
                Container(
                  child: Image.asset('assets/img/Banner.jpg'),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          offset: Offset(2, 0),
                          color: Colors.grey,
                          blurRadius: 0.9,
                        ),
                      ]
                  ),
                ),
                //Lớp 3
                Column(
                  children: [
                    //Phần đầu tiên của cột
                    Padding(padding: EdgeInsets.fromLTRB(20.0, 40.0, 20.0, 0.0),

                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Hello', style: GoogleFonts.darkerGrotesque(
                              fontSize: 31, color: Colors.white70, fontWeight: FontWeight.w800, shadows: [Shadow(
                              offset: Offset(0.8, 0.8), blurRadius: 1.5, color: Colors.white
                          )]
                          ),),
                          Icon(Icons.search, color: Colors.white, size: 30,),
                        ],
                      ),

                    ),
                    //Phần thứ 2 của cột
                    Padding(padding: EdgeInsets.fromLTRB(20.0, 5.0, 20.0, 0.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Welcome to Plant Vision', style: GoogleFonts.darkerGrotesque(
                              color: Colors.white70, fontSize: 28, fontWeight: FontWeight.w800, shadows: [Shadow(
                              offset: Offset(0.8, 0.8), blurRadius: 1.5, color: Colors.white
                          )]
                          )  ,),
                          Icon(Icons.notifications, color: Colors.white,),
                        ],
                      ),
                    ),
                    //Phần thứ 3 của cột
                    //Thanh tìm kiếm
                    Padding(padding: EdgeInsets.fromLTRB(22.0, 28.0, 22.0, 0.0),
                      child: Container(
                        decoration: BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                offset: Offset(0.02, 0.01),
                                blurRadius: 0.7,
                                spreadRadius: 0.2,
                                color: Colors.white,
                              )
                            ]
                        ),
                        child: TextField(
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Color.fromRGBO(246, 242, 250, 0.99),
                            hintText: 'Searching',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                    //Phần thú 4 của cột
                    // Mục các button function
                    Padding(padding: EdgeInsets.fromLTRB(30.0, 60.0, 30.0, 0.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: (){

                            },
                            child: Container(
                              width: 160,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [BoxShadow(
                                  color: Color.fromRGBO(220, 221, 225, 1),
                                  offset: Offset(0.1, 0.1),
                                  spreadRadius: 1,
                                  blurRadius: 8,
                                )],
                              ),

                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        // Icon(Icons.ac_unit, size: 50, color: Colors.grey,),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: (){

                            },
                            child: Container(
                              width: 160,
                              height: 120,
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color.fromRGBO(220, 221, 225, 1),
                                      offset: Offset(0.1, 0.1),
                                      spreadRadius: 1,
                                      blurRadius: 8,
                                    )
                                  ]
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(padding: EdgeInsets.fromLTRB(30.0, 60.0, 30.0, 0.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: (){

                            },
                            child: Container(
                              width: 160,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [BoxShadow(
                                  color: Color.fromRGBO(220, 221, 225, 1),
                                  offset: Offset(0.1, 0.1),
                                  spreadRadius: 1,
                                  blurRadius: 8,
                                )],
                              ),

                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        // Icon(Icons.ac_unit, size: 50, color: Colors.grey,),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: (){

                            },
                            child: Container(
                              width: 160,
                              height: 120,
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color.fromRGBO(220, 221, 225, 1),
                                      offset: Offset(0.1, 0.1),
                                      spreadRadius: 1,
                                      blurRadius: 8,
                                    )
                                  ]
                              ),
                            ),
                          ),

                        ],
                      ),
                    ),
                  ],
                ),
              ]),
        ),
      ),
    );
  }
}


