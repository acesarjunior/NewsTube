# --- NewPipeExtractor / Rhino / Jsoup / OkHttp ---

# Mantém atributos úteis para reflexão
-keepattributes Signature,InnerClasses,EnclosingMethod,*Annotation*

# Rhino
-keep class org.mozilla.javascript.** { *; }
-keep class org.mozilla.classfile.ClassFileWriter { *; }
-dontwarn org.mozilla.javascript.tools.**
-dontwarn org.mozilla.javascript.**

# Referências opcionais que não existem no Android
-dontwarn java.beans.**
-dontwarn javax.script.**
-dontwarn com.google.re2j.**

# Jsoup
-keep class org.jsoup.** { *; }
-dontwarn org.jsoup.**

# NewPipe Extractor
-keep class org.schabi.newpipe.extractor.** { *; }
-dontwarn org.schabi.newpipe.extractor.**

# OkHttp / Okio
-keep class okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**