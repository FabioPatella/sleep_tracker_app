import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sleep_record.dart';

class StorageService {
  static const String _storageKey = 'sleep_records';
  static const String _keywordsKey = 'user_keywords';

  // --- Gestione Sleep Records ---
  
  // Salva un nuovo record nella lista esistente
  static Future<void> saveRecord(SleepRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Recupera i vecchi record testuali JSON
    List<String> recordsJsonList = prefs.getStringList(_storageKey) ?? [];
    
    // Controlliamo se esiste già un record per quella stessa data per sovrascriverlo o aggiungerlo 
    recordsJsonList.removeWhere((jsonStr) {
      final map = jsonDecode(jsonStr);
      return map['date'] == record.date;
    });

    // Aggiungi il nuovo record
    recordsJsonList.add(jsonEncode(record.toJson()));
    
    // Salva nel disco
    await prefs.setStringList(_storageKey, recordsJsonList);
  }

  // Legge tutti i record salvati
  static Future<List<SleepRecord>> getRecords() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> recordsJsonList = prefs.getStringList(_storageKey) ?? [];
    
    List<SleepRecord> records = recordsJsonList.map((jsonStr) {
      return SleepRecord.fromJson(jsonDecode(jsonStr));
    }).toList();
    
    // Ordiniamo dal più recente al più vecchio in base alla data
    records.sort((a, b) => b.date.compareTo(a.date));
    
    return records;
  }

  /// Cancella tutto e ripristina con una nuova lista (usato per il ripristino Cloud)
  static Future<void> clearAllAndRestore(List<SleepRecord> newRecords) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> recordsJsonList = newRecords.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(_storageKey, recordsJsonList);
  }

  // Elimina un record per una specifica data
  static Future<void> deleteRecord(String date) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> recordsJsonList = prefs.getStringList(_storageKey) ?? [];
    
    recordsJsonList.removeWhere((jsonStr) {
      final map = jsonDecode(jsonStr);
      return map['date'] == date;
    });
    
    await prefs.setStringList(_storageKey, recordsJsonList);
  }

  // --- Gestione Keywords (Separate dai records) ---

  static Future<void> saveKeywords(List<String> keywords) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keywordsKey, keywords);
  }

  static Future<List<String>> getKeywords() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keywordsKey) ?? [];
  }
}
