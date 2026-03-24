import 'dart:io';
import 'dart:convert';

void main() async {
  try {
    final csvFile = File(r'd:\FlutterItem\think_nest\assets\docs\课程.csv');
    if (!await csvFile.exists()) {
      File('error.txt').writeAsStringSync('CSV file not found');
      return;
    }

    // read as bytes and decode to avoid BOM issues
    final bytes = await csvFile.readAsBytes();
    String content;
    try {
      content = utf8.decode(bytes, allowMalformed: true);
    } catch (e) {
      content = String.fromCharCodes(bytes);
    }

    final rows = _parseCsv(content);
    if (rows.isEmpty) {
      File('error.txt').writeAsStringSync('Rows empty');
      return;
    }
    
    final actualHeaders = rows.first;
    final nIdx = actualHeaders.indexOf('Name');
    final iIdx = actualHeaders.indexOf('IntroduceWhenPurchased');

    if (nIdx == -1 || iIdx == -1) {
      File('error.txt').writeAsStringSync('Columns not found. Headers: \$actualHeaders');
      return;
    }

    final dataDict = <String, String>{};
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length > nIdx && row.length > iIdx) {
        final name = row[nIdx].trim();
        final intro = row[iIdx];
        if (name.isNotEmpty) {
          dataDict[name] = intro;
        }
      }
    }

    final buffer = StringBuffer();
    buffer.writeln('const Map<String, String> courseIntroduces = <String, String>{');
    
    for (final entry in dataDict.entries) {
      final safeName = entry.key.replaceAll("'", "\\'");
      final safeIntro = entry.value
          .replaceAll('\\', '\\\\')
          .replaceAll("'", "\\'")
          .replaceAll('\n', '\\n')
          .replaceAll('\r', '')
          .replaceAll('\$', '\\\$');
      buffer.writeln("  '\$safeName': '\$safeIntro',");
    }
    buffer.writeln('};');

    final outFile = File(r'd:\FlutterItem\think_nest\lib\common\values\course_introduces.dart');
    await outFile.writeAsString(buffer.toString());
    File('error.txt').writeAsStringSync('Success. Wrote \${dataDict.length} entries.');
  } catch (e) {
    File('error.txt').writeAsStringSync('Error: \$e');
  }
}

List<List<String>> _parseCsv(String content) {
  final rows = <List<String>>[];
  var currentRow = <String>[];
  var currentField = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < content.length; i++) {
    final char = content[i];
    
    if (inQuotes) {
      if (char == '"') {
        if (i + 1 < content.length && content[i + 1] == '"') {
          currentField.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        currentField.write(char);
      }
    } else {
      if (char == '"') {
        inQuotes = true;
      } else if (char == ',') {
        currentRow.add(currentField.toString());
        currentField.clear();
      } else if (char == '\n') {
        var field = currentField.toString();
        if (field.endsWith('\r')) {
          field = field.substring(0, field.length - 1);
        }
        currentRow.add(field);
        rows.add(currentRow);
        currentRow = <String>[];
        currentField.clear();
      } else if (char != '\r') {
        currentField.write(char);
      }
    }
  }
  
  if (currentField.isNotEmpty || currentRow.isNotEmpty) {
    var field = currentField.toString();
    if (field.endsWith('\r')) {
      field = field.substring(0, field.length - 1);
    }
    currentRow.add(field);
    rows.add(currentRow);
  }
  
  return rows;
}
