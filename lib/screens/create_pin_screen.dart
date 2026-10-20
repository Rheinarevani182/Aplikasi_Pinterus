import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/pin_model.dart';
import '../services/api_service.dart';

class CreatePinScreen extends StatefulWidget {
  const CreatePinScreen({
    required this.apiService,
    required this.onCreated,
    super.key,
  });

  final ApiService apiService;
  final ValueChanged<PinModel> onCreated;

  @override
  State<CreatePinScreen> createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends State<CreatePinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _linkController = TextEditingController();
  final _imagePicker = ImagePicker();
  String _category = pinCategories.first;
  XFile? _image;
  Uint8List? _imageBytes;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _chooseImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1600,
    );
    if (image == null) {
      return;
    }

    final bytes = await image.readAsBytes();
    if (!mounted) {
      return;
    }
    setState(() {
      _image = image;
      _imageBytes = bytes;
      _errorMessage = null;
    });
  }

  String? _validateLink(String? value) {
    final link = value?.trim() ?? '';
    if (link.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(link);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return 'Masukkan tautan yang diawali http:// atau https://.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_image == null) {
      setState(() {
        _errorMessage = 'Pilih gambar untuk pin ini.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final pin = await widget.apiService.createPin(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        linkUrl: _linkController.text.trim(),
        imageFile: _image!,
        category: _category,
      );
      widget.onCreated(pin);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on ApiException catch (error) {
      setState(() {
        _errorMessage = error.message;
      });
    } on Exception catch (error) {
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageBytes = _imageBytes;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Buat Pin',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: _isSubmitting ? null : _chooseImage,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: 210,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: imageBytes == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, size: 42),
                            SizedBox(height: 8),
                            Text('Pilih gambar dari perangkat'),
                          ],
                        )
                      : Image.memory(imageBytes, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Judul',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value?.trim().length ?? 0) < 3
                    ? 'Judul minimal 3 karakter.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: [
                  for (final category in pinCategories)
                    DropdownMenuItem(value: category, child: Text(category)),
                ],
                onChanged: _isSubmitting
                    ? null
                    : (category) {
                        if (category != null) {
                          setState(() {
                            _category = category;
                          });
                        }
                      },
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _linkController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Tautan tujuan (opsional)',
                  hintText: 'https://...',
                  prefixIcon: Icon(Icons.open_in_new),
                  border: OutlineInputBorder(),
                ),
                validator: _validateLink,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.publish_outlined),
                label: Text(_isSubmitting ? 'Mengunggah...' : 'Terbitkan Pin'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
