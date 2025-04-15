// ============================================
// Individual Page Widgets (Stateless)
// ============================================
import 'package:flutter/material.dart';


// --- Page 0: Skin Type ---
class SkinTypePage extends StatelessWidget {
  final List<Map<String, dynamic>> skinTypes;
  final int? selectedSkinTypeId;
  final bool isLoading;
  final ValueChanged<int?> onChanged;

  const SkinTypePage({
    required this.skinTypes,
    required this.selectedSkinTypeId,
    required this.isLoading,
    required this.onChanged, required ValueKey<String> key,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0), // More padding for content area
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What is your primary skin type?',
             style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
             'Select the option that best describes your skin most of the time.',
             style: TextStyle(fontSize: 15, color: Colors.grey[700]),
          ),
          const SizedBox(height: 24),
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else if (skinTypes.isEmpty)
            const Center(child: Text('No skin types found.'))
          else
            Column(
              children: skinTypes.map((type) {
                return RadioListTile<int?>(
                  contentPadding: EdgeInsets.zero, // Adjust padding
                  title: Text(type['skin_type'] ?? 'Unknown Type', style: const TextStyle(fontSize: 16)),
                  value: type['skin_type_id'],
                  groupValue: selectedSkinTypeId,
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


