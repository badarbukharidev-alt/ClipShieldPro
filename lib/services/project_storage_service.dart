import 'dart:convert';
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

    // Update stats
    if (project.status == 'done') {
      final shortsCount = prefs.getInt(_keyTotalShorts) ?? 0;
      await prefs.setInt(_keyTotalShorts, shortsCount + project.clipsCount);
      final hours = prefs.getDouble(_keyTotalHoursSaved) ?? 0.0;
      await prefs.setDouble(_keyTotalHoursSaved, hours + (project.clipsCount * 0.5));
    }
  }

  static Future<void> deleteProject(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final projects = await loadProjects();
    projects.removeWhere((p) => p.id == id);
    final jsonStr = json.encode(projects.map((x) => x.toMap()).toList());
    await prefs.setString(_keyProjects, jsonStr);
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
