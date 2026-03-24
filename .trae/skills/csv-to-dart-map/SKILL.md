---
name: csv-to-dart-map
description: "将 CSV 表格数据转换为 Flutter/Dart 项目中的 Map 结构文件。当用户需要从 Excel/CSV 文件导入大量课程、配置或其他结构化数据并生成 `Map<String, Map<String, Object?>>` 格式的 Dart 文件时使用此技能。"
---

# CSV to Dart Map Converter

该技能专门用于将 CSV 文件转换为 Dart 格式的配置映射文件，特别适用于 `think_nest` 项目中的课程数据维护。

## 核心流程

1.  **确认源文件与目标文件**：
    -   默认源文件：`d:\FlutterItem\think_nest\assets\docs\课程.csv`
    -   默认目标文件：`d:\FlutterItem\think_nest\lib\common\values\courses.dart`

2.  **解析 CSV 列名**：
    -   识别 CSV 中的列（如 `Name`, `SuitableGrade`, `CourseFocus` 等）。
    -   与目标 Dart Map 的键（如 `name`, `class`, `describe`, `type`, `letterName`）进行映射。

3.  **生成数据逻辑**：
    -   使用 `Name` 作为外层 Map 的键。**注意：会自动过滤掉空键，如果存在重复的 `Name`，会自动保留最后一条数据，确保键的唯一性。**
    -   内层 Map 包含：
        -   `name`: 对应 CSV 的 `Name`
        -   `class`: 对应 CSV 的 `SuitableGrade`
        -   `describe`: 对应 CSV 的 `CourseFocus`
        -   `type`: 默认为空字符串或从特定逻辑推断。
        -   `letterName`: 建议使用拼音首字母缩写（若支持）或默认为空。

4.  **文件写入规范**：
    -   保持 `const Map<String, Map<String, Object?>> coursesByName = <String, Map<String, Object?>>{ ... };` 格式。
    -   使用单引号括起字符串。
    -   确保代码风格符合项目的 Dart 规范。

## 示例映射

| CSV 列名 | Dart Map 键 | 示例值 |
| :--- | :--- | :--- |
| Name | name | 'H2O的奇幻漂流' |
| SuitableGrade | class | '中班' |
| CourseFocus | describe | '社会、科学' |
| (推断/自定义) | type | '人际之行' |
| (拼音/自定义) | letterName | 'h2odqhpl' |

## 使用建议

-   如果 CSV 文件很大，建议先生成前几行供用户确认格式。
-   生成的 Dart 文件应包含必要的类型声明以支持 GetX 或其他框架。
