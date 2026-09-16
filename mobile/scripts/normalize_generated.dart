import 'dart:io';

// Deterministic whitespace cleanup of generator-owned output only.
void main() {
  final files = <FileSystemEntity>[
    ...Directory('lib').listSync(recursive: true),
    ...Directory('doc').listSync(recursive: true),
    File('README.md'),
  ];
  for (final file in files.whereType<File>()) {
    if (!file.path.endsWith('.dart') && !file.path.endsWith('.md')) continue;
    final original = file.readAsStringSync();
    final normalized =
        '${original.replaceAll(RegExp(r'[ \t]+$', multiLine: true), '').trimRight()}\n';
    if (normalized != original) file.writeAsStringSync(normalized);
  }
}
