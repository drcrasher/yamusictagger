import 'dart:io';

import 'package:eztags/eztags.dart';
import 'package:sqlite3/sqlite3.dart';

class Tagger {
  final String yaSource;
  final String yaDb;
  final String outpath;

  Tagger({required this.yaSource, required this.yaDb, required this.outpath});

  void run() async {
    try {
      print('Checking sources:');

      print('* music directory...');
      _yaDir = Directory(yaSource);
      if (!_yaDir!.existsSync()) {
        throw '!! Ya.Music source directory not exists';
      }

      print('* files to process...');
      _files = _yaDir!.listSync().map((e) => e.path).toList();

      if (_files.isEmpty) throw "No files to process";

      print("... found ${_files.length} file(s)");

      print('* target direcory...');
      _target = Directory(outpath);
      if (!_target!.existsSync()) {
        print('... not exsists. Creating...');
        _target!.createSync(recursive: true);
      }

      print('* ya.music database...');
      _openDb();

      print('Checking complete\r\r');

      print('Processing files');

      for (String f in _files) {
        await _processFile(f);
      }
    } catch (e) {
      print('Exception while processing files:');
      print(e);
    } finally {
      if (_database != null) {
        print('Database closed.');
        _database?.close();
      }
    }

    print('Processing complete.');
  }

  Directory? _yaDir;
  Directory? _target;
  List<String> _files = [];

  Database? _database;

  void _openDb() {
    _database = sqlite3.open(yaDb, mode: .readOnly);
    print('Database opened');
  }

  Future _processFile(String f) async {
    List<String> parts = f.split("\\");

    String fname = parts.last;

    if (!fname.toLowerCase().endsWith('.mp3')) {
      print('... skipped $f');
      return;
    }

    stdout.write('... processing ${fname.padRight(16)}...');

    // File(f).copySync("${_target!.path}\\$fname");

    ResultSet rtags = _database!.select(_sql, [fname.split('.').first]);

    if (rtags.isEmpty) {
      stdout.writeln('tags not found in database, skipped');
      return;
    }

    List<Map<String, String>> tags = [
      ...rtags.map(
        (row) => row.map(
          (key, value) => MapEntry(
            key,
            value.toString().replaceAll(RegExp(r'[^a-zA-Z0-9а-яА-ЯйЙ]'), ' '),
          ),
        ),
      ),
    ];

    stdout.write(' building tags...');

    Map<String, String> id3 = tags.removeAt(0);

    for (var t in tags) {
      id3.update(
        'artist',
        (value) => "$value,${t['artist']}",
        ifAbsent: () => t['artist']!,
      );
    }

    id3['artist'] = id3['artist']!.split(',').toSet().toList().join(', ');
    final tagList = TagList.fromMap(id3);

    String newFName =
        "${id3['artist']} - ${id3['title']} (${id3['album'] ?? ""})";

    stdout.write('writing to $newFName');
    newFName = "${_target!.path}\\$newFName.mp3";

    File(f).copySync(newFName);

    await addTagsToFile(tagList, newFName);

    stdout.writeln(" complete.");
  }

  final String _sql = '''
SELECT tt.Title as title, ta.Name as artist  , ta2.Title as album,
ta2."Year" as "year", ta2.GenreId as genre
FROM T_Track AS tt 
left join  T_TrackArtist tta on tt.Id = tta.TrackId  
LEFT join T_Artist ta on tta.ArtistId = ta.Id 
LEFT join T_TrackAlbum ttalb on tt.Id = ttalb.TrackId 
left join T_Album ta2 on ttalb.AlbumId = ta2.Id 
WHERE RealId = :trackId --limit 1
''';
}
