import 'package:flutter/material.dart';
import 'package:nano_tracer_app/screens/settings_screen.dart';
import 'package:nano_tracer_app/screens/tag_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<String> tags = ["Wallet Tag", "Home key Tag", "Car key Tag"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),

      // App bar with logo and action buttons
      appBar: AppBar(
        title: Text(
          "NanoTrace",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w400
          ),
        ),
        actions: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (context) => SettingsScreen()),
                  );
                }, 
                icon: Icon(Icons.settings, size: 28, color: Colors.teal.shade900,)
              ),
              SizedBox(width: 10),
            ],
          ),
        ],
        toolbarHeight: 80,
        backgroundColor: Color(0xFFF5F5F5),
      ),

      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32.0),
              child: Text(
                "My Trackers",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600
                ),
              ),
            ),

            Expanded(
              child: ListView.builder(
                itemCount: tags.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16.0),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(builder: (context) => TagScreen()),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white, 
                          borderRadius: BorderRadius.circular(16), 
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                tags[index], 
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500
                                ),
                              ),
                              Row(
                                children: [
                                  Text("Connected"),
                                  SizedBox(width: 4),
                                  Icon(Icons.circle, color: Colors.greenAccent)
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: Icon(Icons.add),
        label: Text("New Tag"),
        backgroundColor: Colors.teal, 
        foregroundColor: Colors.white, 
        elevation: 8.0, // Custom elevation/shadow
        shape: RoundedRectangleBorder( // Custom shape
          borderRadius: BorderRadius.circular(16.0),
        ),
        extendedTextStyle: const TextStyle( 
          fontSize: 16.0,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
