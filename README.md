# paperproof

A new Flutter project.

## Getting Started

📄 Legal Document Analyzer - Prompting Guide & Verdict Scoring 💼⚖️

────────────────────────────────────────────
🧠 Prompting Questions Sent to Gemini Model
────────────────────────────────────────────

📌 For Document Analysis:

"""
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
[text from image or user input]
"""

📌 For Document Comparison:

"""
Compare the two Terms and Conditions documents below. Identify what changed, what was added, and what was removed.

Old Document:
[oldDoc]

New Document:
[newDoc]

Output a bullet-point summary of the differences.
"""

────────────────────────────────────────────
🎯 Verdict Scoring Interpretation
────────────────────────────────────────────

🔢 Legality Score Ranges:

🟥 0–19   → 🚫 Malicious or completely non-compliant (⚠️ Avoid unless justified)
🟧 20–40 → 😕 Poor quality, unclear, or legally weak
🟨 41–70 → 😐 Average quality, some issues, needs improvements
🟩 71–90 → 🙂 Strong quality, meets most legal standards
🟦 91–100 → 💯 Excellent, transparent, and fully compliant

────────────────────────────────────────────
✅ Prompt Output Structure Expected
────────────────────────────────────────────

1. ✅ Good Legal Points:
    - Bullet-point list of clauses that are fair and legally sound.

2. ⚠️ Bad Legal Points:
    - Bullet-point list of clauses that may raise concerns.

3. 🧑‍⚖️ Verdict:
    - Summary opinion on document legality.

4. 📋 Summary:
    - Overall context and explanation of analysis.

5. ⚖️ Legality Score:
    - A number from 0 to 100 (following the scoring interpretation above).

────────────────────────────────────────────

🎉 End of Prompting Guide for LegalDocAnalyzer

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


Design Prompting: Arron Kian Parejas