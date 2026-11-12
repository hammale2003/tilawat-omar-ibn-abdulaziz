# Play Store listing

Copy-paste material for the Play Console. Character limits are Google's.

## App name (30 max)

```
تلاوات عمر بن عبد العزيز
```

Alternative if you want the reciter's name in the title (only with his written
permission, which you have):

```
تلاوات عمر بن عبد العزيز
```

## Short description (80 max)

```
استمع إلى القرآن الكريم بصوت الشيخ عمر بن عبد العزيز — بدون إعلانات ودون إنترنت
```

English (for the en-US listing):

```
Listen to the Holy Qur'an. No ads, no accounts, works offline.
```

## Full description (4000 max)

```
تطبيق «تلاوة» للاستماع إلى القرآن الكريم بصوت الشيخ عمر بن عبد العزيز، برواية حفص عن عاصم.

تطبيق بسيط وهادئ، صُمّم لغرض واحد: أن تستمع دون عوائق.

• مجاني بالكامل — بدون إعلانات، وبدون اشتراكات، وبدون مشتريات داخل التطبيق
• بدون حساب ولا تسجيل دخول — افتح التطبيق واستمع
• يعمل دون إنترنت — نزّل السور التي تريدها واستمع إليها في أي وقت
• يكمل من حيث توقفت — في كل سورة على حدة
• التشغيل في الخلفية — مع أزرار التحكم على شاشة القفل وسماعات الرأس
• تكرار السورة أو الكل — للحفظ والمراجعة
• مؤقّت النوم، وسرعة التلاوة
• بحث سريع عن أي سورة
• المظهر الفاتح والداكن
• واجهة عربية بالكامل

الخصوصية:
لا يجمع التطبيق أي بيانات على الإطلاق. لا حسابات، ولا إعلانات، ولا تتبّع، ولا
إحصاءات. كل ما تحفظه يبقى على جهازك وحده. الاتصال الوحيد بالإنترنت هو لتحميل
ملفات التلاوة نفسها.

التلاوة منشورة بإذن من القارئ.

ملاحظة: يعرض التطبيق السور المتوفّرة حاليًا من تلاوة الشيخ، وتُضاف السور الجديدة
فور توفّرها.
```

## Required before you can publish

| Item | Status |
|---|---|
| Privacy policy URL | `https://hammale2003.github.io/tilawat-omar-ibn-abdulaziz/privacy.html` — live as soon as Pages is enabled on `main` `/docs` |
| Data safety form | answer "no data collected" to everything; see note below |
| Content rating questionnaire | reference / books; no objectionable content |
| Target audience | 13+ (avoids the stricter children's-policy rules) |
| App category | Books & Reference (not Music & Audio — reviewers expect Qur'an apps here) |
| Screenshots | at least 2 phone screenshots, 16:9 or 9:16, min 320px |
| Feature graphic | 1024 × 500 PNG |
| App icon | 512 × 512 — `design/play-store-icon-512.png` |

### Data safety form

Answer **no** to every collection and sharing question. The app has no backend,
no analytics SDK and no ad SDK. The only network request is an HTTP GET for an
audio file. Declare: no data collected, no data shared, data is not encrypted in
transit *only if* you serve audio over plain HTTP — archive.org serves HTTPS, so
you can answer that data in transit is encrypted.

Do not be tempted to add an analytics SDK "just to see installs". Play Console
already gives you installs, and adding one turns a clean data-safety form into a
disclosure you then have to maintain.
