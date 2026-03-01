import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/drive/v3.dart' show DownloadOptions;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:http/http.dart' as http;
import 'storage_service.dart';
import '../models/sleep_record.dart';

class GoogleDriveService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/drive.file',
    ],
  );

  static Future<GoogleSignInAccount?> signIn() async {
    try {
      return await _googleSignIn.signIn();
    } catch (e) {
      print('Errore Google Sign-In: $e');
      return null;
    }
  }

  static Future<void> signOut() => _googleSignIn.signOut();

  static Future<bool> isSignedIn() => _googleSignIn.isSignedIn();

  static Future<drive.DriveApi?> _getDriveApi() async {
    final account = await _googleSignIn.signInSilently();
    if (account == null) return null;
    
    final client = await _googleSignIn.authenticatedClient();
    if (client == null) return null;
    
    return drive.DriveApi(client);
  }

  static const String _fileName = 'sleep_tracker_backup.json';

  /// Esegue il backup di tutti i record locali su Google Drive. Ritorna null se ok, altrimenti il messaggio di errore.
  static Future<String?> backupToCloud() async {
    final dynamic driveApi = await _getDriveApi();
    if (driveApi == null) return "Errore di autenticazione.";

    try {
      // Recupera i dati locali
      final records = await StorageService.getRecords();
      final jsonContent = jsonEncode({
        'records': records.map((r) => r.toJson()).toList(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Cerca se esiste già il file
      final dynamic fileList = await driveApi.files.list(
        q: "name = '$_fileName' and trashed = false",
        spaces: 'drive',
      );

      final dynamic driveFile = drive.File();
      driveFile.name = _fileName;

      final dynamic media = drive.Media(
        Stream.value(utf8.encode(jsonContent)),
        jsonContent.length,
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        // Aggiorna file esistente
        final String existingFileId = fileList.files!.first.id!;
        await driveApi.files.update(
          driveFile,
          existingFileId,
          uploadMedia: media,
        );
      } else {
        // Crea nuovo file
        await driveApi.files.create(
          driveFile,
          uploadMedia: media,
        );
      }
      return null;
    } catch (e) {
      print('Errore durante il backup: $e');
      if (e.toString().contains('403') || e.toString().contains('quota')) {
        return "Spazio su Google Drive esaurito.";
      }
      return "Errore durante il backup: $e";
    }
  }

  /// Scarica i dati da Google Drive e sovrascrive quelli locali
  static Future<String?> restoreFromCloud() async {
    final dynamic driveApi = await _getDriveApi();
    if (driveApi == null) return "Errore di autenticazione.";

    try {
      // Cerca il file
      final dynamic fileList = await driveApi.files.list(
        q: "name = '$_fileName' and trashed = false",
        spaces: 'drive',
      );

      if (fileList.files == null || fileList.files!.isEmpty) {
        return "Nessun backup trovato su Drive.";
      }

      final fileId = fileList.files!.first.id!;
      
      // In googleapis 10.1.0, per il download si usa il parametro downloadOptions
      // che richiede un oggetto di tipo DownloadOptions.
      final dynamic response = await driveApi.files.get(
        fileId,
        downloadOptions: DownloadOptions.fullMedia, 
      );

      final List<int> dataStore = [];
      await for (final data in response.stream) {
        dataStore.addAll(data);
      }

      final jsonString = utf8.decode(dataStore);
      final Map<String, dynamic> decoded = jsonDecode(jsonString);
      
      if (decoded.containsKey('records')) {
        final List<dynamic> recordsData = decoded['records'];
        
        await StorageService.clearAllAndRestore(
          recordsData.map((r) => SleepRecord.fromJson(r)).toList()
        );
        return null;
      }
      return "Formato file backup non valido.";
    } catch (e) {
      print('Errore durante il ripristino: $e');
      return "Errore durante il ripristino: $e";
    }
  }
}
