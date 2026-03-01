class SleepInterval {
  final String start;
  final String end;
  final int quality;

  SleepInterval({
    required this.start,
    required this.end,
    required this.quality,
  });

  Map<String, dynamic> toJson() {
    return {
      'start': start,
      'end': end,
      'quality': quality, // Backend maps this to 'intensity' later if needed
    };
  }

  factory SleepInterval.fromJson(Map<String, dynamic> json) {
    return SleepInterval(
      start: json['start'] ?? '00:00',
      end: json['end'] ?? '00:00',
      quality: json['quality'] ?? (json['intensity'] ?? 0),
    );
  }
}

class SleepRecord {
  final String date;
  final List<SleepInterval> intervals;
  final String? notes;

  SleepRecord({
    required this.date,
    required this.intervals,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'intervals': intervals.map((i) => i.toJson()).toList(),
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
    };
  }

  factory SleepRecord.fromJson(Map<String, dynamic> json) {
    var intervalsList = json['intervals'] as List? ?? [];
    return SleepRecord(
      date: json['date'] ?? '',
      intervals: intervalsList.map((i) => SleepInterval.fromJson(i)).toList(),
      notes: json['notes'],
    );
  }
}
