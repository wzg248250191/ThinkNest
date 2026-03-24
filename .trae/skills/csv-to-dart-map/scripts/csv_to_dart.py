import csv
import os
import sys

def csv_to_dart(csv_path, dart_path, map_name="coursesByName"):
    """
    将 CSV 转换为 Dart Map<String, Map<String, Object?>> 格式。
    """
    if not os.path.exists(csv_path):
        print(f"Error: CSV file not found at {csv_path}")
        return

    data_dict = {}
    try:
        with open(csv_path, mode='r', encoding='utf-8-sig') as csvfile:
            reader = csv.DictReader(csvfile)
            for row in reader:
                # 核心映射逻辑
                name = row.get('Name', '')
                if not name:
                    continue
                
                # 处理换行符，避免生成的 Dart 字符串出错
                name = name.replace("\n", "").replace("\r", "")
                
                suitable_grade = row.get('SuitableGrade', '')
                course_focus = row.get('CourseFocus', '')
                
                # 映射到 Dart Map
                data = {
                    'name': name,
                    'class': suitable_grade,
                    'describe': course_focus,
                    'type': '', # 默认为空，用户可手动补充
                    'letterName': '' # 默认为空，用户可手动补充
                }
                # 使用字典存储，自动覆盖重复的 name，保证键唯一
                data_dict[name] = data
    except Exception as e:
        print(f"Error reading CSV: {e}")
        return

    # 生成 Dart 代码
    dart_lines = [
        f"const Map<String, Map<String, Object?>> {map_name} = <String, Map<String, Object?>>{{",
    ]

    for name, data in data_dict.items():
        # 处理单引号转义
        safe_name = name.replace("'", "\\'")
        dart_lines.append(f"  '{safe_name}': <String, Object?>{{")
        for key, value in data.items():
            # 处理转义和引号
            safe_value = str(value).replace("'", "\\'").replace("\n", "\\n").replace("\r", "")
            dart_lines.append(f"    '{key}': '{safe_value}',")
        dart_lines.append("  },")

    dart_lines.append("};")

    # 写入 Dart 文件
    try:
        with open(dart_path, mode='w', encoding='utf-8') as f:
            f.write("\n".join(dart_lines))
        print(f"Successfully generated Dart file at {dart_path}")
    except Exception as e:
        print(f"Error writing Dart file: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python csv_to_dart.py <csv_path> <dart_path> [map_name]")
    else:
        csv_file = sys.argv[1]
        dart_file = sys.argv[2]
        name = sys.argv[3] if len(sys.argv) > 3 else "coursesByName"
        csv_to_dart(csv_file, dart_file, name)
