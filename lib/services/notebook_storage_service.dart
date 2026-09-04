import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notebook_model.dart';
import '../models/template_model.dart';
import 'app_logger.dart';
import 'file_storage_helper.dart';

class NotebookLoadResult {
  final List<NotebookModel> notebooks;
  final int failedCount;
  final bool isFromBackup;

  const NotebookLoadResult({
    required this.notebooks,
    this.failedCount = 0,
    this.isFromBackup = false,
  });
}

class NotebookStorageService {
  static final NotebookStorageService instance = NotebookStorageService._internal();
  NotebookStorageService._internal();

  static const String _fileName = 'notebooks_data.json';
  static const String _templatesFileName = 'custom_templates_data.json';
  static const String _prefsNotebooksKey = 'saved_notebooks_data';
  static const String _prefsTemplatesKey = 'saved_custom_templates_data';
  static const String _prefsSeededKey = 'has_seeded_initial_notebooks_v1';

  List<NotebookModel>? _cachedNotebooks;
  List<JournalTemplate>? _cachedCustomTemplates;
  int _lastFailedCount = 0;

  int get lastFailedCount => _lastFailedCount;

  void resetForTesting() {
    _cachedNotebooks = null;
    _cachedCustomTemplates = null;
    _lastFailedCount = 0;
  }

  Future<List<NotebookModel>> loadNotebooks() async {
    if (_cachedNotebooks != null) {
      return _cachedNotebooks!;
    }

    final prefs = await SharedPreferences.getInstance();
    final bool isAlreadySeeded = prefs.getBool(_prefsSeededKey) ?? false;

    if (kIsWeb) {
      try {
        final content = prefs.getString(_prefsNotebooksKey);
        if (content != null) {
          if (content.trim().isEmpty) {
            _cachedNotebooks = [];
            return [];
          }
          final decoded = jsonDecode(content) as List;
          final List<NotebookModel> loaded = [];
          int failed = 0;
          for (final item in decoded) {
            try {
              loaded.add(NotebookModel.fromJson(item as Map<String, dynamic>));
            } catch (e, st) {
              failed++;
              AppLog.e('NotebookStorage', 'Error parsing web notebook: $e', st);
            }
          }
          _lastFailedCount = failed;
          _cachedNotebooks = loaded;
          return loaded;
        }
      } catch (e, st) {
        AppLog.e('NotebookStorage', 'Error loading notebooks from SharedPreferences', st);
      }

      // First run on Web: seed if not already seeded
      if (!isAlreadySeeded) {
        _cachedNotebooks = List.from(NotebookModel.sampleNotebooks);
        await prefs.setBool(_prefsSeededKey, true);
        await saveNotebooks(_cachedNotebooks!);
        return _cachedNotebooks!;
      }

      _cachedNotebooks = [];
      return [];
    }

    // Native file storage via atomic readLocalFile
    try {
      final content = await readLocalFile(_fileName);
      if (content != null) {
        if (content.trim().isEmpty) {
          _cachedNotebooks = [];
          return [];
        }
        final decoded = jsonDecode(content) as List;
        final List<NotebookModel> loaded = [];
        int failed = 0;
        for (final item in decoded) {
          try {
            loaded.add(NotebookModel.fromJson(item as Map<String, dynamic>));
          } catch (e, st) {
            failed++;
            AppLog.e('NotebookStorage', 'Corrupt notebook item: $e', st);
          }
        }

        _lastFailedCount = failed;
        if (failed > 0) {
          // Backup corrupt data so user files can be rescued
          await backupCorruptFile(_fileName, content);
          AppLog.w('NotebookStorage', '$failed notebooks failed to parse; backed up corrupt content');
        }

        _cachedNotebooks = loaded;
        return loaded;
      }
    } catch (e, st) {
      AppLog.e('NotebookStorage', 'Error reading notebooks file', st);
    }

    // First run on Native: seed if not seeded before
    if (!isAlreadySeeded) {
      _cachedNotebooks = List.from(NotebookModel.sampleNotebooks);
      await prefs.setBool(_prefsSeededKey, true);
      await saveNotebooks(_cachedNotebooks!);
      return _cachedNotebooks!;
    }

    _cachedNotebooks = [];
    return [];
  }

  Future<bool> saveNotebooks(List<NotebookModel> notebooks) async {
    _cachedNotebooks = List.from(notebooks);

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final jsonList = notebooks.map((n) => n.toJson()).toList();
        await prefs.setString(_prefsNotebooksKey, jsonEncode(jsonList));
        return true;
      } catch (e, st) {
        AppLog.e('NotebookStorage', 'Error saving notebooks to SharedPreferences', st);
        return false;
      }
    }

    try {
      final jsonList = notebooks.map((n) => n.toJson()).toList();
      final content = jsonEncode(jsonList);
      final success = await writeLocalFile(_fileName, content);
      return success;
    } catch (e, st) {
      AppLog.e('NotebookStorage', 'Error saving notebooks to local storage', st);
      return false;
    }
  }

  Future<bool> saveOrUpdateNotebook(NotebookModel notebook) async {
    final list = await loadNotebooks();
    final index = list.indexWhere((n) => n.id == notebook.id);
    if (index >= 0) {
      list[index] = notebook;
    } else {
      list.insert(0, notebook);
    }
    return await saveNotebooks(list);
  }

  Future<bool> deleteNotebook(String notebookId) async {
    final list = await loadNotebooks();
    list.removeWhere((n) => n.id == notebookId);
    return await saveNotebooks(list);
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
            } catch (e, st) {
              AppLog.e('NotebookStorage', 'Error parsing custom template: $e', st);
            }
          }
          _cachedCustomTemplates = loaded;
          JournalTemplate.registerTemplates(loaded);
          return loaded;
        }
      } catch (e, st) {
        AppLog.e('NotebookStorage', 'Error loading templates from SharedPreferences', st);
      }

      _cachedCustomTemplates = [];
      return _cachedCustomTemplates!;
    }

    // Native file storage via readLocalFile
    try {
      final content = await readLocalFile(_templatesFileName);
      if (content != null && content.trim().isNotEmpty) {
        final decoded = jsonDecode(content) as List;
        final List<JournalTemplate> loaded = [];
        for (final item in decoded) {
          try {
            loaded.add(JournalTemplate.fromJson(item as Map<String, dynamic>));
          } catch (e, st) {
            AppLog.e('NotebookStorage', 'Error parsing custom template: $e', st);
          }
        }
        _cachedCustomTemplates = loaded;
        JournalTemplate.registerTemplates(loaded);
        return loaded;
      }
    } catch (e, st) {
      AppLog.e('NotebookStorage', 'Error loading custom templates', st);
    }

    _cachedCustomTemplates = [];
    return _cachedCustomTemplates!;
  }

  Future<bool> saveCustomTemplates(List<JournalTemplate> templates) async {
    _cachedCustomTemplates = List.from(templates);
    JournalTemplate.registerTemplates(templates);

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final jsonList = templates.map((t) => t.toJson()).toList();
        await prefs.setString(_prefsTemplatesKey, jsonEncode(jsonList));
        return true;
      } catch (e, st) {
        AppLog.e('NotebookStorage', 'Error saving custom templates', st);
        return false;
      }
    }

    try {
      final jsonList = templates.map((t) => t.toJson()).toList();
      return await writeLocalFile(_templatesFileName, jsonEncode(jsonList));
    } catch (e, st) {
      AppLog.e('NotebookStorage', 'Error saving custom templates', st);
      return false;
    }
  }

  Future<bool> saveOrUpdateCustomTemplate(JournalTemplate template) async {
    JournalTemplate.registerTemplate(template);
    final list = await loadCustomTemplates();
    final index = list.indexWhere((t) => t.id == template.id);
    if (index >= 0) {
      list[index] = template;
    } else {
      list.insert(0, template);
    }
    return await saveCustomTemplates(list);
  }

  Future<bool> deleteCustomTemplate(String templateId) async {
    final list = await loadCustomTemplates();
    list.removeWhere((t) => t.id == templateId);
    return await saveCustomTemplates(list);
  }
}
