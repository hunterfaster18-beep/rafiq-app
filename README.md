# رفيق — Flutter starter project

هذا مشروع مصدر Flutter لتطبيق عربي لتتبع العادات والروتين بتصميم أسود وبنفسجي.
يشمل:
- إضافة وحذف العادات.
- تسجيل الالتزام اليومي وعداد السلسلة وأفضل سلسلة.
- تسجيل الانتكاسة مع حفظ تاريخها.
- مهام الروتين اليومي، مع إمكانية مراجعة تاريخ سابق.
- إحصائيات أساسية.
- حفظ محلي باستخدام `shared_preferences`.

## ملاحظة مهمة
المرفق يحتوي على ملفات Flutter المصدرية الأساسية. مجلد Android الأصلي (Gradle والـ wrapper وملفات المنصة) يتم توليده بواسطة Flutter SDK على جهازك؛ لم يتم بناء AAB هنا لأن Flutter/Android SDK غير متاحين في بيئة الإنشاء هذه. بعد توليد مجلد Android، اتبع الخطوات أدناه.

## تجهيز المشروع على الكمبيوتر
1. ثبّت Flutter SDK وAndroid Studio، ثم تأكد من `flutter doctor`.
2. افتح Terminal/PowerShell في المكان الذي تريد المشروع فيه ونفّذ:
   ```bash
   flutter create --org com.yourname rafiq_habit_tracker
   ```
3. استبدل `pubspec.yaml` و`lib/main.dart` الناتجين بالملفين الموجودين في هذا المرفق.
4. من داخل مجلد المشروع نفّذ:
   ```bash
   flutter pub get
   flutter run
   ```
5. غيّر `com.yourname.rafiq_habit_tracker` إلى معرّف حزمة فريد خاص بك قبل النشر. لا تغيّره بعد نشر التطبيق لأول مرة.
   في المشاريع الحديثة يمكن أن يظهر المعرّف في `android/app/build.gradle.kts` ضمن `applicationId` و`namespace`.
6. افتح `android/app/build.gradle.kts` وتأكد أن `targetSdk` يساوي 36 أو أعلى وفق متطلبات Google Play الحالية، مع تثبيت Android SDK Platform 36 من Android Studio. قد تحتاج نسخة Flutter/Gradle متوافقة مع هذا المستوى.
7. اختبر الإضافة، الحذف، الإنجاز، الانتكاسة، وتأكد أن البيانات تبقى بعد إغلاق التطبيق وإعادة فتحه.

## إعداد توقيع الإصدار
لا ترفع مفتاح التوقيع أو كلمات المرور لأي شخص. احتفظ بنسخة احتياطية آمنة من ملف keystore.

أنشئ مفتاح رفع (مثال عام):
```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
اتبع دليل Flutter الرسمي لتوصيل `key.properties` وملف keystore بإعدادات Gradle، ولا تضع أسرار التوقيع في مستودع عام.

## بناء AAB
بعد ضبط توقيع الإصدار ومعرّف الحزمة وtarget SDK:
```bash
flutter clean
flutter pub get
flutter build appbundle --release
```
المخرج المعتاد:
`build/app/outputs/bundle/release/app.aab`

## النشر
1. افتح Google Play Console وأنشئ تطبيقًا.
2. أكمل تفاصيل المتجر، تصنيف المحتوى، سياسة الخصوصية وإفصاحات Data safety وفق سلوك التطبيق الفعلي.
3. ارفع AAB أولًا إلى Internal testing واختبره على جهاز حقيقي.
4. أكمل أي متطلبات اختبار مغلق/تحقق تظهر لحسابك، ثم أرسل للإنتاج للمراجعة.
5. عند تحديث التطبيق، زد `version` في `pubspec.yaml` مثل `1.0.1+2`.

## الخصوصية
هذا الإصدار يخزّن بيانات العادات والمهام محليًا على الجهاز باستخدام SharedPreferences ولا يرسلها إلى خادم. إذا أضفت لاحقًا حسابات أو تحليلات أو إعلانات، راجع سياسة الخصوصية وإفصاحات المتجر من جديد.
