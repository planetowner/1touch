import "package:flutter/material.dart";
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';

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
      backgroundColor: AppColors.of(context).pageBackground,
      appBar: AppBar(
        backgroundColor: AppColors.of(context).pageBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: Theme.of(context).colorScheme.onSurface,
          ),
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
            Divider(
              color: AppColors.of(context).divider,
              height: 1,
              thickness: 1,
            ),
            Expanded(
              child: ListView.separated(
                itemCount: widget.options.length,
                separatorBuilder: (context, index) => Divider(
                  color: AppColors.of(context).divider,
                  height: 1,
                  thickness: 1,
                  indent: 24, // Optional indent for cleaner look
                ),
                itemBuilder: (context, index) {
                  final option = widget.options[index];
                  final isSelected = option == _currentSelection;

                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    title: Text(
                      option,
                      style: Body1.style.copyWith(
                        color: isSelected
                            ? Theme.of(context).colorScheme.onSurface
                            : AppColors.of(context).mutedForeground,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check,
                            color: Color(0xFFD82457)) // Your App Red
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
