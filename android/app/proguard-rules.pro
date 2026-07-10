# flutter_local_notifications 依赖 GSON 的泛型 TypeToken 反序列化已存储的定时通知，
# R8 全量优化模式会抹掉泛型签名导致运行时抛 "Missing type parameter"。
# 保留签名属性与插件类，避免该问题。
-keepattributes Signature
-keepattributes *Annotation*

-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
-dontwarn com.dexterous.**
