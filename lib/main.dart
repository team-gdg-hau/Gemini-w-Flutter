import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:io';
import 'dart:convert'; // For jsonDecode
import 'package:flutter/services.dart'; // For rootBundle

void main() => runApp(LegalDocAnalyzerApp());

class LegalDocAnalyzerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paperproof Doc Analyzer',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.grey[100],
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      home: LegalDocAnalyzerScreen(),
    );
  }
}

class LegalDocAnalyzerScreen extends StatefulWidget {
  @override
  _LegalDocAnalyzerScreenState createState() => _LegalDocAnalyzerScreenState();
}

class _LegalDocAnalyzerScreenState extends State<LegalDocAnalyzerScreen>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _goodLegal = '';
  String _badLegal = '';
  String _verdict = '';
  String _summary = '';
  String _legalityScore = '';
  String _comparisonResult = '';

  Map<String, int> _criteriaScores = {};

  bool _loading = false;
  File? _selectedImage;
  File? _secondImage;
  List<Widget> _legalJargonWidgets = [];

  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  final String _apiKey = 'AIzaSyAVf0kDtdaaakhEbe12OVWUyS4GS-Rl0fs'; // Replace with your Gemini API Key
  Future<Map<String, Map<String, String>>> _loadLegalTerms() async {
    final jsonString = await rootBundle.loadString('lib/legal-jargon.json');
    final List<dynamic> jsonList = jsonDecode(jsonString);

    Map<String, Map<String, String>> termMap = {};
    for (var item in jsonList) {
      final term = item['term']?.toLowerCase();
      if (term != null) {
        termMap[term] = {
          'translation': item['literal_translation'] ?? '',
          'definition': item['definition'] ?? '',
        };
      }
    }
    return termMap;
  }

  Future<List<Widget>> _highlightLegalTerms(String docText) async {
    final Map<String, Map<String, String>> legalTerms = await _loadLegalTerms();
    List<Widget> foundTerms = [];

    legalTerms.forEach((term, data) {
      if (docText.toLowerCase().contains(term)) {
        foundTerms.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Card(
              color: Colors.yellow[100],
              child: ListTile(
                title: Text(term, style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  '${data['translation']}\n\n${data['definition']}',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ),
          ),
        );
      }
    });

    return foundTerms;
  }
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    );
    _progressAnimation =
        Tween<double>(begin: 0, end: 1).animate(_animationController);
  }

  @override
  void dispose() {
    _controller.dispose();
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile =
    await ImagePicker().pickImage(source: ImageSource.gallery);
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
      _criteriaScores = {};
    });

    _animationController.reset();

    final model = GenerativeModel(
      model: 'models/gemini-1.5-pro-latest',
      apiKey: _apiKey,
    );

    final prompt = '''
You are a legal assistant. Analyze this Terms and Conditions, rental agreements, loan forms, employment contracts, etc. document:

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
- Choose 10, 20, 30, 40, 50, 60, 70, 80, 90, 100 in closest 10's for Legality Score.

Output each criterion score in this format exactly:
Clarity and Simplicity: [score]
User Rights: [score]
Limitations and Liabilities: [score]
Privacy and Data Use: [score]
Cancellation and Termination: [score]
Dispute Resolution: [score]
Transparency of Changes: [score]
No Abusive Clauses: [score]

Output:
- Good Points 15 words each findings 
- Bad Points 15 words each findings 
- Verdict
- Summary
- Legality Score (0–100)

Document:
$text
''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      final output = response.text ?? '';

      final goodStart = output.indexOf('Good Points:');
      final badStart = output.indexOf('Bad Points:');
      final verdictStart = output.indexOf('Verdict:');
      final summaryStart = output.indexOf('Summary:');
      final scoreStart = output.indexOf('Legality Score');

      // Extract criteria scores
      final scoreRegex = RegExp(r'([A-Za-z\s]+):\s*(\d{1,3})');
      final scoreMatches = scoreRegex.allMatches(output);
      Map<String, int> criteriaScores = {};
      for (final match in scoreMatches) {
        final label = match.group(1)?.trim();
        final value = int.tryParse(match.group(2)!);
        if (label != null &&
            value != null &&
            label != 'Legality Score' &&
            label != 'Good Points' &&
            label != 'Bad Points' &&
            label != 'Verdict' &&
            label != 'Summary') {
          criteriaScores[label] = value;
        }
      }

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
        _legalityScore = scoreStart >= 0
            ? RegExp(r'\d+').stringMatch(output.substring(scoreStart)) ?? ''
            : '';
        _criteriaScores = criteriaScores;

      });
      _legalJargonWidgets = await _highlightLegalTerms(text);
      _animationController.forward();

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
    final pickedFile =
    await ImagePicker().pickImage(source: ImageSource.gallery);
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

  Widget _buildBulletText(String title, String content, {required bool isDanger}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.indigo,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDanger ? Colors.red.shade900 : Colors.green.shade900,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isDanger ? Icons.block : Icons.thumb_up_alt,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  content,
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }




  Widget _buildScoreCard(String title, int score) {
    Color getColor(int s) {
      if (s >= 90) return Colors.green.shade700;
      if (s >= 70) return Colors.lightGreen.shade600;
      if (s >= 50) return Colors.orange.shade700;
      return Colors.red.shade400;
    }

    return Card(
      elevation: 3,
      margin: EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(title,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ),
            AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) {
                final animatedScore =
                (_progressAnimation.value * score).clamp(0, score).toInt();
                return Row(
                  children: [
                    Container(
                      width: 150,
                      height: 20,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.grey.shade300,
                      ),
                      child: Stack(
                        children: [
                          FractionallySizedBox(
                            widthFactor: animatedScore / 100,
                            child: Container(
                              decoration: BoxDecoration(
                                color: getColor(score),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      '$animatedScore%',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: getColor(score),
                          fontSize: 16),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final criteriaWidgets = _criteriaScores.entries
        .map((e) => _buildScoreCard(e.key, e.value))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Paperproof Analyzer'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              maxLines: 12,
              decoration: InputDecoration(
                hintText: 'Paste Terms & Conditions here or pick an image',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.photo_library),
                  label: Text('Pick Image'),
                  onPressed: _loading ? null : _pickImage,
                ),
                SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: Icon(Icons.analytics),
                  label: Text('Analyze Document'),
                  onPressed: _loading || _controller.text.trim().isEmpty
                      ? null
                      : () => _analyzeDocument(_controller.text.trim()),
                ),
              ],
            ),
            SizedBox(height: 24),
            if (_loading) ...[
              CircularProgressIndicator(),
              SizedBox(height: 16),
            ],
            if (_legalJargonWidgets.isNotEmpty) ...[
              SizedBox(height: 16),
              Text('Legal Jargon Explained:',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
              SizedBox(height: 8),
              ..._legalJargonWidgets,
            ],

            if (_goodLegal.isNotEmpty) ...[
              _buildBulletText('Good Points:', _goodLegal, isDanger: false),
              Text('Good Points:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.indigo)),
              SizedBox(height: 4),
              Text(_verdict, style: TextStyle(fontSize: 16)),
              SizedBox(height: 16),
            ],
            if (_badLegal.isNotEmpty) ...[
              _buildBulletText('Bad Points:', _badLegal, isDanger: true),
              Text('Bad Points:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.indigo)),
              SizedBox(height: 4),
              Text(_verdict, style: TextStyle(fontSize: 16)),
              SizedBox(height: 16),
            ],
            if (_verdict.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Verdict:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.indigo)),
                  SizedBox(height: 4),
                  Text(_verdict, style: TextStyle(fontSize: 16)),
                  SizedBox(height: 16),
                ],
              ),

            if (_summary.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Summary:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.indigo)),
                  SizedBox(height: 4),
                  Text(_summary, style: TextStyle(fontSize: 16)),
                  SizedBox(height: 16),
                ],
              ),
            if (_legalityScore.isNotEmpty)
              Card(
                color: Colors.indigo.shade50,
                child: Padding(
                  padding:
                  EdgeInsets.symmetric(vertical: 14.0, horizontal: 20.0),
                  child: Text(
                    'Legality Score: $_legalityScore / 100',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade900),
                  ),
                ),
              ),
            SizedBox(height: 12),
            ...criteriaWidgets,
            SizedBox(height: 24),
            Divider(height: 2, color: Colors.indigo.shade200),
            SizedBox(height: 16),
            Text(
              'Compare Terms and Conditions',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.indigo.shade900,
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.photo_library_outlined),
                  label: Text('Pick Second Image'),
                  onPressed: _loading ? null : _pickSecondImageAndCompare,
                ),
              ],
            ),
            SizedBox(height: 16),
            if (_loading)
              CircularProgressIndicator(),
            if (_comparisonResult.isNotEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _comparisonResult,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}