import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'; // Add this
import 'package:read_pdf_text/read_pdf_text.dart'; // Add this
import '../utils/deidentifier.dart';
import 'loading_screen.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  List<PlatformFile> selectedFiles = [];
  bool isExtracting = false; // To show a loader while OCR runs
  
  Future<void> pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png','txt'],
    );

    if (result != null) {
      setState(() {
        selectedFiles = result.files;
      });
    }
  }

  // ✅ NEW FUNCTION: Actually reads the files
  Future<String> extractTextFromFiles() async {
    String combinedText = "";
    final textRecognizer = TextRecognizer();

    try {
      for (var file in selectedFiles) {
        if (file.path == null) continue;

        final ext = (file.extension ?? "").toLowerCase();

        if (ext == 'txt') {
          try {
            final txt = await File(file.path!).readAsString(encoding: utf8);
            combinedText += "$txt\n\n";
          } catch (e) {
            debugPrint("Error reading TXT: $e");
          }
        } else if (ext == 'pdf') {
          // Extract PDF text
          try {
            String pdfText = await ReadPdfText.getPDFtext(file.path!);
            combinedText += "$pdfText\n\n";
          } catch (e) {
            debugPrint("Error reading PDF: $e");
          }
        } else {
          // Extract Image text (OCR)
          try {
            final inputImage = InputImage.fromFilePath(file.path!);
            final recognizedText = await textRecognizer.processImage(inputImage);
            combinedText += "${recognizedText.text}\n\n";
          } catch (e) {
            debugPrint("Error running OCR: $e");
          }
        }
      }
    } finally {
      textRecognizer.close();
    }

    return combinedText;
  }

  void clearFiles() {
    setState(() {
      selectedFiles.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Upload Discharge Summary"),
        actions: [
          if (selectedFiles.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: clearFiles,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // ... (Your existing UI code for the Card and List) ...
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: pickFiles,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: const [
                      Icon(Icons.upload_file, size: 48, color: Colors.teal),
                      SizedBox(height: 12),
                      Text(
                        "Tap to upload PDF or Images",
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // File List Preview
            if (selectedFiles.isNotEmpty)
              Expanded(
                child: Card(
                  child: ListView.builder(
                    itemCount: selectedFiles.length,
                    itemBuilder: (context, index) {
                      final file = selectedFiles[index];
                      return ListTile(
                        title: Text(file.name),
                        leading: Icon(
                          file.extension == 'pdf'
                              ? Icons.picture_as_pdf
                              : Icons.image,
                        ),
                      );
                    },
                  ),
                ),
              ),

            if (selectedFiles.isNotEmpty) const SizedBox(height: 16),

            // BUTTONS
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: selectedFiles.isEmpty ? null : clearFiles,
                    child: const Text("Clear"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    // ✅ UPDATED ONPRESSED LOGIC
                    onPressed: (selectedFiles.isEmpty || isExtracting)
                        ? null
                        : () async {
                            setState(() => isExtracting = true);

                            String rawText = "";
                            try {
                              // 1. Actually extract text
                              rawText = await extractTextFromFiles();
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Failed to extract text: $e")),
                                );
                              }
                              return;
                            } finally {
                              if (mounted) setState(() => isExtracting = false);
                            }

                            if (rawText.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("No text found in file!"),
                                ),
                              );
                              return;
                            }

                            // 2. De-identify
                            final cleanedText = DeIdentifier.redact(rawText);

                            // 3. Navigate
                            if (mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LoadingScreen(
                                    deidentifiedText: cleanedText,
                                  ),
                                ),
                              );
                            }
                          },
                    child: isExtracting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text("Continue"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
