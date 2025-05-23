# Rules for ML Kit Text Recognition (generated by AGP)
# Please add these rules to your existing keep rules in order to suppress warnings.
# This is generated automatically by the Android Gradle plugin.
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions

# It's often good practice to also explicitly keep the classes if -dontwarn isn't enough
# You might need to uncomment or add these if issues persist:
# -keep class com.google.mlkit.vision.text.chinese.** { *; }
# -keep class com.google.mlkit.vision.text.devanagari.** { *; }
# -keep class com.google.mlkit.vision.text.japanese.** { *; }
# -keep class com.google.mlkit.vision.text.korean.** { *; }
# -keep class com.google.mlkit.vision.text.latin.** { *; } # If using Latin as well

# General ML Kit keep rules that might be helpful:
-keepnames class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.** 