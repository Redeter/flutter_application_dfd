# Gson / TypeToken — без этого R8 на release ломает загрузку сериализованных типов
# (IllegalStateException: TypeToken must be created with a type argument),
# что проявляется в flutter_local_notifications при работе с Gson.
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# Плагин локальных уведомлений (dexterous / flutter_local_notifications).
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
