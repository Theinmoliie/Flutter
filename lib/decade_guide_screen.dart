// lib/screens/decade_guide_screen.dart
import 'package:flutter/material.dart';
import '../model/decade_guide.dart';
import '../services/skincare_service.dart';

class DecadeGuideScreen extends StatefulWidget {
  const DecadeGuideScreen({Key? key}) : super(key: key);

  @override
  State<DecadeGuideScreen> createState() => _DecadeGuideScreenState();
}

class _DecadeGuideScreenState extends State<DecadeGuideScreen> {
  final SkincareService _skincareService = SkincareService();
  late Future<DecadeGuide> _guideFuture;

  @override
  void initState() {
    super.initState();
    _guideFuture = _skincareService.getDecadeGuide();
  }

  @override
  Widget build(BuildContext context) {
    // Get the theme colors once for easy access
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF6FF), // Soft background for the body
      // --- START: NEW APPBAR ---
      appBar: AppBar(
        title: const Text('Skincare Compass'),
        backgroundColor: colorScheme.primary, 
        foregroundColor: colorScheme.onPrimary,
      ),
      // --- END: NEW APPBAR ---
      
      body: FutureBuilder<DecadeGuide>(
        future: _guideFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("An error occurred: ${snapshot.error}"));
          }
          if (snapshot.hasData) {
            final guide = snapshot.data!;
            
            // Use SingleChildScrollView for a standard scrolling list
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dynamic title from JSON as a headline
                    Text(
                      guide.title,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    // Summary text
                    Text(
                      guide.summary,
                      style: TextStyle(fontSize: 16, height: 1.5, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 24),

                    const Divider(height: 48, thickness: 1),

                    // Common Concerns tags
                    _buildTagsSection(
                      "Common Concerns",
                      guide.commonConcerns,
                      Colors.orange.shade100,
                      Colors.orange.shade900,
                    ),
                    const SizedBox(height: 24),
                    
                    const Divider(height: 48, thickness: 1),

                    // Focus On tags
                    _buildTagsSection(
                      "Focus On",
                      guide.focusOn,
                      Colors.green.shade100,
                      Colors.green.shade900,
                    ),
                    const Divider(height: 48, thickness: 1),

                    // Spotlight Ingredients section title
                    const Text(
                      "Spotlight Ingredients",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    // ListView.builder for the ingredients
                    // These properties are required inside a SingleChildScrollView
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: guide.spotlightIngredients.length,
                      itemBuilder: (context, index) {
                        final ingredient = guide.spotlightIngredients[index];
                        // We add padding here instead of wrapping the whole ListView
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: _buildIngredientCard(ingredient),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          }
          return const Center(child: Text("Loading your guide..."));
        },
      ),
    );
  }

  // Helper widgets are unchanged and work perfectly here
  Widget _buildTagsSection(String title, List<String> tags, Color bgColor, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: tags.map((tag) => Chip(
            label: Text(tag, style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
            backgroundColor: bgColor,
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildIngredientCard(dynamic ingredient) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ingredient.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(ingredient.tagline, style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade600)),
            const Divider(height: 20),
            Text(ingredient.description, style: const TextStyle(height: 1.4)),
          ],
        ),
      ),
    );
  }
}