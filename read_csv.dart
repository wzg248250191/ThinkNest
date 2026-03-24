import 'dart:io';
import 'dart:convert';

void main() async {
  final file = File('d:/FlutterItem/think_nest/assets/docs/课程.csv');
  final lines = await file.readAsLines(encoding: utf8);
  if (lines.isEmpty) {
    print('File is empty');
    return;
  }
  print(lines[0]);
  print(lines[1]);
}