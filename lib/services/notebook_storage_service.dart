import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notebook_model.dart';
import '../models/template_model.dart';

class NotebookStorageService {
  static final NotebookStorageService instance = NotebookStorageService._internal();
  NotebookStorageService._internal();

  static const String _fileName = 'notebooks_data.json';
  static const String _templatesFileName = 'custom_templates_data.json';
  static const String _prefsNotebooksKey = 'saved_notebooks_data';
  static const String _prefsTemplatesKey = 'saved_custom_templates_data';

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

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final content = prefs.getString(_prefsNotebooksKey);
        if (content != null && content.trim().isNotEmpty) {
          final decoded = jsonDecode(content) as List;
          final List<NotebookModel> loaded = [];
          for (final item in decoded) {
            try {
              loaded.add(NotebookModel.fromJson(item as Map<String, dynamic>));
            } catch (e) {
              debugPrint('Error parsing notebook item from prefs: $e');
            }
          }
          if (loaded.isNotEmpty) {
            _cachedNotebooks = loaded;
            return loaded;
          }
        }
      } catch (e) {
        debugPrint('Error loading notebooks from SharedPreferences: $e');
      }

      // Default to sample notebooks on first run on web
      _cachedNotebooks = List.from(NotebookModel.sampleNotebooks);
      await saveNotebooks(_cachedNotebooks!);
      return _cachedNotebooks!;
    }

    // Native file storage
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

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final jsonList = notebooks.map((n) => n.toJson()).toList();
        await prefs.setString(_prefsNotebooksKey, jsonEncode(jsonList));
      } catch (e) {
        debugPrint('Error saving notebooks to SharedPreferences: $e');
      }
      return;
    }

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
      JournalTemplate.registerTemplates(_cachedCustomTemplates!);
      return _cachedCustomTemplates!;
    }

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final content = prefs.getString(_prefsTemplatesKey);
        if (content != null && content.trim().isNotEmpty) {
          final decoded = jsonDecode(content) as List;
          final List<JournalTemplate> loaded = [];
          for (final item in decoded) {
            try {
              loaded.add(JournalTemplate.fromJson(item as Map<String, dynamic>));
            } catch (e) {
              debugPrint('Error parsing custom template item from prefs: $e');
            }
          }
          _cachedCustomTemplates = loaded;
          JournalTemplate.registerTemplates(loaded);
          return loaded;
        }
      } catch (e) {
        debugPrint('Error loading custom templates from SharedPreferences: $e');
      }

      _cachedCustomTemplates = [];
      return _cachedCustomTemplates!;
    }

    // Native file storage
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
          JournalTemplate.registerTemplates(loaded);
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
    JournalTemplate.registerTemplates(templates);

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final jsonList = templates.map((t) => t.toJson()).toList();
        await prefs.setString(_prefsTemplatesKey, jsonEncode(jsonList));
      } catch (e) {
        debugPrint('Error saving custom templates to SharedPreferences: $e');
      }
      return;
    }

    try {
      final file = await _getTemplatesFile();
      final jsonList = templates.map((t) => t.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving custom templates: $e');
    }
  }

  Future<void> saveOrUpdateCustomTemplate(JournalTemplate template) async {
    JournalTemplate.registerTemplate(template);
    final list = await loadCustomTemplates();
    final index = list.indexWhere((t) => t.id == template.id);
    if (index >= 0) {
      list[index] = template;
    } else {
      list.insert(0, template);
    }
    await saveCustomTemplates(list);
  }

  Future<void> deleteCustomTemplate(String templateId) async {
    final list = await loadCustomTemplates();
    list.removeWhere((t) => t.id == templateId);
    await saveCustomTemplates(list);
  }
}
