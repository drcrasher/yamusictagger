import 'dart:io' show Directory, Platform;

import 'package:args/args.dart';
import 'package:yamusictagger/tagger.dart';

const String version = '0.0.1';

ArgParser buildParser() {
  return ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print this usage information.',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      hide: true,
      help: 'Show additional command output.',
    )
    ..addFlag('version', negatable: false, help: 'Print the tool version.')
    ..addFlag('auto', abbr: 'a', help: 'Autodetect yandex.music files.')
    ..addOption(
      'yapath',
      abbr: 'm',
      help: 'Directory for ya.music MP3 dowloads.',
    )
    ..addOption('yadb', abbr: 'd', help: 'Path to ya.music sqlite database.')
    ..addOption('out', abbr: 'o', help: 'Output path to MP3 files.');
}

void printUsage(ArgParser argParser) {
  print('Usage: yamusictagger <flags> [arguments]');
  print(argParser.usage);
}

void main(List<String> arguments) {
  final ArgParser argParser = buildParser();
  try {
    final ArgResults results = argParser.parse(arguments);
    bool verbose = false;

    // Process the parsed arguments.
    if (results.flag('help')) {
      printUsage(argParser);
      return;
    }
    if (results.flag('version')) {
      print('yamusictagger version: $version');
      return;
    }
    if (results.flag('verbose')) {
      verbose = true;
    }

    String? mp;
    String? db;
    String? out;

    bool autoTest = results.flag('auto');

    if (!autoTest && results.option('yapath') != null) {
      mp = results.option('yapath');
    }
    if (!autoTest && results.option('yadb') != null) {
      db = results.option('yadb');
    }
    if (results.option('out') != null) {
      out = results.option('out');
    }

    if (autoTest) {
      print('Received --auto flag. Trying to detect yandex.music settings...');
      String? localAppData = Platform.environment['LOCALAPPDATA'];

      if (localAppData == null) throw "Can't get environment variables.";

      Directory probeDir = Directory('$localAppData\\Packages');

      if (!probeDir.existsSync()) throw "Can't get 'packages'.";

      List<String> probeContent = probeDir
          .listSync()
          .map((e) => e.path)
          .toList(growable: false);

      String probeYaDir = probeContent.firstWhere(
        (element) => element.toLowerCase().contains(".yandex.music_"),
        orElse: () => "",
      );

      if (probeYaDir.isEmpty) throw "Can't find ya.music directory";

      String probeState = "$probeYaDir\\LocalState";

      mp = Directory("$probeState\\Music").listSync().first.path;
      print("Using yapath=$mp");

      try {
        db = Directory(probeState)
            .listSync()
            .firstWhere((element) => element.path.endsWith('.sqlite'))
            .path;
      } catch (_) {
        db = null;
      }

      if (db == null) throw "Can't find *.sqlite database";

      print("Using yadb=$db");
    }

    // Act on the arguments provided.
    // print('Positional arguments: ${results.rest}');
    if (verbose) {
      print('[VERBOSE] All arguments: ${results.arguments}');
    }
    if (mp == null || db == null || out == null) {
      throw FormatException('Invalid parameters');
    }

    Tagger(yaSource: mp, yaDb: db, outpath: out).run();
  } on FormatException catch (e) {
    // Print usage information if an invalid argument was provided.
    print(e.message);
    print('');
    printUsage(argParser);
  } catch (e) {
    print(e);
  }
}
