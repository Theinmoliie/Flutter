// skin_concerns.dart
import 'package:flutter/material.dart';

class ConcernsPage extends StatelessWidget {
  final List<Map<String, dynamic>> skinConcerns;
  final Set<int> selectedConcernIds;
  final bool isNoneSelected;
  final bool isLoading;
  final Function(int, bool?) onConcernChanged;
  final Function(bool?) onNoneChanged;

  const ConcernsPage({
    // Add super.key for good practice
    super.key,
    required this.skinConcerns,
    required this.selectedConcernIds,
    required this.isNoneSelected,
    required this.isLoading,
    required this.onConcernChanged,
    required this.onNoneChanged,
    // Remove the explicit key requirement from constructor if not needed elsewhere
    // required ValueKey<String> key,
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
             'Do you have any specific skin concerns?',
             style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
           ),
           const SizedBox(height: 8),
            Text(
              'Select all that apply, or choose \'None\' if you don\'t have specific issues you want to address.',
              style: TextStyle(fontSize: 15, color: Colors.grey[700]),
           ),
           const SizedBox(height: 24),
           if (isLoading)
             const Center(child: CircularProgressIndicator())
           else if (skinConcerns.isEmpty && !isNoneSelected)
              const Center(child: Text('No skin concerns found to select.'))
           else
             Column(
               children: [
                 // 'None' Checkbox
                 CheckboxListTile(
                   contentPadding: EdgeInsets.zero,
                   title: const Text('None', style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic)),
                   value: isNoneSelected,
                   onChanged: onNoneChanged,
                   activeColor: colorScheme.primary,
                   controlAffinity: ListTileControlAffinity.leading,
                 ),

                 // List of Real Concerns
                 ...skinConcerns.map((concern) {
                   final int concernId = concern['concern_id'];
                   return CheckboxListTile(
                     contentPadding: EdgeInsets.zero,
                     // Keep title styling for visual feedback
                     title: Text(concern['concern'] ?? 'Unknown Concern', style: TextStyle(fontSize: 16, color: isNoneSelected ? Colors.grey : null)),
                     // Value determines if it *looks* checked
                     value: !isNoneSelected && selectedConcernIds.contains(concernId),
                     // onChanged *always* calls the parent callback
                     onChanged: (value) => onConcernChanged(concernId, value),
                     activeColor: colorScheme.primary,
                     controlAffinity: ListTileControlAffinity.leading,
              
                   );
                 }).toList(),
               ],
             ),
         ],
       ),
     );
  }
}