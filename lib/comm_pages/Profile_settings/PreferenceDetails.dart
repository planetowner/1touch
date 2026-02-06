import "package:flutter/material.dart";
import 'package:onetouch/core/stylesheet_dark.dart';

class PreferenceDetailScreen extends StatefulWidget {
  final String title;
  final List<String> options;
  final String selectedOption;

  const PreferenceDetailScreen({
    super.key,
    required this.title,
    required this.options,
    required this.selectedOption,
  });

  @override
  State<PreferenceDetailScreen> createState() => _PreferenceDetailScreenState();
}

class _PreferenceDetailScreenState extends State<PreferenceDetailScreen> {
  late String _currentSelection;

  @override
  void initState() {
    super.initState();
    _currentSelection = widget.selectedOption;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context), // Go back without saving
        ),
        title: Text(
          widget.title.toUpperCase(),
          style: Body1.style,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Divider(color: Color(0xFF3A3A3A), height: 1, thickness: 1),
            Expanded(
              child: ListView.separated(
                itemCount: widget.options.length,
                separatorBuilder: (context, index) => const Divider(
                  color: Color(0xFF3A3A3A),
                  height: 1,
                  thickness: 1,
                  indent: 24, // Optional indent for cleaner look
                ),
                itemBuilder: (context, index) {
                  final option = widget.options[index];
                  final isSelected = option == _currentSelection;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    title: Text(
                      option,
                      style: Body1.style.copyWith(color: isSelected ? Colors.white : Colors.white70,)
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: Color(0xFFD82457)) // Your App Red
                        : null,
                    onTap: () {
                      setState(() {
                        _currentSelection = option;
                      });
                      // Optional: Auto-close on select?
                      // For now, we update state and wait for user to hit "Done" or "Back"
                      // Or simpler: Return immediately on tap:
                      Navigator.pop(context, option);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}