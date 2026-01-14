# 关键：media_store_plus 在 Android 侧使用 GSON 进行序列化/反序列化；若启用 R8/混淆，需保留注解与泛型签名，避免运行时解析失败。
-keepattributes Signature
-keepattributes *Annotation*

# 关键：保留 Gson 内部使用的类型适配器与反射相关类（遵循官方示例的通用配置）。
-keep class sun.misc.Unsafe { *; }
-keep class com.google.gson.stream.** { *; }
-keep class com.google.gson.reflect.** { *; }
-keep class com.google.gson.** { *; }

