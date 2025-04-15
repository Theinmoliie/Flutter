import 'package:flutter/material.dart';
import 'dart:io';


class AnalysisPage extends StatefulWidget {
  final String imagePath;
  final bool isFrontCamera; // Add this parameter

  const AnalysisPage({
    Key? key, 
    required this.imagePath,
    this.isFrontCamera = true // Default to true for front camera
  }) : super(key: key);

  @override
  _AnalysisPageState createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  bool _isAnalyzing = true;
  Map<String, double>? _analysisResults;

  @override
  void initState() {
    super.initState();
    _startAnalysis();
  }

  Future<void> _startAnalysis() async {
    // Simulate analysis (replace with your actual ML model call)
    await Future.delayed(Duration(seconds: 3));
    
    setState(() {
      _isAnalyzing = false;
      _analysisResults = {
        'hydration': 0.85,
        'wrinkles': 0.15,
        'spots': 0.05,
        'acne': 0.02,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Skin Analysis')),
      body: _isAnalyzing
          ? Center(child: CircularProgressIndicator())
          : _buildResults(),
    );
  }

  Widget _buildResults() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Mirrored image container
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..scale(widget.isFrontCamera ? -1.0 : 1.0, 1.0, 1.0),
            child: Container(
              width: double.infinity,
              height: 300,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: FileImage(File(widget.imagePath)),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Analysis Results',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
          if (_analysisResults != null)
            ..._analysisResults!.entries.map((entry) => 
              ListTile(
                title: Text(entry.key.toUpperCase()),
                subtitle: LinearProgressIndicator(
                  value: entry.value,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                trailing: Text('${(entry.value * 100).toStringAsFixed(0)}%'),
              ),
            ),
        ],
      ),
    );
  }
}