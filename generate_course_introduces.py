import csv
import os
import sys

def csv_to_dart_introduces(csv_path, dart_path):
    if not os.path.exists(csv_path):
        print(f"Error: CSV file not found at {csv_path}")
        return

    data_dict = {}
    try:
        with open(csv_path, mode='r', encoding='utf-8-sig') as csvfile:
            reader = csv.DictReader(csvfile)
            for row in reader:
                name = row.get('Name', '')
                if not name:
                    continue
                
                name = name.replace("\n", "").replace("\r", "")
                introduce = row.get('IntroduceWhenPurchased', '')
                
                data_dict[name] = introduce
    except Exception as e:
        print(f"Error reading CSV: {e}")
        return

    dart_lines = [
        "// 自动生成的课程购买介绍映射表",
        "const Map<String, String> courseIntroduces = <String, String>{",
    ]

    for name, introduce in data_dict.items():
        safe_name = name.replace("'", "\\'")
        # 转义反斜杠、单引号、换行符和 $ 符号
        safe_introduce = introduce.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "\\n").replace("\r", "").replace('$', '\\$')
        dart_lines.append(f"  '{safe_name}': '{safe_introduce}',")

    dart_lines.append("};")

    try:
        with open(dart_path, mode='w', encoding='utf-8') as f:
            f.write("\n".join(dart_lines))
        print(f"Successfully generated Dart file at {dart_path}")
    except Exception as e:
        print(f"Error writing Dart file: {e}")

if __name__ == "__main__":
    csv_file = r"d:\FlutterItem\think_nest\assets\docs\课程.csv"
    dart_file = r"d:\FlutterItem\think_nest\lib\common\values\course_introduces.dart"
    csv_to_dart_introduces(csv_file, dart_file)
