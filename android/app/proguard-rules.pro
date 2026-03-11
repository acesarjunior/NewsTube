# --- NewPipeExtractor / Rhino / Jsoup ---
# Evita falhas do R8 por classes opcionais que não existem no Android.

# Rhino
-keep class org.mozilla.javascript.** { *; }
-keep class org.mozilla.classfile.ClassFileWriter { *; }
-dontwarn org.mozilla.javascript.tools.**
-dontwarn org.mozilla.javascript.**

# Classes que não existem no Android, mas aparecem como referências opcionais em algumas libs
-dontwarn java.beans.**
-dontwarn javax.script.**
-dontwarn com.google.re2j.**

# Jsoup (mantém o básico)
-keep class org.jsoup.** { *; }
-dontwarn org.jsoup.**

# Mantém o que é acessado por reflexão no MainActivity (caption tracks etc.)
-keep class org.schabi.newpipe.extractor.** { *; }
-dontwarn org.schabi.newpipe.extractor.**
