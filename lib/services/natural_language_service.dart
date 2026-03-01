import 'package:flutter/material.dart';

class ParsedSleepData {
  DateTime? date;
  List<TimeInterval>? intervals;
  double? quality;
  String? notes;

  ParsedSleepData({this.date, this.intervals, this.quality, this.notes});
}

class TimeInterval {
  TimeOfDay start;
  TimeOfDay end;
  double? quality;
  TimeInterval(this.start, this.end, {this.quality});
}

class NaturalLanguageService {
  static ParsedSleepData parse(String text) {
    // Normalizzazione iniziale per gestire errori comuni di trascrizione e forme verbali
    text = text.toLowerCase()
      .replaceAll('calle', 'dalle')
      .replaceAll('dal ', 'dalle ')
      .replaceAll("all'una", 'alle 1:00')
      .replaceAll("all'uno", 'alle 1:00')
      .replaceAll('mezzanotte', '00:00')
      .replaceAll('un quarto', '15')
      .replaceAll('tre quarti', '45')
      .replaceAll('mezza', '30')
      .replaceAll('intsnità', 'intensità')
      .replaceAll('intensita', 'intensità')
      .replaceAll('voto', 'intensità');
    
    DateTime? date;
    if (text.contains('ieri')) {
      date = DateTime.now().subtract(const Duration(days: 1));
    } else if (text.contains('oggi')) {
      date = DateTime.now();
    }

    // Global quality (backup)
    double? globalQuality;
    final globalQualityMatch = RegExp(r'intensità\s*[:\s]*(\d+)(?:/10)?').firstMatch(text);
    if (globalQualityMatch != null) {
      globalQuality = double.tryParse(globalQualityMatch.group(1)!);
    }

    List<TimeInterval>? intervals;
    // Regex migliorata per catturare intervalli temporali complessi
    // Cerchiamo pattern come "dalle X alle Y [con intensità Z]"
    final intervalRegex = RegExp(
      r"(?:dalle|dalle ore|dalle ore:)\s+([\w\s:\d']+(?=\s+alle|\s+fino alle))\s+(?:alle|fino alle|alla)\s+([\w\s:\d']+(?=\s+con|\s+e\s+dalle|\s+note|$))(?:\s+(?:con|e|a|\s+)*\s*intensità\s*(\d+))?",
      caseSensitive: false,
    );
    
    final intervalMatches = intervalRegex.allMatches(text);
    
    if (intervalMatches.isNotEmpty) {
      intervals = [];
      for (final m in intervalMatches) {
        final startStr = m.group(1)!.trim();
        final endStr = m.group(2)!.trim();
        final intervalQualityStr = m.group(3);
        
        final start = _parseTime(startStr);
        final end = _parseTime(endStr);
        
        if (start != null && end != null) {
          intervals.add(TimeInterval(
            start, 
            end, 
            quality: intervalQualityStr != null ? double.tryParse(intervalQualityStr) : null
          ));
        }
      }
    }

    String? notes;
    final notesMatch = RegExp(r'(?:note|dettagli)\s*[:\s]*(.*)', dotAll: true).firstMatch(text);
    if (notesMatch != null) {
      notes = notesMatch.group(1)?.trim();
    } else if (text.split(' ').length > 10 && (intervals == null || intervals.isEmpty)) {
      notes = text;
    }

    return ParsedSleepData(
      date: date,
      intervals: intervals,
      quality: globalQuality,
      notes: notes,
    );
  }

  static TimeOfDay? _parseTime(String timeStr) {
    timeStr = timeStr.trim().toLowerCase();
    
    try {
      int hours = 0;
      int minutes = 0;

      // Gestione "X meno Y" (es: "3 meno venti")
      if (timeStr.contains('meno')) {
        final parts = timeStr.split('meno');
        hours = _extractDigits(parts[0]);
        minutes = -_extractDigits(parts[1]);
      } 
      // Gestione "X e Y" (es: "1 e 15")
      else if (timeStr.contains(' e ')) {
        final parts = timeStr.split(' e ');
        hours = _extractDigits(parts[0]);
        minutes = _extractDigits(parts[1]);
      }
      // Gestione standard HH:mm o solo HH
      else if (timeStr.contains(':')) {
        final parts = timeStr.split(':');
        hours = int.tryParse(parts[0]) ?? 0;
        minutes = int.tryParse(parts[1]) ?? 0;
      }
      // Gestione numeri compatti (es: "130" -> 1:30, "2230" -> 22:30)
      else if (RegExp(r'^\d{3,4}$').hasMatch(timeStr)) {
        if (timeStr.length == 3) {
          hours = int.parse(timeStr.substring(0, 1));
          minutes = int.parse(timeStr.substring(1));
        } else {
          hours = int.parse(timeStr.substring(0, 2));
          minutes = int.parse(timeStr.substring(2));
        }
      }
      // Gestione solo ora
      else {
        hours = _extractDigits(timeStr);
        minutes = 0;
      }

      // Normalizzazione finale
      int totalMinutes = hours * 60 + minutes;
      if (totalMinutes < 0) totalMinutes += 24 * 60;
      
      final finalHours = (totalMinutes ~/ 60) % 24;
      final finalMinutes = totalMinutes % 60;

      return TimeOfDay(hour: finalHours, minute: finalMinutes);
    } catch (e) {
      return null;
    }
  }

  static int _extractDigits(String s) {
    final match = RegExp(r'(\d+)').firstMatch(s);
    if (match != null) {
      return int.parse(match.group(1)!);
    }
    // Parole comuni per i numeri (opzionale, ma utile per i minuti)
    if (s.contains('dieci')) return 10;
    if (s.contains('venti')) return 20;
    if (s.contains('trenta')) return 30;
    if (s.contains('quaranta')) return 40;
    if (s.contains('cinquanta')) return 50;
    return 0;
  }
}
