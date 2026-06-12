import 'dart:io';

void main() {
  final dir = Directory('lib');
  for (final file in dir.listSync(recursive: true)) {
    if (file is File && file.path.endsWith('.dart')) {
      var content = file.readAsStringSync();
      if (content.contains('DropdownButtonFormField')) {
        // We will insert borderRadius and dropdownColor after DropdownButtonFormField<...>(
        // Use a simple regex to find the start of the constructor
        final regex = RegExp(r'(DropdownButtonFormField(?:<[^>]+>)?\()');
        content = content.replaceAllMapped(regex, (match) {
          return '${match.group(1)}\nborderRadius: BorderRadius.circular(16),\ndropdownColor: Colors.white.withValues(alpha: 0.95),';
        });
        file.writeAsStringSync(content);
        print('Updated ${file.path}');
      }
    }
  }
}
