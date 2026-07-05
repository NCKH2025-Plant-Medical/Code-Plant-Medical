import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thunghiem1/screens/history_screen.dart';
import 'package:thunghiem1/widgets/action_cards.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SingleChildScrollView(
        child: SafeArea(
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      offset: const Offset(2, 0),
                      color: isDark ? Colors.black54 : Colors.grey,
                      blurRadius: 0.9,
                    ),
                  ],
                ),
                child: Image.asset('assets/img/Banner.jpg'),
              ),
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20.0, 40.0, 20.0, 0.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Hello',
                          style: GoogleFonts.darkerGrotesque(
                            fontSize: 31,
                            color: Colors.white70,
                            fontWeight: FontWeight.w800,
                            shadows: const [
                              Shadow(
                                offset: Offset(0.8, 0.8),
                                blurRadius: 1.5,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.search, color: Colors.white, size: 30),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20.0, 5.0, 20.0, 0.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Welcome to Plant Vision',
                          style: GoogleFonts.darkerGrotesque(
                            color: Colors.white70,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            shadows: const [
                              Shadow(
                                offset: Offset(0.8, 0.8),
                                blurRadius: 1.5,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.notifications, color: Colors.white),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22.0, 24.0, 22.0, 0.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade800 : Colors.grey,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            offset: const Offset(0.02, 0.01),
                            blurRadius: 0.7,
                            spreadRadius: 0.2,
                            color: isDark ? Colors.black26 : Colors.white,
                          ),
                        ],
                      ),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Searching',
                          hintStyle: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(30.0, 60.0, 30.0, 0.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ActionCard(
                          title: 'History\nIdentification',
                          subtitle: 'Hello',
                          imagePath: 'assets/img/func1.png',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ImagesListScreen(),
                              ),
                            );
                          },
                        ),
                        ActionCard(
                          title: 'Chức năng 2',
                          subtitle: 'Hello',
                          imagePath: 'assets/img/func2.png',
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(30.0, 60.0, 30.0, 0.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ActionCard(
                          title: 'Chức năng 3',
                          subtitle: 'Hello',
                          imagePath: 'assets/img/func3.png',
                          onTap: () {},
                        ),
                        ActionCard(
                          title: 'Chức năng 4',
                          subtitle: 'Hello',
                          imagePath: 'assets/img/func4.png',
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
