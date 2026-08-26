import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const ArtisanApp());
}

class ArtisanApp extends StatelessWidget {
  const ArtisanApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Artisan Cataloger',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
        useMaterial3: true,
      ),
      home: const ArtisanCatalogScreen(),
    );
  }
}

class ArtisanCatalogScreen extends StatefulWidget {
  const ArtisanCatalogScreen({Key? key}) : super(key: key);

  @override
  State<ArtisanCatalogScreen> createState() => _ArtisanCatalogScreenState();
}

class _ArtisanCatalogScreenState extends State<ArtisanCatalogScreen> {
  File? _selectedImage;
  bool _isLoading = false;
  Map<String, dynamic>? _generatedCatalog;

  final TextEditingController _materialCostController = TextEditingController();
  final TextEditingController _laborHoursController = TextEditingController();
  final TextEditingController _voiceNotesController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final XFile? photo = await _picker.pickImage(source: source, imageQuality: 85);
    if (photo != null) {
      setState(() {
        _selectedImage = File(photo.path);
      });
    }
  }

  Future<void> _processCatalog() async {
    if (_selectedImage == null ||
        _materialCostController.text.isEmpty ||
        _laborHoursController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload an image, enter costs, and input labor hours.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://10.0.2.2:8000/api/catalog/auto-generate'),
      );

      request.files.add(
        await http.MultipartFile.fromPath('image', _selectedImage!.path),
      );
      request.fields['material_cost'] = _materialCostController.text;
      request.fields['hours_worked'] = _laborHoursController.text;
      request.fields['raw_audio_notes'] = _voiceNotesController.text;

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        setState(() {
          _generatedCatalog = decoded['data'];
        });
      } else {
        throw Exception(jsonDecode(response.body)['detail'] ?? 'Failed to generate catalog');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Artisan Cataloger'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: _showImageSourceDialog,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.deepOrange.shade200),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_selectedImage!, fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.camera_alt, size: 48, color: Colors.deepOrange),
                          SizedBox(height: 8),
                          Text('Tap to Capture Craft Photo', style: TextStyle(color: Colors.black54)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _materialCostController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Material Cost (₹)',
                prefixIcon: Icon(Icons.currency_rupee),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _laborHoursController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Hours Spent Making Item',
                prefixIcon: Icon(Icons.timer),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _voiceNotesController,
              decoration: const InputDecoration(
                labelText: 'Story / Voice Notes (Optional)',
                prefixIcon: Icon(Icons.mic),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _processCatalog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Auto-Generate Catalog & Fair Price',
                      style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
            const SizedBox(height: 24),
            if (_generatedCatalog != null) ...[
              const Text('Generated Catalog Result',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _generatedCatalog!['title'] ?? '',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Craft: ${_generatedCatalog!['craft_type']} | Category: ${_generatedCatalog!['category']}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const Divider(),
                      const Text('Recommended Fair Price:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        '₹${_generatedCatalog!['recommended_price_inr']}',
                        style: const TextStyle(fontSize: 24, color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text('Product Story:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(_generatedCatalog!['story'] ?? ''),
                    ],
                  ),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }
}
