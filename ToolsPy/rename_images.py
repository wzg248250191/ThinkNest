import os
import shutil
import sys
#运行代码：python rename_images.py "D:\钉钉缓存\Unity项目\思巢安卓平板\课程图标"
#    或者py d:\FlutterItem\think_nest\ToolsPy\rename_images.py：运行后在终端粘贴路径
def rename_and_copy_images(source_folder):
    """
    将文件夹中的图片重命名（去掉'-'前面的部分）并保存到新建的同级文件夹中。
    """
    # 检查源文件夹是否存在
    if not os.path.exists(source_folder):
        print(f"错误：文件夹 '{source_folder}' 不存在。")
        return

    # 规范化路径，去除末尾的斜杠
    source_folder = os.path.abspath(source_folder)
    
    # 获取父目录和源文件夹名称
    parent_dir = os.path.dirname(source_folder)
    folder_name = os.path.basename(source_folder)
    
    # 创建目标文件夹路径
    target_folder = os.path.join(parent_dir, f"{folder_name}_renamed")
    
    # 如果目标文件夹不存在，则创建
    if not os.path.exists(target_folder):
        try:
            os.makedirs(target_folder)
            print(f"已创建目标文件夹：{target_folder}")
        except OSError as e:
            print(f"创建目标文件夹失败: {e}")
            return
    else:
        print(f"目标文件夹已存在：{target_folder}")

    # 支持的图片扩展名（不区分大小写）
    image_extensions = {'.jpg', '.jpeg', '.png', '.bmp', '.gif', '.tiff', '.webp', '.ico', '.svg'}

    count = 0
    skipped = 0
    errors = 0

    print(f"开始处理文件夹: {source_folder}")

    # 遍历源文件夹
    try:
        files = os.listdir(source_folder)
    except OSError as e:
        print(f"无法读取源文件夹: {e}")
        return

    for filename in files:
        file_path = os.path.join(source_folder, filename)
        
        # 确保是文件
        if os.path.isfile(file_path):
            # 检查扩展名
            ext = os.path.splitext(filename)[1].lower()
            if ext in image_extensions:
                # 检查文件名中是否包含 '-'
                if '-' in filename:
                    try:
                        # 分割文件名，去掉第一个 '-' 前面的部分
                        # 使用 split('-', 1) 分割一次，取后面部分
                        parts = filename.split('-', 1)
                        if len(parts) > 1:
                            new_filename = parts[1].strip() # 去除可能的前导/尾随空格
                            
                            # 防止重命名后文件名为空
                            if not new_filename:
                                print(f"跳过（重命名后为空）：{filename}")
                                skipped += 1
                                continue

                            target_path = os.path.join(target_folder, new_filename)
                            
                            # 检查目标文件是否已存在，避免覆盖（可选，这里直接覆盖或报错）
                            # 为了安全，这里直接复制。
                            
                            shutil.copy2(file_path, target_path)
                            print(f"已处理：{filename} -> {new_filename}")
                            count += 1
                        else:
                             # 理论上 '-' in filename 为 True 不会进这里，但防万一
                            print(f"跳过（无法分割）：{filename}")
                            skipped += 1
                    except Exception as e:
                        print(f"处理文件出错 {filename}: {e}")
                        errors += 1
                else:
                    print(f"跳过（无 '-'）：{filename}")
                    skipped += 1
            else:
                # 非图片文件
                pass
    
    print("-" * 30)
    print(f"处理完成！")
    print(f"成功处理: {count}")
    print(f"跳过: {skipped}")
    if errors > 0:
        print(f"错误: {errors}")
    print(f"新文件保存在：{target_folder}")

if __name__ == "__main__":
    print("--- 图片重命名工具 ---")
    if len(sys.argv) > 1:
        src_dir = sys.argv[1]
    else:
        # 交互式输入
        src_dir = input("请输入包含图片的文件夹路径: ").strip()
        # 处理可能的引号（例如直接拖入文件夹到终端时可能会带引号）
        if (src_dir.startswith('"') and src_dir.endswith('"')) or (src_dir.startswith("'") and src_dir.endswith("'")):
            src_dir = src_dir[1:-1]
    
    if src_dir:
        rename_and_copy_images(src_dir)
    else:
        print("未提供路径，程序退出。")
