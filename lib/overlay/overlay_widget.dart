import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayWidget extends StatefulWidget {
  const OverlayWidget({super.key});

  @override
  State<OverlayWidget> createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: _isExpanded ? 180 : 60,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFF0A1E32).withOpacity(0.8),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: const Color(0xFFFF6D00).withOpacity(0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isExpanded) ...[
                IconButton(
                  icon: const Icon(Icons.pause, color: Colors.white),
                  onPressed: () {
                    // TODO: Pause recording
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.stop, color: Colors.red),
                  onPressed: () async {
                    await FlutterOverlayWindow.shareData('stop');
                  },
                ),
                const SizedBox(width: 8),
              ],
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF6D00),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: _isExpanded 
                        ? const Icon(Icons.close, color: Colors.white)
                        : const Icon(Icons.videocam, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
