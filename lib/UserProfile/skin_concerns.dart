// skin_concerns.dart
import 'package:flutter/material.dart';

class ConcernsPage extends StatelessWidget {
  final List<Map<String, dynamic>> skinConcerns;
  final Set<int> selectedConcernIds;
  final bool isNoneSelected;
  final bool isLoading;
  final Function(int, bool?) onConcernChanged;
  final Function(bool?) onNoneChanged;
  final int maxConcernsAllowed = 3; // Define the limit

  const ConcernsPage({
    super.key,
    required this.skinConcerns,
    required this.selectedConcernIds,
    required this.isNoneSelected,
    required this.isLoading,
    required this.onConcernChanged,
    required this.onNoneChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool canSelectMoreConcerns = selectedConcernIds.length < maxConcernsAllowed;

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
              'Select up to $maxConcernsAllowed that apply, or choose \'None\' if you don\'t have specific issues you want to address.', // Updated text
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
                 CheckboxListTile(
                   contentPadding: EdgeInsets.zero,
                   title: const Text('None', style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic)),
                   value: isNoneSelected,
                   onChanged: onNoneChanged,
                   activeColor: colorScheme.primary,
                   controlAffinity: ListTileControlAffinity.leading,
                 ),
                 ...skinConcerns.map((concern) {
                   final int concernId = concern['concern_id'];
                   final bool isSelected = selectedConcernIds.contains(concernId);
                   
                   // Disable if "None" is selected OR if max concerns are selected and this one isn't already selected.
                   final bool isDisabled = isNoneSelected || (!isSelected && !canSelectMoreConcerns);

                   return CheckboxListTile(
                     contentPadding: EdgeInsets.zero,
                     title: Text(
                       concern['concern'] ?? 'Unknown Concern', 
                       style: TextStyle(
                         fontSize: 16, 
                         color: isDisabled && !isSelected ? Colors.grey.shade400 : (isNoneSelected ? Colors.grey : null),
                       )
                     ),
                     value: !isNoneSelected && isSelected,
                     onChanged: isDisabled 
                        ? null // Disable checkbox if conditions are met
                        : (value) => onConcernChanged(concernId, value),
                     activeColor: colorScheme.primary,
                     controlAffinity: ListTileControlAffinity.leading,
                     // Optionally, change tile color or add visual cue when disabled
                     // tileColor: isDisabled ? Colors.grey.shade100 : null, 
                   );
                 }).toList(),
               ],
             ),
         ],
       ),
     );
  }
}