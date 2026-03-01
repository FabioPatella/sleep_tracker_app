import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/google_drive_service.dart';
import '../theme.dart';

class SleepSyncScreen extends StatefulWidget {
  const SleepSyncScreen({Key? key}) : super(key: key);

  @override
  _SleepSyncScreenState createState() => _SleepSyncScreenState();
}

class _SleepSyncScreenState extends State<SleepSyncScreen> {
  GoogleSignInAccount? _currentUser;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _checkSignInStatus();
  }

  void _checkSignInStatus() async {
    final bool signedIn = await GoogleDriveService.isSignedIn();
    if (signedIn) {
      final account = await GoogleDriveService.signIn();
      setState(() {
        _currentUser = account;
      });
    }
  }

  Future<void> _handleSignIn() async {
    setState(() => _isProcessing = true);
    final account = await GoogleDriveService.signIn();
    setState(() {
      _currentUser = account;
      _isProcessing = false;
    });
  }

  Future<void> _handleSignOut() async {
    await GoogleDriveService.signOut();
    setState(() {
      _currentUser = null;
    });
  }

  Future<void> _handleBackup() async {
    setState(() => _isProcessing = true);
    final error = await GoogleDriveService.backupToCloud();
    setState(() => _isProcessing = false);

    if (mounted) {
      final bool success = (error == null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Backup completato con successo!' : error),
          backgroundColor: success ? AppTheme.successGreen : AppTheme.errorLight,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleRestore() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma Ripristino'),
        content: const Text('Il ripristino cancellerà TUTTI i dati attualmente presenti sul telefono e li sostituirà con quelli del Cloud. Vuoi procedere?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorLight),
            child: const Text('Ripristina'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    final error = await GoogleDriveService.restoreFromCloud();
    setState(() => _isProcessing = false);

    if (mounted) {
      final bool success = (error == null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Ripristino completato! Riavvia l\'app per vedere i dati.' : error),
          backgroundColor: success ? AppTheme.successGreen : AppTheme.errorLight,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Sync'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.primaryIndigo),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.cloud_sync_outlined, size: 80, color: AppTheme.primaryIndigo),
            const SizedBox(height: 24),
            Text(
              'Sincronizzazione Cloud',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Proteggi i tuoi dati salvandoli sul tuo Google Drive personale. Potrai ripristinarli su qualsiasi dispositivo.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 40),
            
            if (_currentUser == null) ...[
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _handleSignIn,
                icon: const Icon(Icons.login),
                label: const Text('Accedi con Google'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryIndigo,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: _currentUser!.photoUrl != null 
                        ? NetworkImage(_currentUser!.photoUrl!) 
                        : null,
                      child: _currentUser!.photoUrl == null ? const Icon(Icons.person) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_currentUser!.displayName ?? 'Utente Google', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(_currentUser!.email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, size: 20, color: Colors.grey),
                      onPressed: _handleSignOut,
                    )
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              if (_isProcessing)
                const Center(child: CircularProgressIndicator(color: AppTheme.primaryIndigo))
              else ...[
                ElevatedButton.icon(
                  onPressed: _handleBackup,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('Esegui Backup su Cloud'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryIndigo,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _handleRestore,
                  icon: const Icon(Icons.cloud_download),
                  label: const Text('Ripristina dal Cloud'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: AppTheme.primaryIndigo),
                  ),
                ),
              ],
            ],
            
            const Spacer(),
            Text(
              'I tuoi file sono salvati in una cartella sicura e privata su Google Drive, accessibile solo da questa app.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}
