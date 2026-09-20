import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/project_model.dart';
import 'license_service.dart';

class ProjectStorageService {
  static const String _keyProjects = "clipshield_projects_v2";
  static const String _keyGroqKey = "clipshield_groq_api_key";
  static const String _keyCerebrasKey = "clipshield_cerebras_api_key";
  static const String _keyGeminiKey = "clipshield_gemini_api_key";
  static const String _keyOpenRouterKey = "clipshield_openrouter_api_key";
  static const String _keySelectedProvider = "clipshield_selected_ai_provider";
  static const String _keyLicenseStatus = "clipshield_license_status";
  static const String _keyExportQuality = "clipshield_export_quality";
  static const String _keyTotalShorts = "clipshield_total_shorts_count";
  static const String _keyTotalHoursSaved = "clipshield_total_hours_saved";
  static const String _keyCountedProjects = "clipshield_counted_projects";
  static const String _keyBackgroundRendering = "clipshield_background_rendering_enabled";

  /// Bumped on every write so any screen showing projects can rebuild without
  /// needing a manual refresh. Storage is the single source of truth; this is
  /// just the change signal.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static Future<List<ProjectItem>> loadProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyProjects);
    if (jsonStr == null || jsonStr.isEmpty) {
      return _getDefaultProjects();
    }
    try {
      final List<dynamic> list = json.decode(jsonStr);
      return list.map((x) => ProjectItem.fromMap(x as Map<String, dynamic>)).toList();
    } catch (_) {
      return _getDefaultProjects();
    }
  }

  static Future<void> saveProject(ProjectItem project) async {
    final prefs = await SharedPreferences.getInstance();
    final projects = await loadProjects();
    final index = projects.indexWhere((p) => p.id == project.id);
    if (index >= 0) {
      projects[index] = project;
    } else {
      projects.insert(0, project);
    }
    final jsonStr = json.encode(projects.map((x) => x.toMap()).toList());
    await prefs.setString(_keyProjects, jsonStr);

    // Lifetime stats count each completed project exactly once, and only count
    // clips that actually produced an artifact.
    if (project.isReady) {
      final counted = prefs.getStringList(_keyCountedProjects) ?? <String>[];
      if (!counted.contains(project.id)) {
        counted.add(project.id);
        await prefs.setStringList(_keyCountedProjects, counted);
        final produced = project.renderedClipsCount;
        final shortsCount = prefs.getInt(_keyTotalShorts) ?? 0;
        await prefs.setInt(_keyTotalShorts, shortsCount + produced);
        final hours = prefs.getDouble(_keyTotalHoursSaved) ?? 0.0;
        await prefs.setDouble(_keyTotalHoursSaved, hours + (produced * 0.5));
      }
    }

    revision.value++;
  }

  static Future<ProjectItem?> getProject(String id) async {
    final projects = await loadProjects();
    for (final p in projects) {
      if (p.id == id) return p;
    }
    return null;
  }

  static Future<void> deleteProject(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final projects = await loadProjects();
    projects.removeWhere((p) => p.id == id);
    final jsonStr = json.encode(projects.map((x) => x.toMap()).toList());
    await prefs.setString(_keyProjects, jsonStr);
    revision.value++;
  }

  static Future<String?> getGroqApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyGroqKey);
  }

  static Future<void> setGroqApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGroqKey, key);
  }

  static Future<String?> getCerebrasApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCerebrasKey);
  }

  static Future<void> setCerebrasApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCerebrasKey, key);
  }

  static Future<String?> getGeminiApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyGeminiKey);
  }

  static Future<void> setGeminiApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGeminiKey, key);
  }

  static Future<String?> getOpenRouterApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyOpenRouterKey);
  }

  static Future<void> setOpenRouterApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyOpenRouterKey, key);
  }

  static Future<String> getSelectedAiProvider() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySelectedProvider) ?? 'gemini';
  }

  static Future<void> setSelectedAiProvider(String provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedProvider, provider);
  }

  static Future<String> getLicenseStatus() async {
    await LicenseService.instance.init();
    return LicenseService.instance.isActivated() ? 'Activated' : 'Trial';
  }

  static Future<void> setLicenseStatus(String status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLicenseStatus, status);
  }

  static Future<String> getDeviceId() async {
    return await LicenseService.instance.getDeviceId();
  }

  static Future<String> getExportQuality() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyExportQuality) ?? "1080p";
  }

  static Future<void> setExportQuality(String quality) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyExportQuality, quality);
  }

  static Future<bool> getBackgroundRenderingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBackgroundRendering) ?? true;
  }

  static Future<void> setBackgroundRenderingEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBackgroundRendering, enabled);
  }

  static Future<Map<String, dynamic>> getStats() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'shortsMade': prefs.getInt(_keyTotalShorts) ?? 0,
      'editingSavedHours': (prefs.getDouble(_keyTotalHoursSaved) ?? 0.0).round(),
    };
  }

  static List<ProjectItem> _getDefaultProjects() {
    return [];
  }
}
