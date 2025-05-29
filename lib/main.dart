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
  String _legalityScore = '';
  String _comparisonResult = '';

  bool _loading = false;
  File? _selectedImage;
  File? _secondImage;

  final String _apiKey = 'AIzaSyAVf0kDtdaaakhEbe12OVWUyS4GS-Rl0fs'; // Replace with your Gemini API Key

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
      SnackBar(content: Text('Text extracted from image. You can now analyze.')),
    );
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
      _legalityScore = '';
      _comparisonResult = '';
    });

    final model = GenerativeModel(
      model: 'models/gemini-1.5-pro-latest',
      apiKey: _apiKey,
    );

    final prompt = '''
You are a legal assistant. Analyze this Terms and Conditions document:

Criteria:
1. Clarity and Simplicity
2. User Rights
3. Limitations and Liabilities
4. Privacy and Data Use
5. Cancellation and Termination
6. Dispute Resolution
7. Transparency of Changes
8. No Abusive Clauses

Scoring Guidelines:
- Score the document on a scale of 0–100.
- Avoid giving a score of 0 unless the document is malicious or completely non-compliant.
- Use 20–40 for poorly written or legally weak documents.
- Use 41–70 for documents that meet basic standards but need improvements.
- Use 71–90 for well-structured and mostly compliant documents.
- Use 91–100 only for excellent documents with no major flaws and high transparency.

Output:
- Good Legal
- Bad Legal
- Verdict
- Summary
- Legality Score (0–100)

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
      final scoreStart = output.indexOf('Legality Score');

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
        _summary = summaryStart >= 0 && scoreStart >= 0
            ? output.substring(summaryStart + 8, scoreStart).trim()
            : '';
        _legalityScore = scoreStart >= 1
            ? RegExp(r'\d+').stringMatch(output.substring(scoreStart)) ?? ''
            : '';
      });

      await Future.delayed(Duration(milliseconds: 300));
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 600),
        curve: Curves.easeOut,
      );
    } catch (e) {
      setState(() {
        _summary = 'Error: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _pickSecondImageAndCompare() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null && _selectedImage != null) {
      _secondImage = File(pickedFile.path);

      final inputImage1 = InputImage.fromFile(_selectedImage!);
      final inputImage2 = InputImage.fromFile(_secondImage!);

      final textRecognizer = TextRecognizer();
      final text1 = await textRecognizer.processImage(inputImage1);
      final text2 = await textRecognizer.processImage(inputImage2);
      await textRecognizer.close();

      await _compareDocuments(text1.text, text2.text);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select the first image before comparing.')),
      );
    }
  }

  Future<void> _compareDocuments(String oldDoc, String newDoc) async {
    setState(() {
      _loading = true;
      _comparisonResult = '';
    });

    final model = GenerativeModel(
      model: 'models/gemini-1.5-pro-latest',
      apiKey: _apiKey,
    );

    final prompt = '''
Compare the two Terms and Conditions documents below. Identify what changed, what was added, and what was removed.

Old Document:
$oldDoc

New Document:
$newDoc

Output a bullet-point summary of the differences.
''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      setState(() {
        _comparisonResult = response.text ?? 'No response from model.';
      });
    } catch (e) {
      setState(() {
        _comparisonResult = 'Comparison error: $e';
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
      appBar: AppBar(title: Text('PaperProof Analyzer')),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              icon: Icon(Icons.image),
              label: Text('Upload First Image'),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.check_circle),
                  label: Text('Analyze Legality'),
                  onPressed: _loading ? null : () => _analyzeDocument(_controller.text),
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.compare),
                  label: Text('Compare Documents'),
                  onPressed: _loading ? null : _pickSecondImageAndCompare,
                ),
              ],
            ),
            SizedBox(height: 20),
            if (_loading) CircularProgressIndicator(),
            if (_goodLegal.isNotEmpty) _buildBulletList('✅ Good Legal Points:', _goodLegal),
            if (_badLegal.isNotEmpty) _buildBulletList('⚠️ Bad Legal Points:', _badLegal),
            if (_verdict.isNotEmpty)
              Text('🧑‍⚖️ Verdict: $_verdict',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.indigo)),
            if (_legalityScore.isNotEmpty)
              Text('⚖️ Legality Score: $_legalityScore / 100',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
            if (_summary.isNotEmpty) ...[
              SizedBox(height: 10),
              Text('📋 Summary:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(_summary),
            ],
            if (_comparisonResult.isNotEmpty) ...[
              Divider(thickness: 2),
              Text('📄 Document Comparison', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(_comparisonResult),
            ],
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
