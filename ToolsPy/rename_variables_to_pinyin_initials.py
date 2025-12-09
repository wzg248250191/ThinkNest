import re
from xpinyin import Pinyin

def rename_variables_to_initials(file_path):
    p = Pinyin()
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 匹配模式：static const [中文变量名]Png = ...
    # 捕获组1：中文部分
    pattern = re.compile(r'static const ([\u4e00-\u9fa5a-zA-Z0-9]+)Png =')

    def replace_func(match):
        original_name = match.group(1)
        
        # 将中文转换为拼音首字母
        # split='' 表示不需要分隔符，get_initials默认返回大写首字母，如 "ZhongGuo" -> "Z-G"
        # xpinyin get_initials 参数 splitter 默认为 '-'
        
        initials = p.get_initials(original_name, splitter='')
        # 转换为小写
        initials = initials.lower()
        
        # 保持原有的 Png 后缀
        return f'static const {initials}Png ='

    new_content = pattern.sub(replace_func, content)

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)

    print(f"处理完成：{file_path}")

if __name__ == "__main__":
    target_file = r"d:\FlutterItem\think_nest\lib\common\values\images.dart"
    rename_variables_to_initials(target_file)
