import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../models/sleep_record.dart';
import '../services/storage_service.dart';

class SleepStatsScreen extends StatefulWidget {
  @override
  _SleepStatsScreenState createState() => _SleepStatsScreenState();
}

class _SleepStatsScreenState extends State<SleepStatsScreen> {
  List<SleepRecord> _allRecords = [];
  List<SleepRecord> _filteredRecords = [];
  bool _isLoading = true;
  
  // 0 = 7 Giorni, 1 = 1 Mese, 2 = 3 Mesi, 3 = Custom (Singolo o Range)
  int _activeTabIndex = 0;
  DateTimeRange? _customDateRange;

  int _chartViewType = 0; // 0 = Timeline, 1 = Weekday Averages, 2 = Keyword Groups
  List<String> _userKeywords = [];
  int? _stickyComparisonIndex;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final records = await StorageService.getRecords();
    final keywords = await StorageService.getKeywords();
    setState(() {
      _allRecords = records;
      _userKeywords = keywords;
      _isLoading = false;
      _applyFilter();
    });
  }

  void _applyFilter() {
    DateTime now = DateTime.now();
    DateTime startDate;
    DateTime endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

    if (_activeTabIndex == 0) {
      startDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: 6));
    } else if (_activeTabIndex == 1) {
      startDate = DateTime(now.year, now.month - 1, now.day);
    } else if (_activeTabIndex == 2) {
      startDate = DateTime(now.year, now.month - 3, now.day);
    } else {
      // Custom Range
      if (_customDateRange != null) {
        startDate = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day);
        endDate = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day);
      } else {
        startDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: 6));
      }
    }

    // Normalizziamo a mezzanotte per il confronto pulito
    final cleanStart = DateTime(startDate.year, startDate.month, startDate.day);
    final cleanEnd = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    _filteredRecords = _allRecords.where((record) {
      DateTime recordDate = DateTime.parse(record.date);
      return (recordDate.isAtSameMomentAs(cleanStart) || recordDate.isAfter(cleanStart)) && 
             (recordDate.isAtSameMomentAs(cleanEnd) || recordDate.isBefore(cleanEnd));
    }).toList();
  }

  Future<void> _pickCustomRange() async {
    DateTime now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: _customDateRange ?? DateTimeRange(start: now.subtract(Duration(days: 7)), end: now),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).brightness == Brightness.light
                ? ColorScheme.light(primary: AppTheme.primaryIndigo)
                : ColorScheme.dark(primary: AppTheme.primaryIndigo),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _activeTabIndex = 3;
        _customDateRange = picked;
        _applyFilter();
      });
    }
  }

  void _changeTab(int index) {
    if (index == 3) {
      _pickCustomRange();
      return;
    }
    setState(() {
      _activeTabIndex = index;
      _stickyComparisonIndex = null; // Reset sticky tooltip on tab change
      _applyFilter();
    });
  }

  // Helpers per i calcoli
  double _calculateTotalHours(SleepRecord record) {
    double total = 0;
    for (var interval in record.intervals) {
      final startParts = interval.start.split(':');
      final endParts = interval.end.split(':');
      
      int startH = int.parse(startParts[0]);
      int startM = int.parse(startParts[1]);
      int endH = int.parse(endParts[0]);
      int endM = int.parse(endParts[1]);

      double startDecimal = startH + (startM / 60.0);
      double endDecimal = endH + (endM / 60.0);

      if (endDecimal < startDecimal) {
        // Ha scavalcato la mezzanotte
        endDecimal += 24.0;
      }
      total += (endDecimal - startDecimal);
    }
    return total;
  }

  double _calculateAverageIntensity(SleepRecord record) {
    if (record.intervals.isEmpty) return 0;
    double sum = 0;
    for (var i in record.intervals) {
      sum += i.quality;
    }
    return sum / record.intervals.length;
  }

  int _calculateAwakenings(SleepRecord record) {
    return record.intervals.isEmpty ? 0 : record.intervals.length - 1;
  }

  double _calculateScore(SleepRecord record) {
    double totalWeighted = 0;
    for (var interval in record.intervals) {
      final startParts = interval.start.split(':');
      final endParts = interval.end.split(':');
      
      int startH = int.parse(startParts[0]);
      int startM = int.parse(startParts[1]);
      int endH = int.parse(endParts[0]);
      int endM = int.parse(endParts[1]);

      double startDecimal = startH + (startM / 60.0);
      double endDecimal = endH + (endM / 60.0);

      if (endDecimal < startDecimal) {
        endDecimal += 24.0;
      }
      double duration = endDecimal - startDecimal;
      totalWeighted += (interval.quality * duration);
    }
    return totalWeighted / 10.0;
  }

  void _editKeywords() async {
    String currentKws = _userKeywords.join(', ');
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        TextEditingController controller = TextEditingController(text: currentKws);
        return AlertDialog(
          title: Text('Gestisci Keyword'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Inserisci keyword separate da virgola per analizzare le tue note.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'es: sport, stress, alcol',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Annulla')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryIndigo),
              child: Text('Salva', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }
    );

    if (result != null) {
      final newKws = result.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      await StorageService.saveKeywords(newKws);
      setState(() {
        _userKeywords = newKws;
      });
    }
  }

  Map<int, List<SleepRecord>> _groupByWeekday() {
    Map<int, List<SleepRecord>> groups = {1: [], 2: [], 3: [], 4: [], 5: [], 6: [], 7: []};
    for (var record in _filteredRecords) {
      try {
        int weekday = DateTime.parse(record.date).weekday;
        groups[weekday]!.add(record);
      } catch (_) {}
    }
    return groups;
  }

  Map<String, List<SleepRecord>> _groupByKeywords() {
    Map<String, List<SleepRecord>> groups = {'Altro': []};
    for (var kw in _userKeywords) {
      groups[kw] = [];
    }

    for (var record in _filteredRecords) {
      bool matched = false;
      String notes = (record.notes ?? '').toLowerCase();
      for (var kw in _userKeywords) {
        if (notes.contains(kw.toLowerCase())) {
          groups[kw]!.add(record);
          matched = true;
        }
      }
      if (!matched) {
        groups['Altro']!.add(record);
      }
    }
    return groups;
  }

  void _showGroupDetails(String groupLabel, List<SleepRecord> records, BuildContext context) {
    if (records.isEmpty) return;

    double avgHours = records.map((r) => _calculateTotalHours(r)).reduce((a, b) => a + b) / records.length;
    double avgIntensity = records.map((r) => _calculateAverageIntensity(r)).reduce((a, b) => a + b) / records.length;
    double avgAwakenings = records.map((r) => _calculateAwakenings(r)).reduce((a, b) => a + b).toDouble() / records.length;
    double avgScore = records.map((r) => _calculateScore(r)).reduce((a, b) => a + b) / records.length;

    int h = avgHours.floor();
    int m = ((avgHours - h) * 60).round();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
              ),
              SizedBox(height: 24),
              Text('Riepilogo Gruppo', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
              SizedBox(height: 8),
              Text(groupLabel, style: TextStyle(color: AppTheme.primaryIndigo, fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center),
              Text('${records.length} notti registrate', style: TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                   _MiniStat(label: 'Sonno', value: '${h}h ${m}m', icon: Icons.schedule),
                   _MiniStat(label: 'Qualità', value: '${avgIntensity.toStringAsFixed(1)}/10', icon: Icons.star),
                   _MiniStat(label: 'Risvegli', value: '${avgAwakenings.toStringAsFixed(1)}', icon: Icons.warning_amber),
                   _MiniStat(label: 'Score', value: '${avgScore.toStringAsFixed(1)}', icon: Icons.auto_awesome),
                ],
              ),
              SizedBox(height: 24),
              Text('Dettaglio Giorni', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 8),
              Container(
                constraints: BoxConstraints(maxHeight: 250),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final rec = records[index];
                    final dateStr = DateFormat('dd/MM/yy').format(DateTime.parse(rec.date));
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(dateStr, style: TextStyle(fontWeight: FontWeight.w500)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Score: ${_calculateScore(rec).toStringAsFixed(1)}', style: TextStyle(color: AppTheme.primaryIndigo, fontWeight: FontWeight.bold)),
                          Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                        ],
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _showDayDetails(rec, context);
                      },
                    );
                  },
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryIndigo),
                child: Text('Chiudi', style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        );
      }
    );
  }

  void _showDayDetails(SleepRecord record, BuildContext context) {
    DateTime dateObj = DateTime.parse(record.date);
    String formattedDate = DateFormat('dd MMMM yyyy').format(dateObj);
    
    double hours = _calculateTotalHours(record);
    int h = hours.floor();
    int m = ((hours - h) * 60).round();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              SizedBox(height: 24),
              Text('Dettagli Notte', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
              SizedBox(height: 8),
              Text(formattedDate, style: TextStyle(color: AppTheme.primaryIndigo, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                   _MiniStat(label: 'Durata', value: '${h}h ${m}m', icon: Icons.schedule),
                   _MiniStat(label: 'Qualità', value: '${_calculateAverageIntensity(record).toStringAsFixed(1)}/10', icon: Icons.star),
                   _MiniStat(label: 'Risvegli', value: '${_calculateAwakenings(record)}', icon: Icons.warning_amber),
                   _MiniStat(label: 'Score', value: '${_calculateScore(record).toStringAsFixed(1)}', icon: Icons.auto_awesome),
                 ],
               ),
              SizedBox(height: 24),
              if (record.notes != null && record.notes!.isNotEmpty) ...[
                Text('Note', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Text(record.notes!, style: TextStyle(fontStyle: FontStyle.italic)),
                ),
                SizedBox(height: 24),
              ],
              Text('Intervalli di Sonno', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 8),
              ...record.intervals.asMap().entries.map((entry) {
                int idx = entry.key + 1;
                var interval = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 12, backgroundColor: AppTheme.primaryIndigo, child: Text(idx.toString(), style: TextStyle(fontSize: 12, color: Colors.white))),
                      SizedBox(width: 12),
                      Expanded(child: Text('${interval.start} - ${interval.end}')),
                      Text('Qualità: ${interval.quality}', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }).toList(),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryIndigo),
                child: Text('Chiudi', style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        );
      }
    );
  }

  void _showFullscreenChart(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Chiudi',
      transitionDuration: Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.close, color: AppTheme.primaryIndigo),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('Grafico Ingrandito', style: TextStyle(color: AppTheme.primaryIndigo)),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text('Pizzica per zoomare • Trascina per scorrere', 
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                  SizedBox(height: 20),
                  Expanded(
                    child: InteractiveViewer(
                      panEnabled: true,
                      scaleEnabled: true,
                      minScale: 1.0,
                      maxScale: 10.0,
                      // Avvolgiamo il grafico in un GestureDetector per assicurarci che riceva i tap
                      // anche dentro InteractiveViewer
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 1.2,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 32.0, bottom: 20),
                            child: _buildChart(isFull: true),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryIndigo)),
      );
    }

    // Calcolo medie globali
    double globalAvgSleep = 0;
    double globalAvgIntensity = 0;
    double globalAvgAwakenings = 0;
    double globalAvgScore = 0;

    if (_filteredRecords.isNotEmpty) {
      for (var r in _filteredRecords) {
        globalAvgSleep += _calculateTotalHours(r);
        globalAvgIntensity += _calculateAverageIntensity(r);
        globalAvgAwakenings += _calculateAwakenings(r);
        globalAvgScore += _calculateScore(r);
      }
      globalAvgSleep /= _filteredRecords.length;
      globalAvgIntensity /= _filteredRecords.length;
      globalAvgAwakenings /= _filteredRecords.length;
      globalAvgScore /= _filteredRecords.length;
    }

    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            // Chiudi il tooltip quando clicco fuori dal grafico
            if (_stickyComparisonIndex != null) setState(() => _stickyComparisonIndex = null);
          },
          behavior: HitTestBehavior.opaque,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16.0),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Period Selector
            Container(
              padding: EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: theme.inputDecorationTheme.fillColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _PeriodTab(title: '7 Giorni', isActive: _activeTabIndex == 0, onTap: () => _changeTab(0)),
                  _PeriodTab(title: '1 Mese', isActive: _activeTabIndex == 1, onTap: () => _changeTab(1)),
                  _PeriodTab(title: '3 Mesi', isActive: _activeTabIndex == 2, onTap: () => _changeTab(2)),
                  _PeriodTab(title: 'Custom', isActive: _activeTabIndex == 3, onTap: () => _changeTab(3)),
                ],
              ),
            ),
            SizedBox(height: 24),
            
            // Chart View Type Dropdown (EMPHASIZED)
            if (_filteredRecords.length > 7 || _activeTabIndex > 0) ...[
              SizedBox(height: 12),
              Row(
                children: [
                   Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryIndigo.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryIndigo.withOpacity(0.2)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _chartViewType,
                          isExpanded: true,
                          icon: Icon(Icons.analytics_outlined, color: AppTheme.primaryIndigo),
                          style: TextStyle(color: AppTheme.primaryIndigo, fontWeight: FontWeight.bold, fontSize: 16),
                          items: [
                            DropdownMenuItem(value: 0, child: Text('Vista: Cronologica')),
                            DropdownMenuItem(value: 1, child: Text('Vista: Medie Settimanali')),
                            DropdownMenuItem(value: 2, child: Text('Vista: Analisi Keyword')),
                          ],
                          onChanged: (v) {
                             setState(() {
                               _chartViewType = v ?? 0;
                               _stickyComparisonIndex = null; // Reset sticky tooltip on view change
                             });
                          },
                        ),
                      ),
                    ),
                  ),
                  if (_chartViewType == 2) ...[
                    SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.auto_fix_high_rounded, color: Colors.amber[800]),
                        onPressed: _editKeywords,
                        tooltip: 'Gestisci Keyword',
                      ),
                    ),
                  ]
                ],
              ),
            ],
            
            SizedBox(height: 24),
            
            // Removed 'Andamento' text to reduce redundancy

            // Average Cards (MOVED DOWN)
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Sonno Medio',
                    value: '${globalAvgSleep.toStringAsFixed(1)}h',
                    icon: Icons.nightlight_round,
                    color: Colors.green, // Linea Verde
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    title: 'Intensità',
                    value: globalAvgIntensity.toStringAsFixed(1),
                    icon: Icons.star_rate_rounded,
                    color: Colors.orange, // Linea Arancione
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    title: 'Risvegli',
                    value: globalAvgAwakenings.toStringAsFixed(1),
                    icon: Icons.warning_rounded,
                    color: Colors.blue, // Linea Blu
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    title: 'Score',
                    value: globalAvgScore.toStringAsFixed(1),
                    icon: Icons.auto_awesome,
                    color: Colors.deepPurple, // Linea Viola
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            GestureDetector(
              onTap: () => _showFullscreenChart(context),
              child: Card(
                clipBehavior: Clip.none,
                child: Padding(
                  padding: EdgeInsets.only(top: 32, bottom: 16, left: 16, right: 32),
                  child: AspectRatio(
                    aspectRatio: 1.5,
                    child: _buildChart(isFull: false),
                  ),
                ),
              ),
            ),
            
            SizedBox(height: 32),
            
            // Recently Logged Single Days
            Text('Nottate Recenti', style: theme.textTheme.titleLarge),
            SizedBox(height: 12),
            if (_filteredRecords.isEmpty) 
               Padding(
                 padding: EdgeInsets.symmetric(vertical: 20),
                 child: Text('Nessun dato registrato nel periodo selezionato.', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
               ),
            ..._filteredRecords.take(7).map((record) {
              DateTime dateObj = DateTime.parse(record.date);
              String formattedDate = DateFormat('dd MMMM yyyy').format(dateObj);
              double hours = _calculateTotalHours(record);
              int h = hours.floor();
              int m = ((hours - h) * 60).round();
              
               return _RecentDayCard(
                date: formattedDate,
                duration: '${h}h ${m}m',
                quality: '${_calculateAverageIntensity(record).toStringAsFixed(1)}/10',
                score: _calculateScore(record).toStringAsFixed(1),
                awakenings: _calculateAwakenings(record),
                record: record,
              );
            }).toList()
          ],
        ),
      ),
    ),
  ));
  }

  Widget _buildChart({bool isFull = false}) {
    if (_filteredRecords.isEmpty) {
      return Center(child: Text('Nessun dato per il grafico', style: TextStyle(color: Colors.grey)));
    }

    if (_chartViewType == 1) return _buildWeekdayAveragesChart(isFull: isFull);
    if (_chartViewType == 2) return _buildKeywordAveragesChart(isFull: isFull);

    // Per il grafico prendiamo i record filtrati e li rovesciamo in ordine cronologico (dal più vecchio al più nuovo)
    List<SleepRecord> chartRecords = _filteredRecords.toList().reversed.toList();
    
    List<FlSpot> sleepSpots = [];
    List<FlSpot> intensitySpots = [];
    List<FlSpot> awakeningSpots = [];
    List<FlSpot> scoreSpots = [];

    for (int i = 0; i < chartRecords.length; i++) {
      double x = (i + 1).toDouble();
      sleepSpots.add(FlSpot(x, _calculateTotalHours(chartRecords[i])));
      intensitySpots.add(FlSpot(x, _calculateAverageIntensity(chartRecords[i])));
      awakeningSpots.add(FlSpot(x, _calculateAwakenings(chartRecords[i]).toDouble()));
      scoreSpots.add(FlSpot(x, _calculateScore(chartRecords[i])));
    }

    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(
          touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
            if (event is FlTapUpEvent && touchResponse != null && touchResponse.lineBarSpots != null) {
              final spotIndex = touchResponse.lineBarSpots!.first.spotIndex;
              if (spotIndex >= 0 && spotIndex < chartRecords.length) {
                _showDayDetails(chartRecords[spotIndex], context);
              }
            }
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) => [],
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 2,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              // Mostriamo i titoli solo se abbiamo 7 giorni o meno (per pulizia visiva)
              showTitles: chartRecords.length <= 7,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                const style = TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.grey);
                int index = value.toInt() - 1;
                if (index >= 0 && index < chartRecords.length) {
                   DateTime date = DateTime.parse(chartRecords[index].date);
                   String label;
                   if (isFull && chartRecords.length > 7) {
                     label = DateFormat('dd/MM').format(date);
                   } else {
                     label = DateFormat('E').format(date).toUpperCase();
                   }
                   
                   return SideTitleWidget(
                     axisSide: meta.axisSide, 
                     child: Padding(
                       padding: EdgeInsets.only(right: !isFull && index == chartRecords.length - 1 ? 16.0 : 0.0),
                       child: Text(label, style: style),
                     ),
                   );
                }
                return SideTitleWidget(axisSide: meta.axisSide, child: Text('', style: style));
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 2,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                if (value > 11) return const SizedBox();
                return Text(value.toInt().toString(), style: TextStyle(fontSize: 10, color: Colors.grey));
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 1,
        maxX: chartRecords.length.toDouble() > 1 ? chartRecords.length.toDouble() : 2,
        minY: 0,
        maxY: 11.5,
        clipData: FlClipData.none(),
        lineBarsData: [
          // Hours Slept (Green Line)
          LineChartBarData(
            spots: sleepSpots.isEmpty ? [FlSpot(1,0)] : sleepSpots,
            isCurved: true,
            color: Colors.green,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: Colors.green.withOpacity(0.1)),
          ),
          // Intensity (Orange Line)
          LineChartBarData(
            spots: intensitySpots.isEmpty ? [FlSpot(1,0)] : intensitySpots,
            isCurved: true,
            color: Colors.orange,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(show: true),
            dashArray: [5, 5],
          ),
          // Awakenings (Blue Line)
          LineChartBarData(
            spots: awakeningSpots.isEmpty ? [FlSpot(1,0)] : awakeningSpots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 3, color: Colors.blue, strokeWidth: 1, strokeColor: Colors.white)),
          ),
          // Score (Purple Line)
          LineChartBarData(
            spots: scoreSpots.isEmpty ? [FlSpot(1,0)] : scoreSpots,
            isCurved: true,
            color: Colors.deepPurple,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 4, color: Colors.deepPurple, strokeWidth: 1, strokeColor: Colors.white)),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayAveragesChart({bool isFull = false}) {
    final groups = _groupByWeekday();
    List<FlSpot> sleepSpots = [];
    List<FlSpot> intensitySpots = [];
    List<FlSpot> awakeningSpots = [];
    List<FlSpot> scoreSpots = [];

    const weekdaysLabels = ['LUN', 'MAR', 'MER', 'GIO', 'VEN', 'SAB', 'DOM'];
    List<List<SleepRecord>> groupRecords = [];

    for (int i = 1; i <= 7; i++) {
        final dayRecords = groups[i]!;
        groupRecords.add(dayRecords);
        if (dayRecords.isEmpty) continue;

        double avgSleep = dayRecords.map((r) => _calculateTotalHours(r)).reduce((a, b) => a + b) / dayRecords.length;
        double avgIntensity = dayRecords.map((r) => _calculateAverageIntensity(r)).reduce((a, b) => a + b) / dayRecords.length;
        double avgAwakenings = dayRecords.map((r) => _calculateAwakenings(r)).reduce((a, b) => a + b).toDouble() / dayRecords.length;
        double avgScore = dayRecords.map((r) => _calculateScore(r)).reduce((a, b) => a + b) / dayRecords.length;

        double x = i.toDouble();
        sleepSpots.add(FlSpot(x, avgSleep));
        intensitySpots.add(FlSpot(x, avgIntensity));
        awakeningSpots.add(FlSpot(x, avgAwakenings));
        scoreSpots.add(FlSpot(x, avgScore));
    }

    return _renderComparisonChart(
      sleepSpots, intensitySpots, awakeningSpots, scoreSpots,
      (x) => weekdaysLabels[x.toInt() - 1],
      7,
      groupRecords
    );
  }

  Widget _buildKeywordAveragesChart({bool isFull = false}) {
    if (_userKeywords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Nessuna keyword impostata', style: TextStyle(color: Colors.grey)),
            TextButton(onPressed: _editKeywords, child: Text('Aggiungi Keyword'))
          ],
        ),
      );
    }

    final groups = _groupByKeywords();
    List<FlSpot> sleepSpots = [];
    List<FlSpot> intensitySpots = [];
    List<FlSpot> awakeningSpots = [];
    List<FlSpot> scoreSpots = [];

    List<String> labels = groups.keys.toList();
    List<List<SleepRecord>> groupRecords = [];

    for (int i = 0; i < labels.length; i++) {
        final catRecords = groups[labels[i]]!;
        groupRecords.add(catRecords);
        if (catRecords.isEmpty) continue;

        double avgSleep = catRecords.map((r) => _calculateTotalHours(r)).reduce((a, b) => a + b) / catRecords.length;
        double avgIntensity = catRecords.map((r) => _calculateAverageIntensity(r)).reduce((a, b) => a + b) / catRecords.length;
        double avgAwakenings = catRecords.map((r) => _calculateAwakenings(r)).reduce((a, b) => a + b).toDouble() / catRecords.length;
        double avgScore = catRecords.map((r) => _calculateScore(r)).reduce((a, b) => a + b) / catRecords.length;

        double x = (i + 1).toDouble();
        sleepSpots.add(FlSpot(x, avgSleep));
        intensitySpots.add(FlSpot(x, avgIntensity));
        awakeningSpots.add(FlSpot(x, avgAwakenings));
        scoreSpots.add(FlSpot(x, avgScore));
    }

    return _renderComparisonChart(
      sleepSpots, intensitySpots, awakeningSpots, scoreSpots,
      (x) => labels[x.toInt() - 1],
      labels.length.toDouble(),
      groupRecords
    );
  }

  Widget _renderComparisonChart(
    List<FlSpot> sleep, List<FlSpot> intensity, List<FlSpot> awakenings, List<FlSpot> score,
    String Function(double) getLabel,
    double maxXVal,
    List<List<SleepRecord>> groupRecords
  ) {
     final barSleep = LineChartBarData(spots: sleep, isCurved: false, color: Colors.green, barWidth: 3, dotData: FlDotData(show: true));
     final barIntensity = LineChartBarData(spots: intensity, isCurved: false, color: Colors.orange, barWidth: 2, dotData: FlDotData(show: true), dashArray: [5, 5]);
     final barAwakenings = LineChartBarData(spots: awakenings, isCurved: false, color: Colors.blue, barWidth: 2, dotData: FlDotData(show: true));
     final barScore = LineChartBarData(spots: score, isCurved: false, color: Colors.deepPurple, barWidth: 3, dotData: FlDotData(show: true));

     return LineChart(
      LineChartData(
        showingTooltipIndicators: [], 
        lineTouchData: LineTouchData(
          handleBuiltInTouches: false,
          touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
             if (event is FlTapUpEvent) {
               if (touchResponse != null && touchResponse.lineBarSpots != null && touchResponse.lineBarSpots!.isNotEmpty) {
                 final clickedX = touchResponse.lineBarSpots!.first.x.toInt();
                 setState(() {
                   if (_stickyComparisonIndex == clickedX) {
                     _stickyComparisonIndex = null;
                   } else {
                     _stickyComparisonIndex = clickedX;
                     // Mostra dettagli gruppo
                     _showGroupDetails(getLabel(clickedX.toDouble()), groupRecords[clickedX - 1], context);
                   }
                 });
               } else {
                 setState(() => _stickyComparisonIndex = null);
               }
             }
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) => [],
          ),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: true, horizontalInterval: 2),
        titlesData: FlTitlesData(
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                try {
                  return SideTitleWidget(axisSide: meta.axisSide, child: Text(getLabel(value), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)));
                } catch (_) { return SizedBox(); }
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 2,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                if (value > 11) return const SizedBox();
                return Text(value.toInt().toString(), style: TextStyle(fontSize: 10, color: Colors.grey));
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 1,
        maxX: maxXVal,
        minY: 0,
        maxY: 11.5,
        clipData: FlClipData.none(),
        lineBarsData: [barSleep, barIntensity, barAwakenings, barScore],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            SizedBox(height: 8),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(height: 4),
            Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _RecentDayCard extends StatelessWidget {
  final String date;
  final String duration;
  final String quality;
  final String score;
  final int awakenings;
  final SleepRecord record;

  const _RecentDayCard({
    required this.date, 
    required this.duration, 
    required this.quality, 
    required this.score,
    required this.awakenings,
    required this.record,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primaryIndigo.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.nightlight_round, color: AppTheme.primaryIndigo),
        ),
        title: Text(date, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Durata: $duration • Score: $score', style: theme.textTheme.bodyMedium),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(quality, style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            SizedBox(height: 4),
            Text('Risvegli: $awakenings', style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        onTap: () {
          // Usa il widget stateful per accedere al metodo _showDayDetails volendo, ma lo passiamo tramite un callback?
          // Per semplicità qua troviamo il context genitore o passiamo una funzione
          context.findAncestorStateOfType<_SleepStatsScreenState>()?._showDayDetails(record, context);
        },
      ),
    );
  }
}

// Helper per mini statistiche nel BottomSheet
class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MiniStat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey, size: 20),
        SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}

class _PeriodTab extends StatelessWidget {
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const _PeriodTab({required this.title, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primaryIndigo : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ),
      ),
    );
  }
}
