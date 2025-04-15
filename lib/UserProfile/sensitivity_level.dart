import 'package:flutter/material.dart';

// --- Page 1: Sensitivity Level ---
class SensitivityPage extends StatelessWidget {
  final List<String> sensitivityOptions;
  final String? selectedSensitivityLevel;
  final ValueChanged<String?> onChanged;

  const SensitivityPage({
    required this.sensitivityOptions,
    required this.selectedSensitivityLevel,
    required this.onChanged, required ValueKey<String> key,
  });

  @override
  Widget build(BuildContext context) {
     final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
       padding: const EdgeInsets.all(24.0),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           const Text(
              'How sensitive is your skin?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
           ),
           const SizedBox(height: 8),
           Text(
              'Consider how easily your skin reacts to new products or environmental factors.',
              style: TextStyle(fontSize: 15, color: Colors.grey[700]),
            ),
           const SizedBox(height: 24),
           Column(
             children: sensitivityOptions.map((level) {
               return RadioListTile<String?>(
                 contentPadding: EdgeInsets.zero,
                 title: Text(level, style: const TextStyle(fontSize: 16)),
                 value: level,
                 groupValue: selectedSensitivityLevel,
                 onChanged: onChanged,
                 activeColor: colorScheme.primary,
               );
             }).toList(),
           ),
         ],
       ),
     );
  }
}
