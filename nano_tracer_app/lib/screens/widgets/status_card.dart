import 'package:flutter/material.dart';

class StatusCard extends StatelessWidget {
  final bool isConnected;

  const StatusCard({super.key, required this.isConnected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Text("Status", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: isConnected ? Colors.green.shade50 : Colors.grey.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isConnected ? Colors.green.shade200 : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Icon(
                  Icons.bluetooth,
                  color: isConnected ? Colors.black : Colors.grey,
                  size: 32,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text(isConnected ? "Connected" : "Disconnected", style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}