import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/notebook_model.dart';
import '../models/template_model.dart';

class NotebookStorageService {
  static final NotebookStorageService instance = NotebookStorageService._internal();
  NotebookStorageService._internal();

  static const String _fileName = 'notebooks_data.json';
  static const String _templatesFileName = 'custom_templates_data.json';
  List<NotebookModel>? _cachedNotebooks;
  List<JournalTemplate>? _cachedCustomTemplates;

  Future<File> _getLocalFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<File> _getTemplatesFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_templatesFileName');
  }

  Future<List<NotebookModel>> loadNotebooks() async {
    if (_cachedNotebooks != null) {
      return _cachedNotebooks!;
    }

    try {
      final file = await _getLocalFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content) as List;
          final List<NotebookModel> loaded = [];
          for (final item in decoded) {
            try {
              loaded.add(NotebookModel.fromJson(item as Map<String, dynamic>));
            } catch (e) {
              debugPrint('Error parsing notebook item: $e');
            }
          }
          if (loaded.isNotEmpty) {
            _cachedNotebooks = loaded;
            return loaded;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading notebooks from storage: $e');
    }

    // Default to sample notebooks on first run
    _cachedNotebooks = List.from(NotebookModel.sampleNotebooks);
    await saveNotebooks(_cachedNotebooks!);
    return _cachedNotebooks!;
  }

  Future<void> saveNotebooks(List<NotebookModel> notebooks) async {
    _cachedNotebooks = List.from(notebooks);
    try {
      final file = await _getLocalFile();
      final jsonList = notebooks.map((n) => n.toJson()).toList();
      final content = jsonEncode(jsonList);
      await file.writeAsString(content);
    } catch (e) {
      debugPrint('Error saving notebooks to storage: $e');
    }
  }

  Future<void> saveOrUpdateNotebook(NotebookModel notebook) async {
    final list = await loadNotebooks();
    final index = list.indexWhere((n) => n.id == notebook.id);
    if (index >= 0) {
      list[index] = notebook;
    } else {
      list.insert(0, notebook);
    }
    await saveNotebooks(list);
  }

  Future<void> deleteNotebook(String notebookId) async {
    final list = await loadNotebooks();
    list.removeWhere((n) => n.id == notebookId);
    await saveNotebooks(list);
  }

  /// Custom Templates Persistence
  Future<List<JournalTemplate>> loadCustomTemplates() async {
    if (_cachedCustomTemplates != null) {
      return _cachedCustomTemplates!;
    }

    try {
      final file = await _getTemplatesFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content) as List;
          final List<JournalTemplate> loaded = [];
          for (final item in decoded) {
            try {
              loaded.add(JournalTemplate.fromJson(item as Map<String, dynamic>));
            } catch (e) {
              debugPrint('Error parsing custom template item: $e');
            }
          }
          _cachedCustomTemplates = loaded;
          return loaded;
        }
      }
    } catch (e) {
      debugPrint('Error loading custom templates: $e');
    }

    _cachedCustomTemplates = [];
    return _cachedCustomTemplates!;
  }

  Future<void> saveCustomTemplates(List<JournalTemplate> templates) async {
    _cachedCustomTemplates = List.from(templates);
    try {
      final file = await _getTemplatesFile();
      final jsonList = templates.map((t) => t.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving custom templates: $e');
    }
  }

  Future<void> saveOrUpdateCustomTemplate(JournalTemplate template) async {
    final list = await loadCustomTemplates();
    final index = list.indexWhere((t) => t.id == template.id);
    if (index >= 0) {
      list[index] = template;
    } else {
      list.insert(0, template);
    }
    await saveCustomTemplates(list);
  }
}
