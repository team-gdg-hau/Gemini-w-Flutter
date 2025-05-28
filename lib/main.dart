import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:io';

void main() => runApp(LegalDocAnalyzerApp());

class LegalDocAnalyzerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Legal Doc Analyzer',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: LegalDocAnalyzerScreen(),
    );
  }
}

class LegalDocAnalyzerScreen extends StatefulWidget {
  @override
  _LegalDocAnalyzerScreenState createState() => _LegalDocAnalyzerScreenState();
}

class _LegalDocAnalyzerScreenState extends State<LegalDocAnalyzerScreen> {
  final _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _goodLegal = '';
  String _badLegal = '';
  String _verdict = '';
  String _summary = '';
  bool _loading = false;
  File? _selectedImage;

  final String _apiKey = 'AIzaSyAVf0kDtdaaakhEbe12OVWUyS4GS-Rl0fs'; // Replace with your actual API key

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      _selectedImage = File(pickedFile.path);
      await _extractTextFromImage(_selectedImage!);
    }
  }

  Future<void> _extractTextFromImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final textRecognizer = TextRecognizer();
    final recognizedText = await textRecognizer.processImage(inputImage);
    await textRecognizer.close();

    setState(() {
      _controller.text = recognizedText.text;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Text extracted from image. Analyzing...')),
    );

    await _analyzeDocument(recognizedText.text);
  }

  List<String> _extractBulletPoints(String text) {
    return text
        .split(RegExp(r'[\n\r]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  Future<void> _analyzeDocument(String text) async {
    setState(() {
      _loading = true;
      _goodLegal = '';
      _badLegal = '';
      _verdict = '';
      _summary = '';
    });

    final model = GenerativeModel(
      model: 'models/gemini-1.5-pro-latest',
      apiKey: _apiKey,
    );

    final prompt = '''
You are a legal language model assistant. Analyze the following Terms and Conditions document according to these criteria:

1. Clarity and Simplicity
2. User Rights
3. Limitations and Liabilities
4. Privacy and Data Use
5. Cancellation and Termination
6. Dispute Resolution
7. Transparency of Changes
8. No Abusive Clauses

Separate your analysis into:
- Good Legal: List the key parts that are beneficial and clear for users.
- Bad Legal: List problematic or unclear legal parts that could be abusive or unfair.

At the end, provide:
- Verdict: "Good Legality" or "Bad Legality"
- Summary: A clear 2-3 sentence summary of your findings.

Document:
$text
''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      final output = response.text ?? '';

      final goodStart = output.indexOf('Good Legal:');
      final badStart = output.indexOf('Bad Legal:');
      final verdictStart = output.indexOf('Verdict:');
      final summaryStart = output.indexOf('Summary:');

      setState(() {
        _goodLegal = goodStart >= 0 && badStart >= 0
            ? output.substring(goodStart + 11, badStart).trim()
            : '';
        _badLegal = badStart >= 0 && verdictStart >= 0
            ? output.substring(badStart + 10, verdictStart).trim()
            : '';
        _verdict = verdictStart >= 0 && summaryStart >= 0
            ? output.substring(verdictStart + 8, summaryStart).trim()
            : '';
        _summary = summaryStart >= 0
            ? output.substring(summaryStart + 8).trim()
            : '';
      });

      // Scroll to bottom after analysis
      await Future.delayed(Duration(milliseconds: 300));
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 600),
        curve: Curves.easeOut,
      );
    } catch (e) {
      setState(() {
        _summary = 'Error analyzing document: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Widget _buildBulletList(String label, String text) {
    final points = _extractBulletPoints(text);
    if (points.isEmpty) return SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ...points.map((point) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• ', style: TextStyle(fontSize: 16)),
            Expanded(child: Text(point)),
          ],
        )),
        SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('PaperProof Legal Analyzer')),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.all(16.0),
        child: Column(children: [
          ElevatedButton.icon(
            icon: Icon(Icons.image),
            label: Text('Upload Image'),
            onPressed: _pickImage,
          ),
          if (_selectedImage != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Image.file(_selectedImage!, height: 150),
            ),
          TextField(
            controller: _controller,
            maxLines: 10,
            decoration: InputDecoration(
              hintText: 'Paste Terms and Conditions document here...',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loading ? null : () => _analyzeDocument(_controller.text),
            child: Text('Analyze Legality'),
          ),
          SizedBox(height: 20),
          if (_loading) CircularProgressIndicator(),
          if (_goodLegal.isNotEmpty) _buildBulletList('✅ Good Legal Points:', _goodLegal),
          if (_badLegal.isNotEmpty) _buildBulletList('⚠️ Bad Legal Points:', _badLegal),
          if (_verdict.isNotEmpty)
            Text('🧑‍⚖️ Verdict: $_verdict',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.indigo)),
          if (_summary.isNotEmpty) ...[
            SizedBox(height: 10),
            Text('📋 Summary:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(_summary),
          ],
          SizedBox(height: 20),
        ]),
      ),
    );
  }
}
