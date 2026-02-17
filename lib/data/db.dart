import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class AppDb {
  static Database? _db;

  static Future<void> _ensureTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS favorite_channels(
        channel_url TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        thumb TEXT NOT NULL,
        added_at INTEGER NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS favorite_videos(
        video_url TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        channel TEXT NOT NULL,
        thumb TEXT NOT NULL,
        added_at INTEGER NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_prefs(
        k TEXT PRIMARY KEY,
        v TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS transcript_reads(
        video_url TEXT PRIMARY KEY,
        transcribed_at INTEGER NOT NULL,
        caption_lang TEXT,
        translated_to TEXT,
        translated_at INTEGER
      );
    ''');
  }

  static Future<Database> _open() async {
    if (_db != null) return _db!;
    final base = await getDatabasesPath();
    final path = p.join(base, 'newstube.db');

    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, _) async {
        await _ensureTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Garante tabelas em upgrades (ex.: usuários que já tinham DB v1).
        await _ensureTables(db);
      },
    );
    return _db!;
  }

  static Future<bool> isFavChannel(String channelUrl) async {
    try {
      final db = await _open();
      final r = await db.query('favorite_channels', where: 'channel_url=?', whereArgs: [channelUrl], limit: 1);
      return r.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isFavVideo(String videoUrl) async {
    try {
      final db = await _open();
      final r = await db.query('favorite_videos', where: 'video_url=?', whereArgs: [videoUrl], limit: 1);
      return r.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<void> toggleFavChannel({
    required String channelUrl,
    required String title,
    required String thumb,
  }) async {
    final db = await _open();
    final exists = await isFavChannel(channelUrl);
    if (exists) {
      await db.delete('favorite_channels', where: 'channel_url=?', whereArgs: [channelUrl]);
    } else {
      await db.insert('favorite_channels', {
        'channel_url': channelUrl,
        'title': title,
        'thumb': thumb,
        'added_at': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  static Future<void> toggleFavVideo({
    required String videoUrl,
    required String title,
    required String channel,
    required String thumb,
  }) async {
    final db = await _open();
    final exists = await isFavVideo(videoUrl);
    if (exists) {
      await db.delete('favorite_videos', where: 'video_url=?', whereArgs: [videoUrl]);
    } else {
      await db.insert('favorite_videos', {
        'video_url': videoUrl,
        'title': title,
        'channel': channel,
        'thumb': thumb,
        'added_at': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  static Future<List<Map<String, Object?>>> listFavChannels() async {
    try {
      final db = await _open();
      return db.query('favorite_channels', orderBy: 'added_at DESC');
    } catch (_) {
      return <Map<String, Object?>>[];
    }
  }

  static Future<List<Map<String, Object?>>> listFavVideos() async {
    try {
      final db = await _open();
      return db.query('favorite_videos', orderBy: 'added_at DESC');
    } catch (_) {
      return <Map<String, Object?>>[];
    }
  }

  // ------------------------
  // Transcrições lidas / traduzidas
  // ------------------------
  static Future<bool> isTranscribed(String videoUrl) async {
    try {
      final db = await _open();
      final r = await db.query('transcript_reads', where: 'video_url=?', whereArgs: [videoUrl], limit: 1);
      return r.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, Object?>?> getTranscriptMeta(String videoUrl) async {
    try {
      final db = await _open();
      final r = await db.query('transcript_reads', where: 'video_url=?', whereArgs: [videoUrl], limit: 1);
      return r.isEmpty ? null : r.first;
    } catch (_) {
      return null;
    }
  }

  static Future<void> markTranscribed({
    required String videoUrl,
    String? captionLang,
  }) async {
    final db = await _open();
    await db.insert(
      'transcript_reads',
      {
        'video_url': videoUrl,
        'transcribed_at': DateTime.now().millisecondsSinceEpoch,
        'caption_lang': (captionLang ?? '').trim().isEmpty ? null : captionLang!.trim(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> markTranslated({
    required String videoUrl,
    required String targetLang,
  }) async {
    final db = await _open();
    final now = DateTime.now().millisecondsSinceEpoch;
    final exists = await isTranscribed(videoUrl);
    if (exists) {
      await db.update(
        'transcript_reads',
        {
          'translated_to': targetLang.trim(),
          'translated_at': now,
        },
        where: 'video_url=?',
        whereArgs: [videoUrl],
      );
    } else {
      await db.insert(
        'transcript_reads',
        {
          'video_url': videoUrl,
          'transcribed_at': now,
          'translated_to': targetLang.trim(),
          'translated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  static Future<bool> hasBeenTranslated(String videoUrl) async {
    final meta = await getTranscriptMeta(videoUrl);
    final v = (meta?['translated_to'] ?? '').toString().trim();
    return v.isNotEmpty;
  }

  // ---- app prefs (sem shared_preferences) ----
  static Future<String?> getPrefString(String key) async {
    try {
      final db = await _open();
      final r = await db.query('app_prefs', where: 'k=?', whereArgs: [key], limit: 1);
      if (r.isEmpty) return null;
      return (r.first['v'] as String?) ;
    } catch (_) {
      return null;
    }
  }

  static Future<void> setPrefString(String key, String value) async {
    final db = await _open();
    await db.insert('app_prefs', {'k': key, 'v': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<bool?> getPrefBool(String key) async {
    final v = await getPrefString(key);
    if (v == null) return null;
    final s = v.toLowerCase().trim();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0') return false;
    return null;
  }

  static Future<void> setPrefBool(String key, bool value) =>
      setPrefString(key, value ? 'true' : 'false');

}
