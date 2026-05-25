import 'dart:typed_data';

extension StringUtf16Enc on String {
  Uint8List get toUint8List {
    var list = <int>[];
    for (var rune in runes) {
      if (rune >= 0x10000) {
        rune -= 0x10000;
        int firstWord = (rune >> 10) + 0xD800;
        list.add(firstWord >> 8);
        list.add(firstWord & 0xFF);
        int secondWord = (rune & 0x3FF) + 0xDC00;
        list.add(secondWord >> 8);
        list.add(secondWord & 0xFF);
      } else {
        list.add(rune >> 8);
        list.add(rune & 0xFF);
      }
    }
    Uint8List bytes = Uint8List.fromList(list);
    return bytes;
  }
}
