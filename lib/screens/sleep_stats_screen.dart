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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final records = await StorageService.getRecords();
    setState(() {
      _allRecords = records;
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

    if (_filteredRecords.isNotEmpty) {
      for (var r in _filteredRecords) {
        globalAvgSleep += _calculateTotalHours(r);
        globalAvgIntensity += _calculateAverageIntensity(r);
        globalAvgAwakenings += _calculateAwakenings(r);
      }
      globalAvgSleep /= _filteredRecords.length;
      globalAvgIntensity /= _filteredRecords.length;
      globalAvgAwakenings /= _filteredRecords.length;
    }

    return Scaffold(
      body: SafeArea(
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
            
            // Average Cards
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
              ],
            ),
            
            SizedBox(height: 32),
            
            // Chart Overview
            Text(
              _activeTabIndex == 0 ? 'Andamento Settimanale' :
              _activeTabIndex == 1 ? 'Andamento Mensile' :
              _activeTabIndex == 2 ? 'Andamento Trimestrale' : 'Andamento Personalizzato',
              style: theme.textTheme.titleLarge,
            ),
            SizedBox(height: 16),
            GestureDetector(
              onTap: () => _showFullscreenChart(context),
              child: Card(
                clipBehavior: Clip.hardEdge,
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
                awakenings: _calculateAwakenings(record),
                record: record,
              );
            }).toList()
          ],
        ),
      ),
    ));
  }

  Widget _buildChart({bool isFull = false}) {
    if (_filteredRecords.isEmpty) {
      return Center(child: Text('Nessun dato per il grafico', style: TextStyle(color: Colors.grey)));
    }

    // Per il grafico prendiamo i record filtrati e li rovesciamo in ordine cronologico (dal più vecchio al più nuovo)
    List<SleepRecord> chartRecords = _filteredRecords.toList().reversed.toList();
    
    List<FlSpot> sleepSpots = [];
    List<FlSpot> intensitySpots = [];
    List<FlSpot> awakeningSpots = [];

    for (int i = 0; i < chartRecords.length; i++) {
      double x = (i + 1).toDouble();
      sleepSpots.add(FlSpot(x, _calculateTotalHours(chartRecords[i])));
      intensitySpots.add(FlSpot(x, _calculateAverageIntensity(chartRecords[i])));
      awakeningSpots.add(FlSpot(x, _calculateAwakenings(chartRecords[i]).toDouble()));
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
             getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                   String label = '';
                   if (spot.barIndex == 0) label = 'Sonno: ';
                   if (spot.barIndex == 1) label = 'Qualità: ';
                   if (spot.barIndex == 2) label = 'Risvegli: ';
                   
                   return LineTooltipItem(
                     '$label${spot.y.toStringAsFixed(1)}${spot.barIndex == 0 ? 'h' : ''}',
                     const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                   );
                }).toList();
             },
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
                return Text(value.toInt().toString(), style: TextStyle(fontSize: 10, color: Colors.grey));
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 1,
        maxX: chartRecords.length.toDouble() > 1 ? chartRecords.length.toDouble() : 2,
        minY: 0,
        maxY: 12,
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
        ],
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
  final int awakenings;
  final SleepRecord record;

  const _RecentDayCard({
    required this.date, 
    required this.duration, 
    required this.quality, 
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
        subtitle: Text('Durata: $duration • Risvegli: $awakenings', style: theme.textTheme.bodyMedium),
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(quality, style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
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
