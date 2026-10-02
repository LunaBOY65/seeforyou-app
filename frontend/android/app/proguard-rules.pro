# ป้องกัน Error จาก ML Kit Text Recognition
-dontwarn com.google.mlkit.vision.text.**
-keep class com.google.mlkit.vision.text.** { *; }

# หากมีปัญหาเกี่ยวกับ ML Kit Common ด้วย ให้ใส่เพิ่ม
-dontwarn com.google.android.gms.internal.mlkit_vision_text_common.**