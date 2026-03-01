import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../models/sleep_record.dart';
import '../services/storage_service.dart';
import '../services/natural_language_service.dart';
import '../theme.dart';
import 'sleep_sync_screen.dart';

class SleepLogScreen extends StatefulWidget {
  @override
  _SleepLogScreenState createState() => _SleepLogScreenState();
}

class _SleepLogScreenState extends State<SleepLogScreen> {
  DateTime selectedDate = DateTime.now();
  List<SleepIntervalData> intervals = [SleepIntervalData()];
  final TextEditingController notesController = TextEditingController();
  bool isEditing = false;
  
  // Voice variables
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _lastWords = '';

  @override
  void initState() {
    super.initState();
    _checkExistingData();
    _initSpeech();
  }

  void _initSpeech() async {
    try {
      await _speech.initialize();
    } catch (e) {
      debugPrint('Speech initialization failed: $e');
    }
  }

  void _listen() async {
    if (!_isListening) {
      var status = await Permission.microphone.status;
      if (status.isDenied) {
        status = await Permission.microphone.request();
        if (!status.isGranted) return;
      }

      bool available = await _speech.initialize(
        onStatus: (val) => debugPrint('onStatus: $val'),
        onError: (val) => debugPrint('onError: $val'),
      );
      if (available) {
        setState(() {
          _isListening = true;
          _lastWords = ''; // Reset words when starting
        });
        _speech.listen(
          listenMode: stt.ListenMode.dictation, // Use dictation for longer recording
          onResult: (val) => setState(() {
            _lastWords = val.recognizedWords;
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      // Process only when manually stopped
      _processVoiceInput(_lastWords);
    }
  }

  void _showVoiceHelp() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text('Guida Comandi Vocali', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primaryIndigo)),
            const SizedBox(height: 8),
            const Text('Usa la tua voce per compilare il log velocemente. Ecco alcuni esempi:', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            _buildHelpItem(Icons.calendar_today, 'Data', 'Dì "Ieri" o "Oggi". Se non dici nulla, viene usata la data selezionata.'),
            _buildHelpItem(Icons.access_time, 'Intervalli', 'Supporta forme come "Mezzanotte", "L\'una e un quarto" o "Le 3 meno venti".'),
            _buildHelpItem(Icons.star, 'Qualità', 'Dì "Intensità 8". Se lo dici dopo un intervallo, viene applicato a quello.'),
            _buildHelpItem(Icons.notes, 'Note', 'Tutto il resto finisce nelle note (es. "Ho sognato il mare").'),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.primaryIndigo.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.primaryIndigo.withOpacity(0.2))),
              child: const Text(
                'Esempio: "Dalle 23:30 all\'una con intensità 3 e dalle 3 meno un quarto alle 7 con intensità 8"',
                style: TextStyle(fontStyle: FontStyle.italic, color: AppTheme.primaryIndigo),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Ho capito', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppTheme.primaryIndigo.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 20, color: AppTheme.primaryIndigo),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _processVoiceInput(String text) {
    if (text.isEmpty) return;
    
    final parsed = NaturalLanguageService.parse(text);
    
    setState(() {
      if (parsed.date != null) {
        selectedDate = parsed.date!;
      }
      if (parsed.quality != null) {
        // Applichiamo la qualità a tutti gli intervalli esistenti o solo all'ultimo?
        // Per semplicità all'ultimo o a tutti se ne abbiamo appena aggiunto uno
        for (var i in intervals) {
          i.quality = parsed.quality!.clamp(0, 10);
        }
      }
      if (parsed.intervals != null && parsed.intervals!.isNotEmpty) {
        intervals = parsed.intervals!.map((ti) => SleepIntervalData(
          start: ti.start,
          end: ti.end,
          quality: ti.quality ?? parsed.quality ?? 7.0,
        )).toList();
      }
      if (parsed.notes != null) {
        if (notesController.text.isEmpty) {
          notesController.text = parsed.notes!;
        } else {
          notesController.text += '\n${parsed.notes}';
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Input vocale elaborato: "${text.length > 30 ? text.substring(0, 30) + '...' : text}"'),
        action: SnackBarAction(label: 'Annulla', onPressed: () {
          // Opzionale: implementare undo
        }),
      ),
    );
    
    if (parsed.date != null) {
      _checkExistingData();
    }
  }

  void _checkExistingData() async {
    final records = await StorageService.getRecords();
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    
    // Cerchiamo un record esistente per questa data
    SleepRecord? existing;
    try {
      existing = records.firstWhere((r) => r.date == dateStr);
    } catch (e) {
      existing = null;
    }

    if (existing != null) {
      setState(() {
        isEditing = true;
        notesController.text = existing!.notes ?? "";
        intervals = existing.intervals.map<SleepIntervalData>((i) {
          final startParts = i.start.split(':');
          final endParts = i.end.split(':');
          return SleepIntervalData(
            start: TimeOfDay(hour: int.parse(startParts[0]), minute: int.parse(startParts[1])),
            end: TimeOfDay(hour: int.parse(endParts[0]), minute: int.parse(endParts[1])),
            quality: i.quality.toDouble(),
          );
        }).toList();
      });
    } else {
      setState(() {
        isEditing = false;
        intervals = [SleepIntervalData()];
        notesController.clear();
      });
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      _checkExistingData();
    }
  }

  Future<void> _pickTime(BuildContext context, int index, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? intervals[index].start : intervals[index].end,
      initialEntryMode: TimePickerEntryMode.input,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          intervals[index].start = picked;
        } else {
          intervals[index].end = picked;
        }
      });
    }
  }

  void _addInterval() {
    setState(() {
      intervals.add(SleepIntervalData());
    });
  }

  void _removeInterval(int index) {
    if (intervals.length > 1) {
      setState(() {
        intervals.removeAt(index);
      });
    }
  }

  bool _hasOverlaps() {
    List<List<int>> ranges = [];
    for (var i in intervals) {
      int startMins = (i.start.hour * 60 + i.start.minute - 1200 + 1440) % 1440;
      int endMins = (i.end.hour * 60 + i.end.minute - 1200 + 1440) % 1440;
      ranges.add([startMins, endMins]);
    }

    for (int i = 0; i < ranges.length; i++) {
      for (int j = i + 1; j < ranges.length; j++) {
        int s1 = ranges[i][0], e1 = ranges[i][1];
        int s2 = ranges[j][0], e2 = ranges[j][1];
        
        List<List<int>> segments1 = s1 < e1 ? [[s1, e1]] : [[s1, 1440], [0, e1]];
        List<List<int>> segments2 = s2 < e2 ? [[s2, e2]] : [[s2, 1440], [0, e2]];
        
        for (var seg1 in segments1) {
          for (var seg2 in segments2) {
            if (seg1[0] < seg2[1] && seg2[0] < seg1[1]) return true;
          }
        }
      }
    }
    return false;
  }

  void _saveData() async {
    if (_hasOverlaps()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore: gli intervalli di sonno si sovrappongono!'),
          backgroundColor: AppTheme.errorLight,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final DateFormat dateFormat = DateFormat('yyyy-MM-dd');
    final record = SleepRecord(
      date: dateFormat.format(selectedDate),
      intervals: intervals.map((i) => SleepInterval(
        start: '${i.start.hour.toString().padLeft(2, '0')}:${i.start.minute.toString().padLeft(2, '0')}',
        end: '${i.end.hour.toString().padLeft(2, '0')}:${i.end.minute.toString().padLeft(2, '0')}',
        quality: i.quality.toInt(),
      )).toList(),
      notes: notesController.text,
    );

    await StorageService.saveRecord(record);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dati salvati in memoria!'),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      // Reset del form per comodità
      setState(() {
        intervals = [SleepIntervalData()];
        isEditing = false; // No longer editing after saving
        intervals = [SleepIntervalData()];
        notesController.clear();
      });
      _checkExistingData(); // Reload data for the current date to reflect changes
    }
  }

  void _deleteData() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma Eliminazione'),
        content: const Text('Sei sicuro di voler eliminare tutti i dati per questa giornata? Questa azione non può essere annullata.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorLight),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final DateFormat dateFormat = DateFormat('yyyy-MM-dd');
    final dateToDelete = dateFormat.format(selectedDate);

    await StorageService.deleteRecord(dateToDelete);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Record eliminato con successo!'),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        isEditing = false;
        intervals = [SleepIntervalData()];
        notesController.clear();
      });
      _checkExistingData(); // Reload data for the current date to reflect deletion
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with Title and Sync Icon
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Registra Sonno', 
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold, 
                        color: AppTheme.primaryIndigo
                      )
                    ),
                    Row(
                      children: [
                        // Help Button
                        IconButton(
                          icon: const Icon(Icons.info_outline, color: AppTheme.primaryIndigo, size: 20),
                          tooltip: 'Guida Comandi Vocali',
                          onPressed: _showVoiceHelp,
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        // Voice Button
                         Stack(
                           alignment: Alignment.center,
                           children: [
                             if (_isListening)
                               const SizedBox(
                                 width: 48, height: 48,
                                 child: CircularProgressIndicator(
                                   strokeWidth: 2,
                                   valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryIndigo),
                                 ),
                               ),
                             IconButton(
                               icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: AppTheme.primaryIndigo, size: 28),
                               tooltip: 'Dettatura Vocale',
                               onPressed: _listen,
                             ),
                           ],
                         ),
                        IconButton(
                          icon: const Icon(Icons.cloud_sync, color: AppTheme.primaryIndigo, size: 28),
                          tooltip: 'Sincronizzazione Cloud',
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SleepSyncScreen()),
                          ).then((_) => _checkExistingData()),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Transcription Display
              if (_isListening || _lastWords.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Card(
                    color: AppTheme.primaryIndigo.withOpacity(0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppTheme.primaryIndigo.withOpacity(0.2)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.record_voice_over, size: 16, color: AppTheme.primaryIndigo),
                              SizedBox(width: 8),
                              Text('Trascrizione in corso...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryIndigo)),
                              Spacer(),
                              if (!_isListening) 
                                IconButton(
                                  icon: Icon(Icons.close, size: 16), 
                                  onPressed: () => setState(() => _lastWords = ''),
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(),
                                )
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            _lastWords.isEmpty ? 'Inizia a parlare...' : _lastWords,
                            style: TextStyle(fontStyle: FontStyle.italic, color: AppTheme.textLightSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Date Selection Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Data di Riferimento', style: theme.textTheme.titleLarge),
                          if (isEditing)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amber.withOpacity(0.5)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 14, color: Colors.amber.shade800),
                                  const SizedBox(width: 4),
                                  Text('MODIFICA', style: TextStyle(color: Colors.amber.shade800, fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.light ? Colors.blue.shade50 : Colors.blue.shade900.withOpacity(0.2),
                          border: Border.all(color: theme.brightness == Brightness.light ? Colors.blue.shade200 : Colors.blue.shade800),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, color: theme.brightness == Brightness.light ? Colors.blue.shade800 : Colors.blue.shade200, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'La data selezionata rappresenta il ciclo di sonno che inizia alle 20:00 del giorno precedente e termina alle 19:59 del giorno indicato.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.brightness == Brightness.light ? Colors.blue.shade900 : Colors.blue.shade100,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () => _pickDate(context),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.inputDecorationTheme.border!.borderSide.color),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('dd MMMM yyyy').format(selectedDate),
                                style: theme.textTheme.bodyLarge,
                              ),
                              const Icon(Icons.calendar_today, color: AppTheme.primaryIndigo),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
            
            // Intervals Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Intervalli di Sonno', style: theme.textTheme.titleLarge),
                TextButton.icon(
                  onPressed: _addInterval,
                  icon: Icon(Icons.add, color: AppTheme.primaryIndigo),
                  label: Text('Aggiungi', style: TextStyle(color: AppTheme.primaryIndigo, fontWeight: FontWeight.bold)),
                )
              ],
            ),
            
            // Intervals List
            ...intervals.asMap().entries.map((entry) {
              int idx = entry.key;
              SleepIntervalData interval = entry.value;
              return Card(
                margin: EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Fase ${idx + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDarkSecondary)),
                          if (intervals.length > 1)
                            IconButton(
                              icon: Icon(Icons.delete_outline, color: AppTheme.errorLight),
                              onPressed: () => _removeInterval(idx),
                              constraints: BoxConstraints(),
                              padding: EdgeInsets.zero,
                            )
                        ],
                      ),
                      SizedBox(height: 16),
                      // Time Pickers
                      Row(
                        children: [
                          Expanded(
                            child: _TimePickerBox(
                              label: 'Inizio',
                              time: interval.start,
                              onTap: () => _pickTime(context, idx, true),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _TimePickerBox(
                              label: 'Fine',
                              time: interval.end,
                              onTap: () => _pickTime(context, idx, false),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      // Quality Slider
                      Text('Qualità del sonno: ${interval.quality.toInt()}/10', style: theme.textTheme.bodyMedium),
                      Slider(
                        value: interval.quality,
                        min: 0,
                        max: 10,
                        divisions: 10,
                        activeColor: AppTheme.primaryPurple,
                        inactiveColor: theme.inputDecorationTheme.border!.borderSide.color,
                        label: interval.quality.toInt().toString(),
                        onChanged: (val) {
                          setState(() {
                            interval.quality = val;
                          });
                        },
                      )
                    ],
                  ),
                ),
              );
            }).toList(),
            
            SizedBox(height: 16),
            
            // Notes Text Area
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Note', style: theme.textTheme.titleLarge),
                    SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Come ti senti al risveglio? Altri dettagli..',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 24),
            
            // Save & Delete Buttons
            Row(
              children: [
                if (isEditing)
                  Expanded(
                    flex: 1,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: OutlinedButton(
                        onPressed: _deleteData,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppTheme.errorLight),
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Icon(Icons.delete_forever, color: AppTheme.errorLight),
                      ),
                    ),
                  ),
                Expanded(
                  flex: 3,
                  child: GradientButton(
                    onPressed: _saveData,
                    child: Text(
                      isEditing ? 'Aggiorna Dati' : 'Salva Dati',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 32),
          ],
        ),
      ),
    ),
  );
}
}

class SleepIntervalData {
  TimeOfDay start;
  TimeOfDay end;
  double quality;

  SleepIntervalData({
    TimeOfDay? start,
    TimeOfDay? end,
    this.quality = 7.0,
  })  : start = start ?? const TimeOfDay(hour: 23, minute: 30),
        end = end ?? const TimeOfDay(hour: 7, minute: 0);
}

class _TimePickerBox extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimePickerBox({required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor, // slightly darker bg inside card
          border: Border.all(color: theme.inputDecorationTheme.border!.borderSide.color.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12)),
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Icon(Icons.access_time, size: 16, color: AppTheme.textDarkSecondary),
              ],
            )
          ],
        ),
      ),
    );
  }
}
