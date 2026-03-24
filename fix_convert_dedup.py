import csv
import os

def generate_specific_map(csv_path, dart_path, map_name="courseIntroductions"):
    """
    生成 Dart Map，并处理重复键的问题。
    """
    if not os.path.exists(csv_path):
        print(f"Error: CSV file not found at {csv_path}")
        return

    # 使用字典来存储数据，自动覆盖重复键，保留最后一条数据
    # 这样可以避免 Dart 中 "Two keys in a constant map literal can't be equal" 错误
    data_dict = {}
    try:
        with open(csv_path, mode='r', encoding='utf-8-sig') as csvfile:
            reader = csv.DictReader(csvfile)
            for row in reader:
                name = row.get('Name', '')
                introduce = row.get('IntroduceWhenPurchased', '')
                if name:
                    # 规范化换行符
                    introduce = (introduce or "").replace("\r\n", "\n").replace("\r", "\n")
                    data_dict[name] = introduce
    except Exception as e:
        print(f"Error reading CSV: {e}")
        return

    dart_lines = [
        f"const Map<String, String> {map_name} = <String, String>{{",
    ]

    for name, introduce in data_dict.items():
        # 处理 Key 中的单引号和换行符 (发现有个键叫 "测试\n2")
        safe_name = name.replace("'", "\\'").replace("\n", "").replace("\r", "")
        # 处理内容中可能存在的 '''
        safe_introduce = introduce.replace("'''", "' ' '")
        # 使用 r'''...'''
        dart_lines.append(f"  '{safe_name}': r'''{safe_introduce}''',")

    dart_lines.append("};")

    try:
        with open(dart_path, mode='w', encoding='utf-8', newline='\n') as f:
            f.write("\n".join(dart_lines))
        print(f"Successfully generated Dart file at {dart_path}")
    except Exception as e:
        print(f"Error writing Dart file: {e}")

if __name__ == "__main__":
    csv_file = r'd:\FlutterItem\think_nest\assets\docs\课程.csv'
    dart_file = r'd:\FlutterItem\think_nest\lib\common\values\course_introductions.dart'
    generate_specific_map(csv_file, dart_file)
