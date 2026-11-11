import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr/qr.dart' as qr;
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QRStudioApp());
}

enum QRType { url, text, phone, wifi, contact, email, location }

class QRStudioApp extends StatefulWidget {
  const QRStudioApp({super.key});
  @override State<QRStudioApp> createState() => _QRStudioAppState();
}

class _QRStudioAppState extends State<QRStudioApp> with SingleTickerProviderStateMixin {
  static const String _bannerTestUnitId = 'ca-app-pub-3904535066175358/9214105998';
  static const String _interstitialTestUnitId = 'ca-app-pub-3904535066175358/9429728416';
  BannerAd? _bannerAd;
  bool _bannerLoaded = false;
  InterstitialAd? _interstitialAd;
  int _savedQrCount = 0;
  bool _interstitialShowing = false;
  bool _pendingInterstitial = false;
  bool _interstitialLoadInProgress = false;
  Timer? _bannerRetryTimer;
  Timer? _interstitialRetryTimer;

  Future<void> _initializeAds() async {
    try {
      await MobileAds.instance.initialize();
      if (!mounted) return;
      _loadBannerAd();
      _loadInterstitialAd();
    } catch (_) {
      // Ads must never prevent the app interface from starting.
    }
  }

  void _loadBannerAd() {
    if (!mounted) return;
    _bannerRetryTimer?.cancel();
    final ad = BannerAd(
      adUnitId: _bannerTestUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _bannerRetryTimer?.cancel();
          if (!mounted) { ad.dispose(); return; }
          setState(() => _bannerLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;
          setState(() => _bannerLoaded = false);
          // Retry transient failures; an unavailable AdMob fill may still need account-side review.
          _bannerRetryTimer?.cancel();
          _bannerRetryTimer = Timer(const Duration(seconds: 30), _loadBannerAd);
        },
      ),
    );
    _bannerAd = ad;
    ad.load();
  }

  void _loadInterstitialAd() {
    if (!mounted || _interstitialLoadInProgress || _interstitialAd != null) return;
    _interstitialLoadInProgress = true;
    _interstitialRetryTimer?.cancel();
    InterstitialAd.load(
      adUnitId: _interstitialTestUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialLoadInProgress = false;
          _interstitialRetryTimer?.cancel();
          _interstitialAd?.dispose();
          _interstitialAd = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              _interstitialShowing = false;
              _loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitialAd = null;
              _interstitialShowing = false;
              _loadInterstitialAd();
            },
          );
          if (_pendingInterstitial && !_interstitialShowing) {
            _showPendingInterstitial();
          }
        },
        onAdFailedToLoad: (error) {
          _interstitialLoadInProgress = false;
          _interstitialAd = null;
          if (!mounted) return;
          _interstitialRetryTimer?.cancel();
          _interstitialRetryTimer = Timer(const Duration(seconds: 30), () {
            if (mounted) _loadInterstitialAd();
          });
        },
      ),
    );
  }

  void _showPendingInterstitial() {
    final ad = _interstitialAd;
    if (ad == null || _interstitialShowing) return;
    _pendingInterstitial = false;
    _interstitialShowing = true;
    ad.show();
  }

  void _onQrSaved() {
    _savedQrCount++;
    if (_savedQrCount >= 6) {
      _savedQrCount = 0;
      _pendingInterstitial = true;
      if (_interstitialAd != null) {
        _showPendingInterstitial();
      } else {
        _loadInterstitialAd();
      }
    }
  }

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  ThemeMode themeMode = ThemeMode.light;
  String lang = 'English';
  bool _preferencesLoaded = false;
  bool _showWelcome = false;
  bool _welcomeDialogScheduled = false;
  String _welcomeLanguage = 'English';

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString('qr_studio_theme');
      final savedLanguage = prefs.getString('qr_studio_language');
      final welcomeShown = prefs.getBool('qr_studio_welcome_shown') ?? false;
      final deviceLanguage = WidgetsBinding.instance.platformDispatcher.locale.languageCode.toLowerCase();
      final welcomeLanguage = deviceLanguage == 'ru' ? 'Русский' : deviceLanguage == 'de' ? 'Deutsch' : deviceLanguage == 'ka' ? 'ქართული' : 'English';
      if (!mounted) return;
      setState(() {
        themeMode = savedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;
        const supportedLanguages = {'English', 'Русский', 'Deutsch', 'ქართული'};
        lang = supportedLanguages.contains(savedLanguage) ? savedLanguage! : 'English';
        _welcomeLanguage = welcomeLanguage;
        _showWelcome = !welcomeShown;
        _preferencesLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _preferencesLoaded = true);
    }
  }

  Map<String, String> _welcomeCopy() {
    const copy = {
      'English': {
        'title': 'Welcome to QR Studio!',
        'tagline': 'Your QR codes. Your style.',
        'body': 'Create QR codes in seconds, customize their design, add your own logo, and save or share them with ease.',
        'closing': 'Everything you need to make your QR codes unique.',
        'button': "Let's get started!",
      },
      'Русский': {
        'title': 'Добро пожаловать в QR Studio!',
        'tagline': 'Ваши QR-коды. Ваш стиль.',
        'body': 'Создавайте QR-коды за считанные секунды, настраивайте их дизайн, добавляйте собственный логотип, сохраняйте и делитесь ими.',
        'closing': 'Всё необходимое, чтобы сделать ваши QR-коды уникальными.',
        'button': 'Начнём!',
      },
      'Deutsch': {
        'title': 'Willkommen bei QR Studio!',
        'tagline': 'Deine QR-Codes. Dein Stil.',
        'body': 'Erstelle QR-Codes in Sekunden, passe ihr Design an, füge dein eigenes Logo hinzu und speichere oder teile sie ganz einfach.',
        'closing': 'Alles, was du brauchst, um deine QR-Codes einzigartig zu machen.',
        'button': "Los geht's!",
      },
      'ქართული': {
        'title': 'მოგესალმებით QR Studio-ში!',
        'tagline': 'თქვენი QR კოდები. თქვენი სტილი.',
        'body': 'შექმენით QR კოდები წამებში, მოარგეთ მათი დიზაინი, დაამატეთ საკუთარი ლოგო და მარტივად შეინახეთ ან გააზიარეთ.',
        'closing': 'ყველაფერი, რაც გჭირდებათ თქვენი QR კოდების უნიკალურობისთვის.',
        'button': 'დავიწყოთ!',
      },
    };
    return copy[_welcomeLanguage] ?? copy['English']!;
  }

  Future<void> _showWelcomeDialog() async {
    final copy = _welcomeCopy();
    final dialogContext = _navigatorKey.currentContext;
    if (dialogContext == null) {
      _welcomeDialogScheduled = false;
      return;
    }
    await showDialog<void>(
      context: dialogContext,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(copy['title']!, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(copy['tagline']!, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text(copy['body']!, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(copy['closing']!, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(copy['button']!),
          ),
        ],
      ),
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('qr_studio_welcome_shown', true);
    } catch (_) {}
    if (mounted) setState(() => _showWelcome = false);
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('qr_studio_theme', themeMode == ThemeMode.dark ? 'dark' : 'light');
      await prefs.setString('qr_studio_language', lang);
    } catch (_) {
      // Keep the app usable if local preference storage is unavailable.
    }
  }
  QRType type = QRType.url;
  Color fg = Colors.black, bg = Colors.white;
  double size = 684;
  double logoScale = .15;
  String error = 'M', security = 'WPA';
  String selectedDesign = 'classic';
  String designCategory = 'modules';
  String selectedEyeStyle = 'square';
  double logoOpacity = 1.0;
  bool transparentBg = false;
  bool showColorPanel = false;
  bool showDesignPanel = false;
  bool editingBackground = false;
  double colorBrightness = 1.0;
  bool isCheckingQr = false;
  String? qrCheckState;
  bool isScannerOpen = false;
  String? scannedValue;
  bool torchEnabled = false;
  final MobileScannerController scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 150,
    autoZoom: true,
  );
  late final AnimationController _scanLineController;
  Uint8List? photoBytes;
  ui.Image? photoImage;
  ui.Image? qrLogoImage;
  final picker = ImagePicker();
  Timer? _logoRefreshTimer;
  int _logoRefreshSerial = 0;
  final c = {for (final k in ['main','name','phone','email','subject','message','ssid','password','lat','lon','address']) k: TextEditingController()};
  final FocusNode _mainInputFocusNode = FocusNode();
  bool _mainInputFocused = false;

  final labels = const {
    'Русский': {'title':'QR Studio','subtitle':'Создавай • Кастомизируй • Сохраняй','type':'Тип QR-кода','url':'URL','text':'Текст','phone':'Телефон','wifi':'Wi‑Fi','contact':'Контакт','email':'Email','location':'Геолокация','fg':'Цвет QR','bg':'Фон','transparent':'Прозрачный фон','size':'Размер','error':'Коррекция ошибок','save':'Сохранить PNG','share':'Поделиться','checkQr':'Проверить QR','qrEmpty':'Данные QR-кода пусты.','qrReadable':'QR-код читается','qrMismatch':'Содержимое QR не совпадает','qrConfirmed':'Приложение отсканировало созданное изображение QR и подтвердило, что его содержимое совпадает с исходными данными.','qrMismatchHint':'QR-код считан, но данные не совпадают с исходными. Попробуйте другой дизайн или удалите логотип.','qrFailed':'Не удалось отсканировать QR-код','qrFailedHint':'Приложение попыталось проверить созданное изображение QR, но не смогло его распознать. Попробуйте простой дизайн, более высокий контраст или уменьшите логотип.','ok':'ОК','name':'Имя','data':'Данные','subject':'Тема','message':'Сообщение','ssid':'Название Wi‑Fi','password':'Пароль','security':'Защита','lat':'Широта','lon':'Долгота','address':'Адрес','photo':'Выбрать фото','logo':'Логотип в QR','logoHint':'По желанию: вставьте картинку из галереи в центр QR','photoSelected':'Логотип выбран • коррекция H','removeLogo':'Удалить логотип','photoError':'Не удалось открыть это изображение','saved':'PNG сохранён в галерею','permission':'Разрешите доступ к галерее','preview':'Ваш QR-код','ready':'Готов к сохранению','logoSize':'Размер логотипа','lowContrastQr':'Низкий контраст: выберите более тёмный цвет QR.','lowContrastBg':'Низкий контраст: выберите более светлый фон.','contrastWarning':'Предупреждение: низкий контраст QR и фона — сканирование может быть затруднено.','none':'Без защиты','designs':'Дизайн QR-кода','classic':'Классика','neon':'Неон','sunset':'Закат','mint':'Мята','violet':'Фиолетовый'},
    'English': {'title':'QR Studio','subtitle':'Create • Customize • Save','type':'QR code type','url':'URL','text':'Text','phone':'Phone','wifi':'Wi‑Fi','contact':'Contact','email':'Email','location':'Location','fg':'QR color','bg':'Background','transparent':'Transparent background','size':'Size','error':'Error correction','save':'Save PNG','share':'Share','checkQr':'Check QR','qrEmpty':'QR data is empty.','qrReadable':'QR code is readable','qrMismatch':'QR code data mismatch','qrConfirmed':'The app scanned the generated QR image and confirmed that its contents match your data.','qrMismatchHint':'The QR image was read, but the decoded content does not match the original data. Try another design or remove the logo.','qrFailed':'QR code could not be scanned','qrFailedHint':'The app tried to scan the actual generated QR image but could not decode it. Try a simpler design, stronger contrast, or a smaller logo.','ok':'OK','name':'Name','data':'Data','subject':'Subject','message':'Message','ssid':'Wi‑Fi name','password':'Password','security':'Security','lat':'Latitude','lon':'Longitude','address':'Address','photo':'Choose photo','logo':'Logo in QR','logoHint':'Optional: add an image from the gallery to the center','photoSelected':'Logo selected • correction H','removeLogo':'Remove logo','photoError':'Could not open this image','saved':'PNG saved to gallery','permission':'Please allow gallery access','preview':'Your QR code','ready':'Ready to save','logoSize':'Logo size','lowContrastQr':'Low contrast: choose a darker QR color.','lowContrastBg':'Low contrast: choose a lighter background.','contrastWarning':'Warning: QR and background contrast is low — scanning may be difficult.','none':'No security','designs':'QR design','classic':'Classic','green':'Green style','social':'Blue corners','maze':'Geometric','gold':'Gold frame','pink':'Pink frame','red':'Red style','neon':'Neon','sunset':'Sunset','mint':'Mint','violet':'Violet'},
    'Deutsch': {'title':'QR Studio','subtitle':'Erstellen • Anpassen • Speichern','type':'QR-Code-Typ','url':'URL','text':'Text','phone':'Telefon','wifi':'WLAN','contact':'Kontakt','email':'E-Mail','location':'Standort','fg':'QR-Farbe','bg':'Hintergrund','transparent':'Transparenter Hintergrund','size':'Größe','error':'Fehlerkorrektur','save':'PNG speichern','share':'Teilen','checkQr':'QR prüfen','qrEmpty':'Die QR-Daten sind leer.','qrReadable':'QR-Code ist lesbar','qrMismatch':'QR-Code-Inhalt stimmt nicht überein','qrConfirmed':'Die App hat das erzeugte QR-Bild gescannt und bestätigt, dass der Inhalt mit den ursprünglichen Daten übereinstimmt.','qrMismatchHint':'Das QR-Bild wurde gelesen, aber der Inhalt stimmt nicht mit den ursprünglichen Daten überein. Versuchen Sie ein anderes Design oder entfernen Sie das Logo.','qrFailed':'QR-Code konnte nicht gescannt werden','qrFailedHint':'Das erzeugte QR-Bild konnte nicht gelesen werden. Versuchen Sie ein einfacheres Design, stärkeren Kontrast oder ein kleineres Logo.','ok':'OK','name':'Name','data':'Daten','subject':'Betreff','message':'Nachricht','ssid':'WLAN-Name','password':'Passwort','security':'Sicherheit','lat':'Breitengrad','lon':'Längengrad','address':'Adresse','photo':'Foto auswählen','logo':'Logo im QR','logoHint':'Optional: Bild aus der Galerie in die Mitte einfügen','photoSelected':'Logo ausgewählt • Korrektur H','removeLogo':'Logo entfernen','photoError':'Bild konnte nicht geöffnet werden','saved':'PNG in Galerie gespeichert','permission':'Bitte Galeriezugriff erlauben','preview':'Ihr QR-Code','ready':'Bereit zum Speichern','logoSize':'Logogröße','lowContrastQr':'Zu geringer Kontrast: Wählen Sie eine dunklere QR-Farbe.','lowContrastBg':'Zu geringer Kontrast: Wählen Sie einen helleren Hintergrund.','contrastWarning':'Warnung: Der Kontrast zwischen QR und Hintergrund ist niedrig — das Scannen kann schwierig sein.','none':'Keine Sicherheit','designs':'QR-Design','classic':'Klassisch','neon':'Neon','sunset':'Sonnenuntergang','mint':'Minze','violet':'Violett'},
    'ქართული': {'title':'QR Studio','subtitle':'შექმენი • მოარგე • შეინახე','type':'QR კოდის ტიპი','url':'URL','text':'ტექსტი','phone':'ტელეფონი','wifi':'Wi‑Fi','contact':'კონტაქტი','email':'ელფოსტა','location':'გეოლოკაცია','fg':'QR ფერი','bg':'ფონი','transparent':'გამჭვირვალე ფონი','size':'ზომა','error':'შეცდომის გასწორება','save':'PNG შენახვა','share':'გაზიარება','checkQr':'QR-ის შემოწმება','qrEmpty':'QR კოდის მონაცემები ცარიელია.','qrReadable':'QR კოდი იკითხება','qrMismatch':'QR კოდის მონაცემები არ ემთხვევა','qrConfirmed':'აპმა დაასკანერა შექმნილი QR გამოსახულება და დაადასტურა, რომ შიგთავსი საწყის მონაცემებს ემთხვევა.','qrMismatchHint':'QR გამოსახულება წაიკითხა, მაგრამ მონაცემები საწყისს არ ემთხვევა. სცადეთ სხვა დიზაინი ან წაშალეთ ლოგო.','qrFailed':'QR კოდის წაკითხვა ვერ მოხერხდა','qrFailedHint':'აპმა სცადა შექმნილი QR გამოსახულების წაკითხვა, მაგრამ ვერ შეძლო. სცადეთ მარტივი დიზაინი, უფრო მაღალი კონტრასტი ან პატარა ლოგო.','ok':'კარგი','name':'სახელი','data':'მონაცემები','subject':'თემა','message':'შეტყობინება','ssid':'Wi‑Fi სახელი','password':'პაროლი','security':'დაცვა','lat':'გრძედი','lon':'განედი','address':'მისამართი','photo':'ფოტოს არჩევა','logo':'ლოგო QR-ში','logoHint':'სურვილისამებრ: გალერეიდან სურათი ჩასვით QR-ის ცენტრში','photoSelected':'ლოგო არჩეულია • კორექცია H','removeLogo':'ლოგოს წაშლა','photoError':'სურათი ვერ გაიხსნა','saved':'PNG გალერეაში შეინახა','permission':'გთხოვთ დაუშვათ გალერეაზე წვდომა','preview':'თქვენი QR კოდი','ready':'მზადაა შესანახად','logoSize':'ლოგოს ზომა','lowContrastQr':'კონტრასტი ძალიან დაბალია: აირჩიეთ უფრო მუქი QR ფერი.','lowContrastBg':'კონტრასტი ძალიან დაბალია: აირჩიეთ უფრო ღია ფონი.','contrastWarning':'გაფრთხილება: QR-სა და ფონს შორის კონტრასტი დაბალია — სკანირება შეიძლება გართულდეს.','none':'დაცვის გარეშე','designs':'QR დიზაინი','classic':'კლასიკური','neon':'ნეონი','sunset':'მზის ჩასვლა','mint':'პიტნა','violet':'იისფერი'}
  };

  final designNames = const {
    'Русский': {
      'brand_instagram':'Instagram','brand_facebook':'Facebook','brand_tiktok':'TikTok','brand_youtube':'YouTube','brand_x':'X','brand_whatsapp':'WhatsApp','brand_telegram':'Telegram','brand_snapchat':'Snapchat','brand_discord':'Discord','brand_linkedin':'LinkedIn',
      'shape_round_dots':'Круглые точки','shape_diamond':'Ромбы','shape_hexagon':'Шестиугольники','shape_rounded_squares':'Скруглённые','shape_droplet':'Капли','shape_stars':'Звёзды','shape_honeycomb':'Соты','shape_wave':'Волны','shape_lines':'Линии','shape_frame':'Рамка'
    },
    'English': {
      'brand_instagram':'Instagram','brand_facebook':'Facebook','brand_tiktok':'TikTok','brand_youtube':'YouTube','brand_x':'X','brand_whatsapp':'WhatsApp','brand_telegram':'Telegram','brand_snapchat':'Snapchat','brand_discord':'Discord','brand_linkedin':'LinkedIn',
      'shape_round_dots':'Round dots','shape_diamond':'Diamond','shape_hexagon':'Hexagon','shape_rounded_squares':'Rounded squares','shape_droplet':'Droplet','shape_stars':'Stars','shape_honeycomb':'Honeycomb','shape_wave':'Wave','shape_lines':'Lines','shape_frame':'Frame'
    },
    'Deutsch': {
      'brand_instagram':'Instagram','brand_facebook':'Facebook','brand_tiktok':'TikTok','brand_youtube':'YouTube','brand_x':'X','brand_whatsapp':'WhatsApp','brand_telegram':'Telegram','brand_snapchat':'Snapchat','brand_discord':'Discord','brand_linkedin':'LinkedIn',
      'shape_round_dots':'Runde Punkte','shape_diamond':'Diamant','shape_hexagon':'Sechsecke','shape_rounded_squares':'Abgerundet','shape_droplet':'Tropfen','shape_stars':'Sterne','shape_honeycomb':'Waben','shape_wave':'Wellen','shape_lines':'Linien','shape_frame':'Rahmen'
    },
    'ქართული': {
      'brand_instagram':'Instagram','brand_facebook':'Facebook','brand_tiktok':'TikTok','brand_youtube':'YouTube','brand_x':'X','brand_whatsapp':'WhatsApp','brand_telegram':'Telegram','brand_snapchat':'Snapchat','brand_discord':'Discord','brand_linkedin':'LinkedIn',
      'shape_round_dots':'მრგვალი წერტილები','shape_diamond':'რომბები','shape_hexagon':'ექვსკუთხედები','shape_rounded_squares':'მომრგვალებული','shape_droplet':'წვეთები','shape_stars':'ვარსკვლავები','shape_honeycomb':'ფიჭა','shape_wave':'ტალღები','shape_lines':'ხაზები','shape_frame':'ჩარჩო'
    }
  };

  String t(String k) => designNames[lang]?[k] ?? labels[lang]![k] ?? k;
  String v(String k) => c[k]!.text.trim();
  double _luminance(Color color) {
    double channel(int value) {
      final v = value / 255.0;
      return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) * ((v + 0.055) / 1.055) * ((v + 0.055) / 1.055);
    }
    return 0.2126 * channel(color.red) + 0.7152 * channel(color.green) + 0.0722 * channel(color.blue);
  }

  double _contrast(Color a, Color b) {
    final la = _luminance(a), lb = _luminance(b);
    final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }
 
  int get errorLevel => (photoImage != null || selectedDesign.startsWith('brand_')) ? 2 : (const {'L':1,'M':0,'Q':3,'H':2}[error] ?? 0);

  @override void initState() {
    super.initState();
    _loadPreferences();
    // Queue the launch interstitial immediately. If AdMob takes longer to respond,
    // show it when it eventually loads instead of silently skipping the launch ad.
    _pendingInterstitial = true;
    _initializeAds();
    _mainInputFocusNode.addListener(() {
      if (mounted) setState(() => _mainInputFocused = _mainInputFocusNode.hasFocus);
    });
    _scanLineController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
  }
  @override void dispose() { _bannerRetryTimer?.cancel(); _interstitialRetryTimer?.cancel(); _bannerAd?.dispose(); _interstitialAd?.dispose(); _logoRefreshTimer?.cancel(); _scanLineController.dispose(); _mainInputFocusNode.dispose(); scannerController.dispose(); photoImage?.dispose(); qrLogoImage?.dispose(); for (final x in c.values) x.dispose(); super.dispose(); }

  Future<ui.Image> _makeQrLogo(ui.Image source, Color borderColor) async {
    const canvasSize = 1000.0;
    const border = 20.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..filterQuality = FilterQuality.high;
    canvas.drawRect(const Rect.fromLTWH(0, 0, canvasSize, canvasSize), Paint()..color = borderColor);
    final sw = source.width.toDouble();
    final sh = source.height.toDouble();
    final inner = canvasSize - border * 2;
    final scale = (inner / sw).clamp(0.0, inner / sh);
    final dw = sw * scale;
    final dh = sh * scale;
    final dst = Rect.fromLTWH((canvasSize - dw) / 2, (canvasSize - dh) / 2, dw, dh);
    canvas.drawImageRect(source, Rect.fromLTWH(0, 0, sw, sh), dst, paint);
    final picture = recorder.endRecording();
    return picture.toImage(canvasSize.toInt(), canvasSize.toInt());
  }

  String get data {
    switch (type) {
      case QRType.url: return _normalizeWebUrl(v('main'));
      case QRType.text: return v('main');
      case QRType.phone: return 'tel:' + v('phone');
      case QRType.wifi:
        final s = security == 'None' ? 'nopass' : security;
        String e(String x) => x.replaceAll(r'\', r'\\').replaceAll(';', r'\;').replaceAll(':', r'\:').replaceAll(',', r'\,');
        return 'WIFI:T:' + s + ';S:' + e(v('ssid')) + ';P:' + e(v('password')) + ';;';
      case QRType.contact: return 'BEGIN:VCARD\nVERSION:3.0\nFN:' + v('name') + '\nTEL:' + v('phone') + '\nEMAIL:' + v('email') + '\nEND:VCARD';
      case QRType.email: return 'mailto:' + v('email') + '?subject=' + Uri.encodeComponent(v('subject')) + '&body=' + Uri.encodeComponent(v('message'));
      case QRType.location: return 'geo:' + v('lat') + ',' + v('lon') + '?q=' + Uri.encodeComponent(v('address'));
    }
  }

  Future<void> choosePhoto() async {
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x == null) return;
    try {
      final b = await x.readAsBytes();
      final codec = await ui.instantiateImageCodec(b);
      final frame = await codec.getNextFrame();
      final old = photoImage;
      final oldQr = qrLogoImage;
      if (!mounted) { frame.image.dispose(); return; }
      setState(() {
        photoBytes = b;
        photoImage = frame.image;
        qrLogoImage = null;
        error = 'H';
      });
      final prepared = await _makeQrLogo(frame.image, transparentBg ? Colors.transparent : bg);
      if (!mounted) { prepared.dispose(); return; }
      setState(() {
        qrLogoImage = prepared;
      });
      old?.dispose();
      oldQr?.dispose();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content:Text(t('photoError'))),
        );
      }
    }
  }

  void removePhoto() {
    final old = photoImage;
    final oldQr = qrLogoImage;
    setState(() {
      photoBytes = null;
      photoImage = null;
      qrLogoImage = null;
    });
    old?.dispose();
    oldQr?.dispose();
  }

  Future<Uint8List?> pngBytes() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final painter = StyledQrPainter(
      data: data.isEmpty ? ' ' : data,
      foreground: fg,
      background: transparentBg ? Colors.transparent : bg,
      design: selectedDesign,
      logo: photoImage,
      logoScale: logoScale,
      errorLevel: errorLevel,
      eyeStyle: selectedEyeStyle,
      logoOpacity: logoOpacity,
    );
    painter.paint(canvas, Size(size, size));
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.round(), size.round());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);    image.dispose();    picture.dispose();
    return bytes?.buffer.asUint8List();
  }

  Future<void> savePng() async {
    // Saving is independent from the optional scanability check.
    final b = await pngBytes(); if (b == null) return;
    try {
      if (!await Gal.hasAccess()) {
        final ok = await Gal.requestAccess();
        if (!ok) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(t('permission')))); return; }
      }
      await Gal.putImageBytes(b, album:'QR Studio');
      _onQrSaved();
      try { await const MethodChannel('qr_studio_notifications').invokeMethod('showSavedNotification'); } catch (_) {}
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(t('saved'))));
    } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(t('permission')))); }
  }

  Future<void> sharePng() async {
    final b = await pngBytes(); if (b == null) return;
    final dir = await getTemporaryDirectory();
    final f = File(dir.path + '/QR_Studio.png');
    await f.writeAsBytes(b);
    await Share.shareXFiles([XFile(f.path)], text:'QR Studio');
  }

  @override
  Widget build(BuildContext context) {
    if (_preferencesLoaded && _showWelcome && !_welcomeDialogScheduled) {
      _welcomeDialogScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _showWelcome) _showWelcomeDialog();
      });
    }
    if (!_preferencesLoaded) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner:false, themeMode:themeMode,
      theme:ThemeData(useMaterial3:true, brightness:Brightness.light, scaffoldBackgroundColor:const Color(0xFFE8F5FF), colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xFF2B7FFF))),
      darkTheme:ThemeData(
         useMaterial3:true,
         brightness:Brightness.dark,
         scaffoldBackgroundColor:const Color(0xFF171D25),
         canvasColor:const Color(0xFF252D37),
         cardColor:const Color(0xFF252D37),
         dialogBackgroundColor:const Color(0xFF303A46),
         bottomSheetTheme:const BottomSheetThemeData(
           backgroundColor:Color(0xFF303A46),
           modalBackgroundColor:Color(0xFF303A46),
         ),
         popupMenuTheme:const PopupMenuThemeData(
           color:Color(0xFF303A46),
           surfaceTintColor:Colors.transparent,
         ),
         drawerTheme:const DrawerThemeData(
           backgroundColor:Color(0xFF252D37),
           surfaceTintColor:Colors.transparent,
         ),
         colorScheme:ColorScheme.fromSeed(
           seedColor:const Color(0xFF1E9BFF),
           brightness:Brightness.dark,
         ).copyWith(
           surface:const Color(0xFF252D37),
           surfaceContainerLowest:const Color(0xFF171D25),
           surfaceContainerLow:const Color(0xFF202832),
           surfaceContainer:const Color(0xFF252D37),
           surfaceContainerHigh:const Color(0xFF303A46),
           surfaceContainerHighest:const Color(0xFF394451),
           onSurface:const Color(0xFFF1F3F5),
           onSurfaceVariant:const Color(0xFFBBC4CE),
           outline:const Color(0xFF687583),
           outlineVariant:const Color(0xFF4B5663),
         ),
         dividerColor:const Color(0xFF46515E),
         inputDecorationTheme:const InputDecorationTheme(
           filled:true,
           fillColor:Color(0xFF252D37),
           labelStyle:TextStyle(color:Color(0xFFBBC4CE)),
           hintStyle:TextStyle(color:Color(0xFF929EAA)),
         ),
       ),
      home:Scaffold(
        bottomNavigationBar: _bannerLoaded && _bannerAd != null
            ? SafeArea(
                top: false,
                child: SizedBox(
                  height: _bannerAd!.size.height.toDouble(),
                  width: _bannerAd!.size.width.toDouble(),
                  child: Center(child: AdWidget(ad: _bannerAd!)),
                ),
              )
            : null,
        body:SafeArea(child:LayoutBuilder(builder:(ctx,box) {
          final wide = box.maxWidth > 820;
          return SingleChildScrollView(
            padding:EdgeInsets.fromLTRB(wide ? 28 : 16,8,wide ? 28 : 16,16),
            child:Center(child:ConstrainedBox(
              constraints:const BoxConstraints(maxWidth:980),
              child:wide ? (isScannerOpen ? Column(children:[header(),const SizedBox(height:8),modeSelector(),const SizedBox(height:10),scannerView()]) : Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:form()),const SizedBox(width:24),Expanded(child:preview())])) : Column(children:[header(),const SizedBox(height:12),modeSelector(),const SizedBox(height:16),if(isScannerOpen) scannerView() else ...[formBody(),const SizedBox(height:10),previewCard(),const SizedBox(height:7),checkQrButton(),const SizedBox(height:10),footerButtons()]]),
            )),
          );
        })),
      ),
    );
  }

  Widget header() => Container(
    padding:const EdgeInsets.symmetric(horizontal:12,vertical:10),
    decoration:BoxDecoration(
      color:Theme.of(context).brightness==Brightness.light ? const Color(0xFFD2EAFF) : const Color(0xFF12345A),
      borderRadius:BorderRadius.circular(20),
      border:Border.all(color:const Color(0xFF8CCBFF).withOpacity(.75),width:1.2),      boxShadow:[BoxShadow(color:const Color(0xFF3B9DFF).withOpacity(.10),blurRadius:14,offset:const Offset(0,4))],
    ),
    child:Row(children:[
      logo(54), const SizedBox(width:11),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        ShaderMask(shaderCallback:(r)=>const LinearGradient(colors:[Color(0xFF0077CC),Color(0xFF6545C4),Color(0xFFDB4F9B)]).createShader(r),child:Text(t('title'),style:const TextStyle(fontSize:25,fontWeight:FontWeight.w800,color:Colors.white))),
        Text(t('subtitle'),style:const TextStyle(fontSize:11,color:Colors.black)),
      ])),
      languageButton(), const SizedBox(width:4),
      IconButton(onPressed:(){setState(()=>themeMode=themeMode==ThemeMode.light?ThemeMode.dark:ThemeMode.light);_savePreferences();},icon:Icon(themeMode==ThemeMode.light?Icons.dark_mode:Icons.light_mode)),
    ]),
  );

  Widget logo(double s) => Container(
    width:s,height:s,padding:const EdgeInsets.all(2),
    decoration:BoxDecoration(shape:BoxShape.circle,gradient:const LinearGradient(colors:[Color(0xFF00D5FF),Color(0xFF9B00FF),Color(0xFFFF7A00)]),boxShadow:[BoxShadow(color:const Color(0xFF00BFFF).withOpacity(.18),blurRadius:12)]),
    child:ClipOval(child:Image.asset('app_icon.png',fit:BoxFit.cover)),
  );

  Widget languageButton() {
    const flags={'Русский':'🇷🇺','English':'🇬🇧','Deutsch':'🇩🇪','ქართული':'🇬🇪'};
    return PopupMenuButton<String>(
      onSelected:(x){setState(()=>lang=x);_savePreferences();},
      itemBuilder:(_)=>flags.entries.map((e)=>PopupMenuItem(value:e.key,child:Text(e.value + '  ' + e.key))).toList(),
      child:Row(children:[Text(flags[lang]!,style:const TextStyle(fontSize:20)),const Icon(Icons.keyboard_arrow_down)]),
    );
  }

  Widget form() => Column(children:[header(),const SizedBox(height:8),modeSelector(),const SizedBox(height:10),formBody(),const SizedBox(height:10),footerButtons()]);

  String scannerText(String key) {
    const strings = {
      'Русский': {'studio':'QR Studio','scan':'QR Scan','title':'Сканер QR-кодов','hint':'Наведите камеру на QR-код','result':'Результат сканирования','again':'Сканировать ещё','open':'Открыть ссылку','empty':'QR-код не содержит текста','gallery':'Галерея','scanButton':'Сканировать','frameHint':'Разместите код внутри рамки','galleryError':'Не удалось прочитать QR-код на этом фото','torchOn':'Выключить фонарик','torchOff':'Включить фонарик'},
      'English': {'studio':'QR Studio','scan':'QR Scan','title':'QR Code Scanner','hint':'Point the camera at a QR code','result':'Scan result','again':'Scan again','open':'Open link','empty':'This QR code contains no text','gallery':'Gallery','scanButton':'Scan','frameHint':'Place the code inside the frame','galleryError':'Could not read a QR code from this photo','torchOn':'Turn flashlight off','torchOff':'Turn flashlight on'},
      'Deutsch': {'studio':'QR Studio','scan':'QR Scan','title':'QR-Code-Scanner','hint':'Richte die Kamera auf einen QR-Code','result':'Scan-Ergebnis','again':'Erneut scannen','open':'Link öffnen','empty':'Dieser QR-Code enthält keinen Text','gallery':'Galerie','scanButton':'Scannen','frameHint':'Platziere den Code innerhalb des Rahmens','galleryError':'QR-Code auf diesem Foto konnte nicht gelesen werden','torchOn':'Taschenlampe ausschalten','torchOff':'Taschenlampe einschalten'},
      'ქართული': {'studio':'QR Studio','scan':'QR Scan','title':'QR კოდის სკანერი','hint':'მიმართეთ კამერა QR კოდისკენ','result':'სკანირების შედეგი','again':'ხელახლა სკანირება','open':'ბმულის გახსნა','empty':'QR კოდი ტექსტს არ შეიცავს','gallery':'გალერეა','scanButton':'სკანირება','frameHint':'მოათავსეთ კოდი ჩარჩოს შიგნით','galleryError':'ფოტოზე QR კოდის წაკითხვა ვერ მოხერხდა','torchOn':'ფანრის გამორთვა','torchOff':'ფანრის ჩართვა'},
    };
    return strings[lang]?[key] ?? strings['English']![key]!;
  }

  Widget modeSelector() => Row(children:[
    Expanded(child:FilledButton.icon(
      onPressed:()=>setState(()=>isScannerOpen=false),
      icon:const Icon(Icons.qr_code_2),
      label:Text(scannerText('studio'),maxLines:1,overflow:TextOverflow.ellipsis),
      style:FilledButton.styleFrom(minimumSize:const Size.fromHeight(48),backgroundColor:!isScannerOpen?const Color(0xFF1877D2):Theme.of(context).colorScheme.surfaceVariant,foregroundColor:!isScannerOpen?Colors.white:Theme.of(context).colorScheme.onSurfaceVariant),
    )),
    const SizedBox(width:10),
    Expanded(child:FilledButton.icon(
      onPressed:(){ setState(() { isScannerOpen=true; scannedValue=null; }); },
      icon:const Icon(Icons.qr_code_scanner),
      label:Text(scannerText('scan'),maxLines:1,overflow:TextOverflow.ellipsis),
      style:FilledButton.styleFrom(minimumSize:const Size.fromHeight(48),backgroundColor:isScannerOpen?const Color(0xFF1877D2):Theme.of(context).colorScheme.surfaceVariant,foregroundColor:isScannerOpen?Colors.white:Theme.of(context).colorScheme.onSurfaceVariant),
    )),
  ]);

  String _normalizeWebUrl(String input) {
    final value = input.trim();
    if (value.isEmpty) return '';
    final parsed = Uri.tryParse(value);
    if (parsed != null && parsed.hasScheme) return value;
    return 'https://$value';
  }

  // Prefer the scanner's original payload bytes when they are valid UTF-8.
  // This preserves Georgian, Cyrillic and other non-Latin text instead of
  // relying only on a platform-decoded rawValue string.
  String _readBarcodeText(Barcode barcode) {
    final bytes = barcode.rawBytes;
    if (bytes != null && bytes.isNotEmpty) {
      try {
        final decoded = utf8.decode(bytes, allowMalformed: false);
        if (decoded.trim().isNotEmpty) return decoded;
      } catch (_) {
        // Fall back to ML Kit's decoded value for non-UTF-8/binary payloads.
      }
    }
    return barcode.rawValue ?? '';
  }

  Future<void> _handleScannedValue(String value) async {
    final cleaned = value.trim();
    if (cleaned.isEmpty || !mounted) return;
    setState(() => scannedValue = cleaned);

    final uri = Uri.tryParse(cleaned);
    if (uri == null ||
        !uri.hasScheme ||
        !const {'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty) {
      return;
    }

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Keep the scan result visible so the user can still open or copy it.
    }
  }

  Future<void> chooseScanImage() async {
    try {
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) throw StateError('Image decode failed');
      final rgba = decodedImage.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
      final pixels = Int32List(decodedImage.width * decodedImage.height);
      for (var i = 0; i < pixels.length; i++) {
        final offset = i * 4;
        final alpha = rgba[offset + 3];
        final r = ((rgba[offset] * alpha) + (255 * (255 - alpha))) ~/ 255;
        final g = ((rgba[offset + 1] * alpha) + (255 * (255 - alpha))) ~/ 255;
        final b = ((rgba[offset + 2] * alpha) + (255 * (255 - alpha))) ~/ 255;
        pixels[i] = 0xFF000000 | (r << 16) | (g << 8) | b;
      }
      final source = RGBLuminanceSource(decodedImage.width, decodedImage.height, pixels);
      final result = QRCodeReader().decode(BinaryBitmap(HybridBinarizer(source)));
      if (mounted) await _handleScannedValue(result.text);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(scannerText('galleryError'))));
    }
  }

  Future<void> zoomScannerIn() async {
    // Start with moderate zoom (50% of the camera's normalized zoom range).
    // This keeps the scan frame compact without the excessive maximum zoom.
    try {
      await scannerController.setZoomScale(0.5);
    } catch (_) {
      // Keep scanning normally on cameras that do not support zoom.
    }
  }

  Future<void> toggleScannerTorch() async {
    try {
      await scannerController.toggleTorch();
      if (mounted) setState(() => torchEnabled = !torchEnabled);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(scannerText('torchOff'))));
    }
  }

  Widget scannerView() => Container(
    constraints: const BoxConstraints(minHeight: 650),
    decoration: BoxDecoration(
      color: const Color(0xFF10151D),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFF168FFF).withOpacity(.35)),
      boxShadow: [BoxShadow(color: const Color(0xFF078BFF).withOpacity(.10), blurRadius: 24)],
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF0B1421), Color(0xFF111A27)]),
          border: Border(bottom: BorderSide(color: Color(0xFF24354A))),
        ),
        child: Row(children: [
          IconButton(
            tooltip: scannerText('studio'),
            onPressed: () => setState(() { isScannerOpen = false; torchEnabled = false; }),
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF08A9FF), size: 29),
          ),
          const SizedBox(width: 3),
          const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF08A9FF), size: 34),
          const SizedBox(width: 10),
          Expanded(child: RichText(text: const TextSpan(
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            children: [TextSpan(text: 'QR ', style: TextStyle(color: Colors.white)), TextSpan(text: 'Scan', style: TextStyle(color: Color(0xFF08A9FF)))],
          ))),
          Container(
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF286EFF), width: 2)),
            child: IconButton(
              tooltip: scannerText(torchEnabled ? 'torchOn' : 'torchOff'),
              onPressed: toggleScannerTorch,
              icon: Icon(torchEnabled ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded, color: torchEnabled ? const Color(0xFFFFD45C) : Colors.white, size: 27),
            ),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 26, 18, 20),
        child: Column(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 410,
              width: double.infinity,
              child: Stack(fit: StackFit.expand, children: [
                if (scannedValue == null)
                  MobileScanner(
                    controller: scannerController,
                    onDetect: (capture) {
                      if (scannedValue != null) return;
                      for (final barcode in capture.barcodes) {
                        final value = _readBarcodeText(barcode);
                        if (value != null && value.trim().isNotEmpty) {
                          unawaited(_handleScannedValue(value));
                          break;
                        }
                      }
                    },
                  )
                else
                  Container(color: const Color(0xFF20252D), child: const Center(child: Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 58))),
                if (scannedValue == null) ...[
                  Container(color: Colors.black.withOpacity(.16)),
                  Center(child: Container(                    width: 230, height: 230,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(.035), borderRadius: BorderRadius.circular(18)),
                  )),
                  Center(child: SizedBox(width: 230, height: 230, child: CustomPaint(painter: ScannerCornersPainter()))),
                  Center(child: SizedBox(
                    width: 230,
                    height: 230,
                    child: AnimatedBuilder(
                      animation: _scanLineController,
                      builder: (context, child) => Align(
                        alignment: Alignment(0, -1 + (2 * _scanLineController.value)),
                        child: Container(
                          height: 3,
                          width: 230,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1CA9FF),
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: [BoxShadow(color: const Color(0xFF168FFF).withOpacity(.95), blurRadius: 10, spreadRadius: 2)],
                          ),
                        ),
                      ),
                    ),
                  )),
                ] else
                  Padding(padding: const EdgeInsets.all(18), child: Center(child: Text(scannedValue!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)))),
              ]),
            ),          ),
          const SizedBox(height: 14),
          Text(scannedValue == null ? scannerText('frameHint') : scannerText('result'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
          if (scannedValue != null) ...[
            const SizedBox(height: 10),
            SelectableText(scannedValue!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF8FD8FF))),
            const SizedBox(height: 10),
            if (Uri.tryParse(scannedValue!)?.hasScheme == true && ['http','https'].contains(Uri.tryParse(scannedValue!)!.scheme.toLowerCase()))
              FilledButton.icon(onPressed: () async { final uri = Uri.tryParse(scannedValue!); if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication); }, icon: const Icon(Icons.open_in_new), label: Text(scannerText('open'))),
            OutlinedButton.icon(onPressed: () => setState(() => scannedValue = null), icon: const Icon(Icons.refresh), label: Text(scannerText('again'))),
          ],
          const SizedBox(height: 68),
          Center(child: _scannerAction(
            icon: Icons.photo_library_outlined,
            label: scannerText('gallery'),
            colors: const [Color(0xFF8E45FF), Color(0xFF5424B9)],
            onTap: chooseScanImage,
            diameter: 66,
            iconSize: 29,
          )),
        ]),
      ),
    ]),
  );

  Widget _scannerAction({required IconData icon, required String label, required List<Color> colors, required VoidCallback onTap, double diameter = 100, double iconSize = 38}) => Column(children: [
    SizedBox(
      width: diameter, height: diameter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
          border: Border.all(color: colors.first, width: 2.5),
          boxShadow: [BoxShadow(color: colors.first.withOpacity(.25), blurRadius: 15, spreadRadius: 1)],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(onTap: onTap, customBorder: const CircleBorder(), child: Icon(icon, color: Colors.white, size: iconSize)),
        ),
      ),
    ),
    const SizedBox(height: 10),
    Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
  ]);


  // Form-panel colors follow the selected app theme. This State context is
  // above MaterialApp, so Theme.of(context) here would read the outer theme.
  bool get isDarkTheme => themeMode == ThemeMode.dark;
  Color get panelSurfaceColor => isDarkTheme ? const Color(0xFF171D25) : const Color(0xFFFFFFFF);
  Color get panelOutlineColor => isDarkTheme ? const Color(0xFF687583) : const Color(0xFFB8C4D0);
  Color get panelTextColor => isDarkTheme ? const Color(0xFFF1F3F5) : const Color(0xFF20252B);
  Color get panelMutedColor => isDarkTheme ? const Color(0xFFBBC4CE) : const Color(0xFF687582);

  Widget formBody() => Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Text(t('type'),style:TextStyle(fontSize:16,fontWeight:FontWeight.w700,color:panelTextColor)),const SizedBox(height:6),
    Wrap(spacing:7,runSpacing:7,children:[QRType.url,QRType.text,QRType.phone,QRType.wifi,QRType.contact,QRType.email,QRType.location].map(typeChip).toList()),
    const SizedBox(height:8),
    const SizedBox(height:7),specific(),
    if(type==QRType.wifi) ...[
      const SizedBox(height:2),
      DropdownButtonFormField<String>(value:security,decoration:fieldDecoration(t('security')),items:['WPA','WEP','None'].map((x)=>DropdownMenuItem(value:x,child:Text(x=='None'?t('none'):x))).toList(),onChanged:(x)=>setState(()=>security=x!)),
    ],
    if(type==QRType.location) ...[input('lat',t('lat'),keyboard:TextInputType.number),input('lon',t('lon'),keyboard:TextInputType.number),input('address',t('address'))],
    const SizedBox(height:2),
    Row(children:[
      Expanded(child:OutlinedButton.icon(
        onPressed:()=>setState(()=>showColorPanel=!showColorPanel),
        icon:Icon(showColorPanel ? Icons.expand_less : Icons.palette_outlined,size:18),
        label:Text(lang == 'Русский' ? 'Цвета' : lang == 'Deutsch' ? 'Farben' : lang == 'ქართული' ? 'ფერები' : 'Colors',maxLines:1,overflow:TextOverflow.ellipsis),
        style:OutlinedButton.styleFrom(
          foregroundColor:panelTextColor,
          side:BorderSide(color:panelOutlineColor),
          minimumSize:const Size.fromHeight(46),
          padding:const EdgeInsets.symmetric(horizontal:8),
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(7)),
        ),
      )),
      const SizedBox(width:8),
      Expanded(child:OutlinedButton.icon(
        onPressed:()=>setState(()=>showDesignPanel=!showDesignPanel),
        icon:Icon(showDesignPanel ? Icons.expand_less : Icons.qr_code_2,size:18),
        label:Text(lang == 'Русский' ? 'Дизайны' : lang == 'Deutsch' ? 'Designs' : lang == 'ქართული' ? 'დიზაინები' : 'Designs',maxLines:1,overflow:TextOverflow.ellipsis),
        style:OutlinedButton.styleFrom(
          foregroundColor:panelTextColor,
          side:BorderSide(color:panelOutlineColor),
          minimumSize:const Size.fromHeight(46),
          padding:const EdgeInsets.symmetric(horizontal:8),
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(7)),
        ),
      )),
    ]),
    if(showColorPanel) ...[
      const SizedBox(height:7),
      colorEditor(),
    ],
    if(showDesignPanel) ...[
      const SizedBox(height:7),
      Container(
      width:double.infinity,
      padding:const EdgeInsets.fromLTRB(10,10,10,12),
      decoration:BoxDecoration(
        color:panelSurfaceColor,
        borderRadius:BorderRadius.circular(14),
        border:Border.all(color:isDarkTheme ? panelOutlineColor : const Color(0xFF5B2DFF).withOpacity(.55),width:1.4),
      ),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          const Icon(Icons.palette_outlined,size:19,color:Color(0xFF5B2DFF)),
          const SizedBox(width:7),
          Expanded(child:Text(t('designs'),style:TextStyle(fontSize:14,fontWeight:FontWeight.w800,color:panelTextColor))),
        ]),
        const SizedBox(height:9),
        Row(children:[
          Expanded(child:OutlinedButton(onPressed:()=>setState(()=>designCategory='modules'),style:OutlinedButton.styleFrom(backgroundColor:designCategory=='modules'?const Color(0xFF5B2DFF).withOpacity(.13):Colors.transparent,foregroundColor:panelTextColor,side:BorderSide(color:designCategory=='modules'?const Color(0xFF5B2DFF):panelOutlineColor),padding:const EdgeInsets.symmetric(horizontal:4,vertical:9)),child:Text(lang=='Русский'?'Внутренние точки':lang=='Deutsch'?'QR-Punkte':lang=='ქართული'?'შიდა წერტილები':'Inner dots',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700)))),
          const SizedBox(width:7),
          Expanded(child:OutlinedButton(onPressed:()=>setState(()=>designCategory='eyes'),style:OutlinedButton.styleFrom(backgroundColor:designCategory=='eyes'?const Color(0xFF5B2DFF).withOpacity(.13):Colors.transparent,foregroundColor:panelTextColor,side:BorderSide(color:designCategory=='eyes'?const Color(0xFF5B2DFF):panelOutlineColor),padding:const EdgeInsets.symmetric(horizontal:4,vertical:9)),child:Text(lang=='Русский'?'Большие квадраты':lang=='Deutsch'?'Große Quadrate':lang=='ქართული'?'დიდი კვადრატები':'Large squares',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700)))),
        ]),
        const SizedBox(height:8),
        SizedBox(height:112,child:ListView(scrollDirection:Axis.horizontal,children:designCategory=='modules' ? [
          designOption('classic',Colors.black,Colors.white),
          designOption('shape_round_dots',Colors.black,Colors.white),
          designOption('shape_diamond',const Color(0xFF1749C8),Colors.white),
          designOption('shape_hexagon',const Color(0xFF6633AA),const Color(0xFFF8F3FF)),
          designOption('shape_rounded_squares',const Color(0xFF1678C8),Colors.white),
          designOption('shape_droplet',const Color(0xFF1267B5),const Color(0xFFF1F8FF)),
          designOption('shape_stars',const Color(0xFF5530A8),Colors.white),
          designOption('shape_honeycomb',const Color(0xFF171717),const Color(0xFFFFF9E8)),
          designOption('shape_wave',const Color(0xFF087FC3),Colors.white),
          designOption('shape_lines',const Color(0xFF222222),Colors.white),
          designOption('shape_frame',const Color(0xFF6032A8),const Color(0xFFFFFCF2)),
        ] : [
          _eyeStyleOption('square','Square'),
          _eyeStyleOption('rounded','Rounded'),
          _eyeStyleOption('circle','Circle'),
          _eyeStyleOption('diamond','Diamond'),
          _eyeStyleOption('neon','Neon'),
        ]))
      ]),
      ),
    ],
    const SizedBox(height:4),Text(t('size') + ': ' + size.round().toString() + ' px',style:TextStyle(fontSize:12,fontWeight:FontWeight.w700,color:panelTextColor)),
    SizedBox(height:36,child:SliderTheme(data:SliderTheme.of(context).copyWith(trackHeight:2,thumbShape:const RoundSliderThumbShape(enabledThumbRadius:6),overlayShape:const RoundSliderOverlayShape(overlayRadius:9)),child:Slider(min:256,max:1024,value:size,activeColor:const Color(0xFF5B2DFF),onChanged:(x)=>setState(()=>size=x)))),
    Text(t('error'),style:TextStyle(fontSize:12,fontWeight:FontWeight.w700,color:panelTextColor)),const SizedBox(height:2),
    DropdownButtonFormField<String>(value:photoImage != null ? 'H' : error,decoration:fieldDecoration(''),items:['L','M','Q','H'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:photoImage != null ? null : (x)=>setState(()=>error=x!)),
    const SizedBox(height:7),
    logoSection(),
    if (photoImage != null) ...[
      const SizedBox(height:10),
      Text(t('logoSize') + ': ' + (logoScale * 100).round().toString() + '%',
          style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700)),
      Slider(
        min:.10,
        max:.20,
        divisions:25,
        value:logoScale,
        activeColor:const Color(0xFF5B2DFF),
        onChanged:(x)=>setState(()=>logoScale=x),
      ),
      Text((lang=='Русский'?'Прозрачность логотипа':lang=='Deutsch'?'Logo-Deckkraft':lang=='ქართული'?'ლოგოს გამჭვირვალობა':'Logo opacity')+': '+(logoOpacity*100).round().toString()+'%',style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700)),
      Slider(min:.25,max:1,divisions:15,value:logoOpacity,activeColor:const Color(0xFF5B2DFF),onChanged:(x)=>setState(()=>logoOpacity=x)),
    ],
  ]);

  Widget logoSection()=>Container(
    padding:const EdgeInsets.all(7),
    decoration:BoxDecoration(
      color:panelSurfaceColor,
      borderRadius:BorderRadius.circular(10),
      border:Border.all(color:panelOutlineColor),
    ),
    child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Row(children:[
        Icon(Icons.add_photo_alternate_outlined,size:18,color:panelTextColor),
        const SizedBox(width:5),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(t('logo'),style:TextStyle(fontSize:13,fontWeight:FontWeight.w700,color:panelTextColor)),
          Text(photoImage == null ? t('logoHint') : t('photoSelected'),style:TextStyle(fontSize:10,color:panelMutedColor)),
        ])),
        if(photoImage != null)
          ClipRRect(borderRadius:BorderRadius.circular(8),child:Image.memory(photoBytes!,width:36,height:36,fit:BoxFit.cover)),
      ]),
      const SizedBox(height:4),
      Row(children:[
        Expanded(child:OutlinedButton.icon(
          onPressed:choosePhoto,
          icon:const Icon(Icons.photo_library_outlined,size:18),
          label:Text(t('photo')),
          style:OutlinedButton.styleFrom(minimumSize:const Size.fromHeight(36),padding:const EdgeInsets.symmetric(vertical:6),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(7))),
        )),
        if(photoImage != null) ...[
          const SizedBox(width:5),
          IconButton(
            onPressed:removePhoto,
            tooltip:t('removeLogo'),
            icon:const Icon(Icons.delete_outline),
            style:IconButton.styleFrom(minimumSize:const Size(36,36)),
          ),
        ],
      ]),
    ]),
  );

  // Presets change QR geometry, not just colors.
  QrEyeShape get selectedEyeShape => switch (selectedDesign) {
    'neon' => QrEyeShape.circle,
    'mint' => QrEyeShape.circle,
    _ => QrEyeShape.square,
  };

  QrDataModuleShape get selectedModuleShape => switch (selectedDesign) {
    'neon' => QrDataModuleShape.circle,
    'sunset' => QrDataModuleShape.circle,
    'violet' => QrDataModuleShape.circle,
    _ => QrDataModuleShape.square,
  };

  bool get selectedGapless => selectedDesign != 'violet';

  Widget _eyeStyleOption(String id,String label) {
    final selected=selectedEyeStyle==id;
    return GestureDetector(
      onTap:()=>setState(()=>selectedEyeStyle=id),
      child:Container(
        width:88,
        margin:const EdgeInsets.only(right:8),
        padding:const EdgeInsets.all(7),
        decoration:BoxDecoration(
          color:selected?const Color(0xFF5B2DFF).withOpacity(.12):panelSurfaceColor,
          borderRadius:BorderRadius.circular(9),
          border:Border.all(color:selected?const Color(0xFF5B2DFF):panelOutlineColor,width:selected?2:1),
        ),
        child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
          SizedBox(width:34,height:34,child:CustomPaint(painter:EyeStylePreviewPainter(id))),
          const SizedBox(height:5),
          Text(label,style:TextStyle(fontSize:10,fontWeight:FontWeight.w700,color:panelTextColor),maxLines:1,overflow:TextOverflow.ellipsis),
        ]),
      ),
    );
  }

  Widget designOption(String id, Color qrColor, Color backgroundColor) {
    final chosen = selectedDesign == id;
    return GestureDetector(
      onTap:() {
        setState(() {
          // Shape presets change geometry only. QR and background colors stay
          // under the user's separate color controls.
          selectedDesign = id;
        });
        scheduleQrLogoRefresh();
      },
      child:AnimatedContainer(
        duration:const Duration(milliseconds:160),
        width:82,
        margin:const EdgeInsets.only(right:9),
        padding:const EdgeInsets.all(7),
        decoration:BoxDecoration(
          color:panelSurfaceColor,
          borderRadius:BorderRadius.circular(12),
          border:Border.all(color:chosen ? const Color(0xFF00B89C) : panelOutlineColor,width:chosen ? 2.5 : 1),
        ),
        child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
          Container(
            width:43,height:43,
            padding:const EdgeInsets.all(3),
            decoration:const BoxDecoration(color:Colors.white,borderRadius:BorderRadius.all(Radius.circular(6))),
            child:CustomPaint(painter:ModuleStylePreviewPainter(id)),
          ),
          const SizedBox(height:4),
          Text(t(id),maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(fontSize:10,fontWeight:chosen ? FontWeight.w800 : FontWeight.w500,color:panelTextColor)),
        ]),
      ),
    );
  }

  Widget typeChip(QRType x) {
    final selected=type==x;
    final icons={QRType.url:Icons.link,QRType.text:Icons.description_outlined,QRType.phone:Icons.phone_outlined,QRType.wifi:Icons.wifi,QRType.contact:Icons.person_outline,QRType.email:Icons.mail_outline,QRType.location:Icons.location_on_outlined};
    final key=switch(x){QRType.url=>'url',QRType.text=>'text',QRType.phone=>'phone',QRType.wifi=>'wifi',QRType.contact=>'contact',QRType.email=>'email',QRType.location=>'location'};
    return GestureDetector(
      onTap:()=>setState(()=>type=x),
      child:AnimatedContainer(
        duration:const Duration(milliseconds:160),constraints:const BoxConstraints(minWidth:98,minHeight:40),padding:const EdgeInsets.symmetric(horizontal:12),
        decoration:BoxDecoration(gradient:selected?const LinearGradient(colors:[Color(0xFF00CFFF),Color(0xFF7A00FF),Color(0xFFFF1BC7)]):null,color:selected?null:panelSurfaceColor,borderRadius:BorderRadius.circular(7),border:Border.all(color:selected?Colors.transparent:panelOutlineColor)),
        child:Row(mainAxisSize:MainAxisSize.min,children:[Icon(icons[x],size:18,color:selected?Colors.white:panelMutedColor),const SizedBox(width:7),Text(t(key),style:TextStyle(fontSize:12,fontWeight:FontWeight.w600,color:selected?Colors.white:panelTextColor))]),
      ),
    );
  }

  InputDecoration fieldDecoration(String label) {
    // This State context is above MaterialApp, so Theme.of(context) does not see its darkTheme.
    // Read the selected app theme directly to ensure every shared input uses the dark colors.
    final dark = themeMode == ThemeMode.dark;
    final outline = dark ? const Color(0xFF687583) : Theme.of(context).colorScheme.outlineVariant;
    final shape = OutlineInputBorder(
      borderRadius: BorderRadius.circular(7),
      borderSide: BorderSide(color: outline, width: 1.2),
    );
    return InputDecoration(
      labelText: label.isEmpty ? null : label,
      filled: true,
      fillColor: dark ? const Color(0xFF171D25) : Theme.of(context).colorScheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      labelStyle: TextStyle(color: dark ? const Color(0xFFBBC4CE) : Theme.of(context).colorScheme.onSurfaceVariant),
      hintStyle: TextStyle(color: dark ? const Color(0xFF929EAA) : Theme.of(context).colorScheme.onSurfaceVariant),
      border: shape,
      enabledBorder: shape,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: BorderSide(color: dark ? const Color(0xFF8A98A8) : Theme.of(context).colorScheme.primary, width: 1.6),
      ),
      disabledBorder: shape,
    );
  }

  Widget input(String key,String label,{TextInputType? keyboard})=>Padding(
    padding:const EdgeInsets.only(bottom:6),
    child:TextField(
      controller:c[key],
      focusNode:key == 'main' ? _mainInputFocusNode : null,
      keyboardType:keyboard,
      onChanged:(_)=>setState((){}),
      decoration:fieldDecoration(label).copyWith(
        hintText:key == 'main' && !_mainInputFocused ? 'https://www' : null,
        hintStyle:const TextStyle(color:Color(0x66808080)),
      ),
    ),
  );

  Widget specific(){
    switch(type){
      case QRType.url:return input('main','URL');
      case QRType.text:return input('main',t('data'));
      case QRType.phone:return input('phone',t('phone'),keyboard:TextInputType.phone);
      case QRType.wifi:return Column(children:[input('ssid',t('ssid')),input('password',t('password'))]);
      case QRType.contact:return Column(children:[input('name',t('name')),input('phone',t('phone')),input('email',t('email'),keyboard:TextInputType.emailAddress)]);
      case QRType.email:return Column(children:[input('email',t('email'),keyboard:TextInputType.emailAddress),input('subject',t('subject')),input('message',t('message'))]);
      case QRType.location:return const SizedBox.shrink();
    }
  }

  Widget gradientColorBar(bool background)=>LayoutBuilder(
    builder:(context,constraints){
      final width=constraints.maxWidth;
      final current=background ? bg : fg;      return Column(
        crossAxisAlignment:CrossAxisAlignment.stretch,
        children:[
          GestureDetector(
            behavior:HitTestBehavior.opaque,
            onTapDown:(d)=>setColorFromPosition(background,d.localPosition.dx,width),            onPanStart:(d)=>setColorFromPosition(background,d.localPosition.dx,width),
            onPanUpdate:(d)=>setColorFromPosition(background,d.localPosition.dx,width),
            child:Container(
              height:48,
              decoration:BoxDecoration(
                gradient:const LinearGradient(
                  colors:[
                    Color(0xFFFF0000),Color(0xFFFFFF00),Color(0xFF00FF00),
                    Color(0xFF00FFFF),Color(0xFF0000FF),Color(0xFFFF00FF),Color(0xFFFF0000)
                  ],
                ),
                borderRadius:BorderRadius.circular(7),
              ),
              alignment:Alignment.center,
              child:Align(
                alignment:Alignment.centerLeft,
                child:Transform.translate(
                  offset:Offset((currentHue(current)/360*width).clamp(0.0,width-1),0),
                  child:Container(
                    width:24,height:24,
                    decoration:BoxDecoration(
                      shape:BoxShape.circle,
                      color:current,
                      border:Border.all(color:Colors.white,width:3),
                      boxShadow:[BoxShadow(color:Colors.black.withOpacity(.35),blurRadius:5)],
                    ),                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height:7),
          Text(
            'RGB: #' + current.value.toRadixString(16).padLeft(8,'0').substring(2).toUpperCase(),
            textAlign:TextAlign.center,
            style:TextStyle(fontSize:11,color:panelMutedColor,fontWeight:FontWeight.w600),
          ),
          const SizedBox(height:8),
          Row(
            mainAxisAlignment:MainAxisAlignment.center,
            children:[
              colorQuickButton(Colors.black, background),
              const SizedBox(width:10),
              colorQuickButton(Colors.white, background),
            ],
          ),
          if (background) ...[
            const SizedBox(height:10),
            GestureDetector(
              onTap:(){
                setState((){ transparentBg=true; });
                scheduleQrLogoRefresh();
              },
              child:Container(
                padding:const EdgeInsets.symmetric(horizontal:14,vertical:9),
                decoration:BoxDecoration(
                  color:panelSurfaceColor,
                  borderRadius:BorderRadius.circular(7),
                  border:Border.all(
                    color:transparentBg ? const Color(0xFF7A00FF) : panelOutlineColor,
                    width:transparentBg ? 2.5 : 1,
                  ),
                ),
                child:Row(
                  mainAxisSize:MainAxisSize.min,
                  children:[
                    Container(
                      width:22,height:22,
                      decoration:BoxDecoration(
                        borderRadius:BorderRadius.circular(4),
                        border:Border.all(color:panelOutlineColor),
                        gradient:const LinearGradient(
                          begin:Alignment.topLeft,end:Alignment.bottomRight,
                          colors:[Colors.white,Colors.white,Color(0xFFBDBDBD),Color(0xFFBDBDBD)],
                          stops:[0,.5,.5,1],
                        ),
                      ),
                    ),
                    const SizedBox(width:8),
                    Text(t('transparent'),style:TextStyle(fontSize:12,fontWeight:FontWeight.w700,color:panelTextColor)),
                    if(transparentBg) ...[
                      const SizedBox(width:6),
                      const Icon(Icons.check_circle,size:16,color:Color(0xFF7A00FF)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      );
    },
  );

  Widget colorQuickButton(Color color, bool background) {
    final selected = (background ? bg : fg).value == color.value;
    return GestureDetector(
      onTap:(){
        if(background){
          setState((){ bg=color; transparentBg=false; });
          scheduleQrLogoRefresh();
        }else{
          setState((){ fg=color; });
        }
        if(_contrast(background ? fg : color, background ? color : bg) < 2.0){
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content:Text(t('contrastWarning'))),
          );
        }
      },
      child:Container(
        width:54,
        height:34,
        decoration:BoxDecoration(
          color:color,
          borderRadius:BorderRadius.circular(9),
          border:Border.all(
            color:selected ? const Color(0xFF7A00FF) : panelOutlineColor,
            width:selected ? 3 : 1.5,
          ),
          boxShadow:const [BoxShadow(color:Color(0x33000000),blurRadius:3,offset:Offset(0,1))],
        ),
        child:selected
          ? Icon(Icons.check,size:19,color:color.computeLuminance() > .5 ? Colors.black : Colors.white)
          : null,
      ),
    );
  }

  double currentHue(Color color) => HSVColor.fromColor(color).hue;

  void scheduleQrLogoRefresh() {
    if (photoImage == null) return;
    _logoRefreshTimer?.cancel();
    final serial = ++_logoRefreshSerial;
    _logoRefreshTimer = Timer(const Duration(milliseconds:120), () async {
      final source = photoImage;
      if (source == null) return;
      final prepared = await _makeQrLogo(source, transparentBg ? Colors.transparent : bg);
      if (!mounted || serial != _logoRefreshSerial || photoImage != source) {
        prepared.dispose();
        return;
      }
      final old = qrLogoImage;
      setState(() => qrLogoImage = prepared);
      old?.dispose();
    });
  }

  void setColorFromPosition(bool background,double x,double width){
    final p=(x/width).clamp(0.0,1.0);
    final color=HSVColor.fromAHSV(1,p*360,1,1).toColor();
    setState((){
      if(background){
        bg=color;
        transparentBg=false;
        scheduleQrLogoRefresh();
      }else{
        fg=color;
      }
    });
  }


  Widget colorEditor()=>Container(
    padding:const EdgeInsets.all(12),
    decoration:BoxDecoration(
      color:panelSurfaceColor,
      borderRadius:BorderRadius.circular(14),
      border:Border.all(color:panelOutlineColor),
    ),
    child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      previewCard(),
      const SizedBox(height:12),
      SegmentedButton<bool>(
        segments:[
          ButtonSegment<bool>(value:false,label:Text(lang == 'Русский' ? 'Цвет QR' : lang == 'Deutsch' ? 'QR-Farbe' : lang == 'ქართული' ? 'QR ფერი' : 'QR color')),
          ButtonSegment<bool>(value:true,label:Text(lang == 'Русский' ? 'Фон' : lang == 'Deutsch' ? 'Hintergrund' : lang == 'ქართული' ? 'ფონი' : 'Background')),
        ],
        selected:<bool>{editingBackground},
        onSelectionChanged:(values)=>setState(()=>editingBackground=values.first),
      ),
      const SizedBox(height:12),
      Center(
        child:GestureDetector(
          onPanDown:(d)=>setColorFromWheel(editingBackground,d.localPosition,const Size(248,248)),
          onPanUpdate:(d)=>setColorFromWheel(editingBackground,d.localPosition,const Size(248,248)),
          child:SizedBox(
            width:248,height:248,
            child:CustomPaint(
              painter:ColorWheelPainter(brightness:colorBrightness),
              child:Center(
                child:Container(
                  width:48,height:48,
                  decoration:BoxDecoration(
                    shape:BoxShape.circle,
                    color:editingBackground ? (transparentBg ? Colors.transparent : bg) : fg,
                    border:Border.all(color:panelTextColor,width:2),
                  ),
                  child:transparentBg && editingBackground ? const Icon(Icons.grid_on,size:24,color:Colors.grey) : null,
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height:5),
      Text(
        'RGB: #${(editingBackground ? (transparentBg ? Colors.transparent : bg) : fg).value.toRadixString(16).padLeft(8,'0').substring(2).toUpperCase()}',
        textAlign:TextAlign.center,
        style:TextStyle(fontSize:11,color:panelMutedColor,fontWeight:FontWeight.w600),
      ),
      Row(children:[
        Text(lang == 'Русский' ? 'Яркость' : lang == 'Deutsch' ? 'Helligkeit' : lang == 'ქართული' ? 'სიკაშკაშე' : 'Brightness',style:TextStyle(fontSize:11,color:panelTextColor)),
        Expanded(child:Slider(
          min:.15,max:1,value:colorBrightness,
          activeColor:const Color(0xFF5B2DFF),
          onChanged:(value)=>setState(()=>colorBrightness=value),
        )),
      ]),
      Row(mainAxisAlignment:MainAxisAlignment.center,children:[
        colorQuickButton(Colors.black,editingBackground),
        const SizedBox(width:12),
        colorQuickButton(Colors.white,editingBackground),
        if(editingBackground) ...[
          const SizedBox(width:12),
          OutlinedButton.icon(
            onPressed:(){setState(()=>transparentBg=true);scheduleQrLogoRefresh();},
            icon:const Icon(Icons.grid_on,size:16),
            label:Text(t('transparent')),
          ),
        ],
      ]),
    ]),
  );

  void setColorFromWheel(bool background,Offset position,Size size){
    final center=Offset(size.width/2,size.height/2);
    final delta=position-center;
    final radius=math.min(size.width,size.height)/2;
    final distance=(delta.distance/(radius*.92)).clamp(0.0,1.0);
    final hue=(math.atan2(delta.dy,delta.dx)*180/math.pi+90+360)%360;
    final color=HSVColor.fromAHSV(1,hue,distance,colorBrightness).toColor();
    setState((){
      if(background){bg=color;transparentBg=false;}
      else{fg=color;}
    });
    if(background)scheduleQrLogoRefresh();
  }

  Widget preview()=>Column(children:[previewCard(),const SizedBox(height:7),checkQrButton(),const SizedBox(height:9),footerButtons()]);

  Widget contrastWarning()=>Container(
    margin:const EdgeInsets.only(bottom:10),
    padding:const EdgeInsets.symmetric(horizontal:12,vertical:9),
    decoration:BoxDecoration(
      color:Colors.orange.withOpacity(.14),
      borderRadius:BorderRadius.circular(7),
      border:Border.all(color:Colors.orange.withOpacity(.55)),
    ),
    child:Row(children:[
      const Icon(Icons.warning_amber_rounded,size:19,color:Colors.white),
      const SizedBox(width:8),
      Expanded(child:Text(t('contrastWarning'),style:const TextStyle(fontSize:11,fontWeight:FontWeight.w600,color:Colors.white))),
    ]),
  );

  Widget previewCard()=>Container(
    padding:const EdgeInsets.all(14),
    decoration:BoxDecoration(gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFF061B3B),Color(0xFF0A2D59),Color(0xFF350066)]),borderRadius:BorderRadius.circular(18)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      if (_contrast(fg,bg) < 2.0 && !transparentBg) contrastWarning(),
      Row(children:[
      Container(width:160,height:160,padding:const EdgeInsets.all(8),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16)),child:CustomPaint(
        key:ValueKey('${selectedDesign}-${fg.value}-${bg.value}-${transparentBg}-${error}-${photoImage != null}-${data}'),
        size:const Size(144,144),
        painter:StyledQrPainter(
          data:data.isEmpty ? ' ' : data,
          foreground:fg,
          background:transparentBg ? Colors.transparent : bg,
          design:selectedDesign,
          logo:photoImage,
          logoScale:logoScale,
          errorLevel:errorLevel,
          eyeStyle:selectedEyeStyle,
          logoOpacity:logoOpacity,
        ),
      )),
      const SizedBox(width:10),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(t('preview'),style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700,fontSize:14)),const SizedBox(height:5),Text(t('ready'),style:TextStyle(color:Colors.white.withOpacity(.78),fontSize:11))])),
      ]),
    ]),
  );

  Future<void> checkQr() async {
    if (isCheckingQr) return;
    final expected = data.trim();
    if (expected.isEmpty) {
      setState(() => qrCheckState = 'empty');
      return;
    }
    setState(() {
      isCheckingQr = true;      qrCheckState = 'checking';
    });
    try {
      // Scan the actual PNG rendered from the current QR design.
      final bytes = await pngBytes();
      if (bytes == null) throw StateError('QR image rendering returned no bytes');
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) throw StateError('Generated PNG could not be decoded');
      final rgba = decodedImage.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
      final pixels = Int32List(decodedImage.width * decodedImage.height);
      for (var i = 0; i < pixels.length; i++) {
        final offset = i * 4;
        final alpha = rgba[offset + 3];
        final r = ((rgba[offset] * alpha) + (255 * (255 - alpha))) ~/ 255;
        final g = ((rgba[offset + 1] * alpha) + (255 * (255 - alpha))) ~/ 255;
        final b = ((rgba[offset + 2] * alpha) + (255 * (255 - alpha))) ~/ 255;
        pixels[i] = 0xFF000000 | (r << 16) | (g << 8) | b;
      }
      // First try standard QR polarity (dark modules on a light background).
      // If the design uses a dark background with light modules, retry with
      // inverted luminance so the checker can validate reverse-contrast QR.
      Result? result;
      try {
        final source = RGBLuminanceSource(decodedImage.width, decodedImage.height, pixels);
        result = QRCodeReader().decode(BinaryBitmap(HybridBinarizer(source)));
      } catch (_) {
        final invertedPixels = Int32List(pixels.length);
        for (var i = 0; i < pixels.length; i++) {
          final p = pixels[i];
          final r = 255 - ((p >> 16) & 0xFF);
          final g = 255 - ((p >> 8) & 0xFF);
          final b = 255 - (p & 0xFF);
          invertedPixels[i] = 0xFF000000 | (r << 16) | (g << 8) | b;
        }
        final invertedSource = RGBLuminanceSource(decodedImage.width, decodedImage.height, invertedPixels);
        result = QRCodeReader().decode(BinaryBitmap(HybridBinarizer(invertedSource)));
      }
      if (!mounted) return;
      setState(() => qrCheckState = result!.text == expected ? 'success' : 'mismatch');
    } catch (e) {
      if (!mounted) return;
      setState(() => qrCheckState = 'failed');
    } finally {
      if (mounted) setState(() => isCheckingQr = false);
    }
  }

  Widget checkQrButton()=>Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        width:double.infinity,
        child:FilledButton.icon(
          onPressed:isCheckingQr ? null : checkQr,
          icon:isCheckingQr ? const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : const Icon(Icons.qr_code_scanner,size:20),
          label:Text(isCheckingQr ? (lang == 'Русский' ? 'Проверка…' : lang == 'Deutsch' ? 'Prüfung…' : lang == 'ქართული' ? 'მოწმდება…' : 'Checking…') : t('checkQr')),
          style:FilledButton.styleFrom(
            backgroundColor:const Color(0xFF1877D2),
            foregroundColor:Colors.white,
            minimumSize:const Size.fromHeight(46),
            shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(9)),
          ),
        ),
      ),
      if (qrCheckState != null) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: qrCheckState == 'success' ? Colors.green.withOpacity(.12) :
                   (qrCheckState == 'checking' ? Colors.blue.withOpacity(.12) : Colors.red.withOpacity(.10)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: qrCheckState == 'success' ? Colors.green :
                     (qrCheckState == 'checking' ? Colors.blue : Colors.red),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                qrCheckState == 'success' ? Icons.check_circle :
                (qrCheckState == 'checking' ? Icons.hourglass_top : Icons.error_outline),
                color: qrCheckState == 'success' ? Colors.green :
                       (qrCheckState == 'checking' ? Colors.blue : Colors.red),
              ),
              const SizedBox(width: 9),
              Expanded(child: Text(
                qrCheckState == 'success' ? t('qrConfirmed') :
                qrCheckState == 'mismatch' ? t('qrMismatchHint') :
                qrCheckState == 'empty' ? t('qrEmpty') :
                qrCheckState == 'checking' ? (lang == 'Русский' ? 'Проверяем изображение QR-кода…' : lang == 'Deutsch' ? 'QR-Bild wird geprüft…' : lang == 'ქართული' ? 'QR გამოსახულება მოწმდება…' : 'Checking the QR image…') :
                t('qrFailedHint'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              )),
            ],
          ),
        ),
      ],
    ],
  );

  Widget footerButtons()=>Row(children:[
    Expanded(
      child:Container(        decoration:BoxDecoration(
          gradient:const LinearGradient(colors:[Color(0xFF00C8FF),Color(0xFF7A00FF),Color(0xFFFF5A00)]),
          borderRadius:BorderRadius.circular(9),
        ),
        child:FilledButton.icon(
          onPressed:savePng,
          icon:const Icon(Icons.download_outlined,size:18),
          label:Text(t('save')),
          style:FilledButton.styleFrom(
            backgroundColor:Colors.transparent,
            shadowColor:Colors.transparent,
            minimumSize:const Size.fromHeight(48),
          ),
        ),
      ),
    ),
    const SizedBox(width:9),
    Expanded(
      child:OutlinedButton.icon(
        onPressed:sharePng,
        icon:const Icon(Icons.share_outlined,size:18),
        label:Text(t('share')),
        style:OutlinedButton.styleFrom(
          minimumSize:const Size.fromHeight(48),
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(9)),        ),
      ),
    ),
  ]);
}


class ModuleStylePreviewPainter extends CustomPainter {
  ModuleStylePreviewPainter(this.style);
  final String style;

  bool _finder(int x,int y) {
    return (x < 5 && y < 5) || (x >= 12 && y < 5) || (x < 5 && y >= 12);
  }

  bool _dark(int x,int y) {
    if (_finder(x,y)) return false;
    // A fixed QR-like pattern makes each preview stable and easy to compare.
    return ((x * 7 + y * 11 + x * y * 3) % 9 < 5) ||
        ((x + y * 2) % 7 == 0);
  }

  void _drawFinder(Canvas canvas, double unit, Paint ink, Paint paper) {
    for (final origin in const [(0,0),(12,0),(0,12)]) {
      final x=origin.$1, y=origin.$2;
      final r=Rect.fromLTWH(x*unit,y*unit,5*unit,5*unit);
      canvas.drawRect(r,ink);
      canvas.drawRect(r.deflate(unit),paper);
      canvas.drawRect(r.deflate(unit*2),ink);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paper=Paint()..color=Colors.white;
    final ink=Paint()..color=Colors.black;
    canvas.drawRect(Offset.zero & size,paper);
    const count=21;
    final unit=size.width/count;
    for(var y=0;y<count;y++) {
      for(var x=0;x<count;x++) {
        if(!_dark(x,y)) continue;
        final rect=Rect.fromLTWH(x*unit,y*unit,unit*.9,unit*.9);
        switch(style) {
          case 'shape_round_dots':
            canvas.drawCircle(rect.center,unit*.43,ink);
            break;
          case 'shape_diamond':
            final p=Path()..moveTo(rect.center.dx,rect.top)..lineTo(rect.right,rect.center.dy)..lineTo(rect.center.dx,rect.bottom)..lineTo(rect.left,rect.center.dy)..close();
            canvas.drawPath(p,ink);
            break;
          case 'shape_hexagon':
          case 'shape_honeycomb':
            final p=Path()..moveTo(rect.left+unit*.22,rect.top)..lineTo(rect.right-unit*.22,rect.top)..lineTo(rect.right,rect.center.dy)..lineTo(rect.right-unit*.22,rect.bottom)..lineTo(rect.left+unit*.22,rect.bottom)..lineTo(rect.left,rect.center.dy)..close();
            canvas.drawPath(p,ink);
            break;
          case 'shape_rounded_squares':
            canvas.drawRRect(RRect.fromRectAndRadius(rect,Radius.circular(unit*.28)),ink);
            break;
          case 'shape_droplet':
            final p=Path()..moveTo(rect.center.dx,rect.top)..quadraticBezierTo(rect.right,rect.top+unit*.15,rect.right,rect.center.dy)..quadraticBezierTo(rect.right,rect.bottom,rect.center.dx,rect.bottom)..quadraticBezierTo(rect.left,rect.bottom,rect.left,rect.center.dy)..quadraticBezierTo(rect.left,rect.top+unit*.15,rect.center.dx,rect.top)..close();
            canvas.drawPath(p,ink);
            break;
          case 'shape_stars':
            final p=Path();
            for(var k=0;k<10;k++) {
              final a=-math.pi/2+k*math.pi/5;
              final rad=k.isEven?unit*.46:unit*.19;
              final point=Offset(rect.center.dx+math.cos(a)*rad,rect.center.dy+math.sin(a)*rad);
              if(k==0) p.moveTo(point.dx,point.dy); else p.lineTo(point.dx,point.dy);
            }
            p.close(); canvas.drawPath(p,ink);
            break;
          case 'shape_wave':
            canvas.drawRRect(RRect.fromRectAndRadius(rect,Radius.circular(unit*.45)),ink);
            break;
          case 'shape_lines':
            canvas.drawRect(Rect.fromLTWH(rect.left,rect.center.dy-unit*.12,rect.width,unit*.24),ink);
            break;
          case 'shape_frame':
            canvas.drawRect(rect,ink);
            canvas.drawRect(rect.deflate(unit*.22),paper);
            break;
          default:
            canvas.drawRect(rect,ink);
        }
      }
    }
    _drawFinder(canvas,unit,ink,paper);
  }

  @override
  bool shouldRepaint(covariant ModuleStylePreviewPainter oldDelegate)=>style!=oldDelegate.style;
}

class EyeStylePreviewPainter extends CustomPainter {
  EyeStylePreviewPainter(this.style);
  final String style;
  @override
  void paint(Canvas canvas, Size size) {
    final black=Paint()..color=Colors.black;
    final white=Paint()..color=Colors.white;
    final r=Offset.zero & size;
    canvas.drawRect(r,white);
    final inner=r.deflate(size.width*.27);
    final core=r.deflate(size.width*.43);
    switch(style) {
      case 'circle':
        canvas.drawCircle(r.center,size.width*.5,black);
        canvas.drawCircle(r.center,size.width*.23,white);
        canvas.drawCircle(r.center,size.width*.07,black);
        break;
      case 'diamond':
        Path d(Rect a)=>Path()..moveTo(a.center.dx,a.top)..lineTo(a.right,a.center.dy)..lineTo(a.center.dx,a.bottom)..lineTo(a.left,a.center.dy)..close();
        canvas.drawPath(d(r),black); canvas.drawPath(d(inner),white); canvas.drawPath(d(core),black);
        break;
      case 'rounded':
        canvas.drawRRect(RRect.fromRectAndRadius(r,Radius.circular(size.width*.22)),black);
        canvas.drawRRect(RRect.fromRectAndRadius(inner,Radius.circular(size.width*.13)),white);
        canvas.drawRRect(RRect.fromRectAndRadius(core,Radius.circular(size.width*.06)),black);
        break;
      case 'double':
        canvas.drawRect(r,black); canvas.drawRect(r.deflate(size.width*.13),white);
        canvas.drawRect(r.deflate(size.width*.25),black); canvas.drawRect(r.deflate(size.width*.36),white);
        canvas.drawRect(r.deflate(size.width*.43),black);
        break;
      case 'neon':
        canvas.drawRRect(RRect.fromRectAndRadius(r,Radius.circular(size.width*.28)),black);
        canvas.drawRRect(RRect.fromRectAndRadius(r.deflate(size.width*.15),Radius.circular(size.width*.18)),white);
        canvas.drawRRect(RRect.fromRectAndRadius(r.deflate(size.width*.29),Radius.circular(size.width*.10)),black);
        break;
      default:
        canvas.drawRect(r,black); canvas.drawRect(inner,white); canvas.drawRect(core,black);
    }
  }
  @override
  bool shouldRepaint(covariant EyeStylePreviewPainter oldDelegate)=>style!=oldDelegate.style;
}

class StyledQrPainter extends CustomPainter {
  StyledQrPainter({
    required this.data,
    required this.foreground,
    required this.background,
    required this.design,
    required this.logo,
    required this.logoScale,
    required this.errorLevel,
    required this.eyeStyle,
    required this.logoOpacity,
  });

  final String data;
  final Color foreground;
  final Color background;
  final String design;
  final ui.Image? logo;
  final double logoScale;
  final int errorLevel;
  final String eyeStyle;
  final double logoOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final level = switch (errorLevel) {
      1 => qr.QrErrorCorrectLevel.low,
      2 => qr.QrErrorCorrectLevel.high,
      3 => qr.QrErrorCorrectLevel.quartile,
      _ => qr.QrErrorCorrectLevel.medium,
    };
    // Explicit UTF-8 ECI tells QR readers how to interpret non-Latin text.
    final payload = qr.QrPayload()
      ..addECI(qr.QrEciValue.utf8)
      ..addString(data);
    final code = qr.QrCode(payload: payload, errorCorrectLevel: level);
    final matrix = qr.QrImage(code);
    final count = matrix.moduleCount;
    final quiet = 4.0; // Standard QR quiet zone: four modules on every side.
    final unit = size.width / (count + quiet * 2);
    final origin = unit * quiet;
    final bgPaint = Paint()..color = background;
    canvas.drawRect(Offset.zero & size, bgPaint);

    final modules = Paint()..color = foreground..style = PaintingStyle.fill;
    final eyeRegions = <Rect>[
      Rect.fromLTWH(0, 0, 7, 7),
      Rect.fromLTWH(count - 7, 0, 7, 7),
      Rect.fromLTWH(0, count - 7, 7, 7),
    ];
    bool inEye(int x, int y) => eyeRegions.any((r) => r.contains(Offset(x + .5, y + .5)));
    for (var y = 0; y < count; y++) {
      for (var x = 0; x < count; x++) {
        if (!matrix.isDark(y, x) || inEye(x, y)) continue;
        final rect = Rect.fromLTWH(origin + x * unit, origin + y * unit, unit * .94, unit * .94);
        switch (design) {
          case 'shape_round_dots':
            canvas.drawCircle(rect.center, unit * .47, modules);
            break;
          case 'shape_diamond':
            final path = Path()..moveTo(rect.center.dx, rect.top)..lineTo(rect.right, rect.center.dy)..lineTo(rect.center.dx, rect.bottom)..lineTo(rect.left, rect.center.dy)..close();
            canvas.drawPath(path, modules);
            break;
          case 'shape_hexagon':
          case 'shape_honeycomb':
            final path = Path()
              ..moveTo(rect.left + rect.width * .25, rect.top)
              ..lineTo(rect.right - rect.width * .25, rect.top)
              ..lineTo(rect.right, rect.center.dy)
              ..lineTo(rect.right - rect.width * .25, rect.bottom)
              ..lineTo(rect.left + rect.width * .25, rect.bottom)
              ..lineTo(rect.left, rect.center.dy)..close();
            canvas.drawPath(path, modules);
            break;
          case 'shape_rounded_squares':
            canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(unit * .30)), modules);
            break;
          case 'shape_droplet':
            final path = Path()
              ..moveTo(rect.center.dx, rect.top)
              ..cubicTo(rect.right, rect.center.dy, rect.right, rect.bottom, rect.center.dx, rect.bottom)
              ..cubicTo(rect.left, rect.bottom, rect.left, rect.center.dy, rect.center.dx, rect.top)
              ..close();
            canvas.drawPath(path, modules);
            break;
          case 'shape_stars':
            final path = Path();
            for (var point = 0; point < 10; point++) {
              final radius = point.isEven ? unit * .48 : unit * .22;
              final angle = -math.pi / 2 + point * math.pi / 5;
              final p = Offset(rect.center.dx + math.cos(angle) * radius, rect.center.dy + math.sin(angle) * radius);
              if (point == 0) { path.moveTo(p.dx, p.dy); } else { path.lineTo(p.dx, p.dy); }
            }
            path.close();
            canvas.drawPath(path, modules);
            break;
          case 'shape_wave':
            final wave = Path()
              ..moveTo(rect.left, rect.top + unit * .20)
              ..quadraticBezierTo(rect.center.dx, rect.top - unit * .12, rect.right, rect.top + unit * .20)
              ..lineTo(rect.right, rect.bottom - unit * .20)
              ..quadraticBezierTo(rect.center.dx, rect.bottom + unit * .12, rect.left, rect.bottom - unit * .20)
              ..close();
            canvas.drawPath(wave, modules);
            break;
          case 'shape_lines':
            canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(unit * .08)), modules);
            break;
          case 'shape_frame':
            canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(unit * .12)), modules);
            break;
          case 'green':
            canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(unit * .30)), modules);
            break;
          case 'social':
            canvas.drawRect(rect.inflate(unit * .03), modules);
            break;
          case 'maze':
            // Keep every data module solid for reliable scanner detection.
            // Add a subtle squared maze-like notch while preserving the module's filled footprint.
            canvas.drawRect(rect, modules);
            break;
          case 'gold':
            canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(unit * .12)), modules);
            break;
          case 'pink':
            canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(unit * .22)), modules);
            break;
          case 'red':
            canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(unit * .38)), modules);
            break;
          case 'neon':
            canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(unit * .46)), modules);
            break;
          case 'sunset':
            final path = Path()
              ..moveTo(rect.center.dx, rect.top)
              ..lineTo(rect.right, rect.center.dy)
              ..lineTo(rect.center.dx, rect.bottom)
              ..lineTo(rect.left, rect.center.dy)
              ..close();
            canvas.drawPath(path, modules);
            break;
          case 'mint':
            canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(unit * .18)), modules);
            break;
          case 'violet':
            canvas.drawCircle(rect.center, unit * .39, modules);
            break;
          default:
            canvas.drawRect(rect, modules);
        }
      }
    }

    for (final eye in eyeRegions) {
      final rect = Rect.fromLTWH(origin + eye.left * unit, origin + eye.top * unit, eye.width * unit, eye.height * unit);
      final scanBacking=background.alpha==0?Colors.white:background;
      final clear=Paint()..color=scanBacking;
      final center=rect.center;
      final outerRadius=eyeStyle=='rounded'?unit*1.25:unit*.05;
      final inner=rect.deflate(unit*1.15);
      final core=rect.deflate(unit*2.25);
      Path diamond(Rect r)=>Path()
        ..moveTo(r.center.dx,r.top)..lineTo(r.right,r.center.dy)
        ..lineTo(r.center.dx,r.bottom)..lineTo(r.left,r.center.dy)..close();
      void shape(Rect r,Paint p,{double radius=0}) {
        switch(eyeStyle) {
          case 'circle': canvas.drawCircle(r.center,r.width/2,p); break;
          case 'diamond': canvas.drawPath(diamond(r),p); break;
          case 'rounded': canvas.drawRRect(RRect.fromRectAndRadius(r,Radius.circular(radius)),p); break;
          default: canvas.drawRect(r,p);
        }
      }
      if(eyeStyle=='neon') {
        // Rounded outer frame and a distinct rounded center block.
        canvas.drawRRect(RRect.fromRectAndRadius(rect,Radius.circular(unit*2.0)),modules);
        canvas.drawRRect(RRect.fromRectAndRadius(rect.deflate(unit*.9),Radius.circular(unit*1.15)),clear);
        canvas.drawRRect(RRect.fromRectAndRadius(rect.deflate(unit*1.75),Radius.circular(unit*.55)),modules);
      } else {
        shape(rect,modules,radius:outerRadius);
        shape(inner,clear,radius:outerRadius*.65);
        shape(core,modules,radius:outerRadius*.35);
      }
    }

    // Distinctive corner brackets on the sunset and violet templates.
    if (design == 'sunset' || design == 'violet' || design == 'social' || design == 'gold' || design == 'pink') {
      final p = Paint()..color = foreground..style = PaintingStyle.stroke..strokeWidth = unit * .85..strokeCap = StrokeCap.square;
      final span = unit * 4.2;
      final pad = origin - unit * .5;
      for (final x in [pad, size.width - pad]) {
        for (final y in [pad, size.height - pad]) {
          final sx = x < size.width / 2 ? 1.0 : -1.0;
          final sy = y < size.height / 2 ? 1.0 : -1.0;
          final path = Path()
            ..moveTo(x, y + sy * span)
            ..lineTo(x, y)
            ..lineTo(x + sx * span, y);
          canvas.drawPath(path, p);
        }
      }
    }

    if (logo != null) {
      final side = size.width * logoScale;
      final rect = Rect.fromCenter(center: size.center(Offset.zero), width: side, height: side);
      final scanBacking = background.alpha == 0 ? Colors.white : background;
      final pad = Paint()..color = scanBacking;
      canvas.drawRRect(RRect.fromRectAndRadius(rect.inflate(unit * .65), Radius.circular(unit)), pad);
      canvas.drawImageRect(logo!, Rect.fromLTWH(0, 0, logo!.width.toDouble(), logo!.height.toDouble()), rect, Paint()..filterQuality = FilterQuality.high..color=Colors.white.withOpacity(logoOpacity));
    } else if (design.startsWith('brand_')) {
      final side = size.width * .19;
      final rect = Rect.fromCenter(center:size.center(Offset.zero),width:side,height:side);
      final center=rect.center;
      final white=Paint()..color=Colors.white..style=PaintingStyle.fill;
      final ink=Paint()..color=foreground..style=PaintingStyle.fill;
      final stroke=Paint()..color=foreground..style=PaintingStyle.stroke..strokeWidth=side*.095..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round;
      final plate=background.alpha==0?Colors.white:background;
      canvas.drawRRect(RRect.fromRectAndRadius(rect.inflate(unit*.65),Radius.circular(unit)),Paint()..color=plate);
      canvas.drawRRect(RRect.fromRectAndRadius(rect,Radius.circular(side*.20)),white);
      switch(design){
        case 'brand_instagram':
          canvas.drawRRect(RRect.fromRectAndRadius(rect.deflate(side*.19),Radius.circular(side*.22)),stroke);
          canvas.drawCircle(center,side*.19,stroke);
          canvas.drawCircle(Offset(rect.right-side*.28,rect.top+side*.28),side*.055,ink);
          break;
        case 'brand_facebook':
          final p=Path()..moveTo(center.dx+side*.12,rect.bottom-side*.12)..lineTo(center.dx+side*.12,center.dy-side*.02)..lineTo(center.dx+side*.31,center.dy-side*.02)..lineTo(center.dx+side*.31,center.dy-side*.20)..lineTo(center.dx+side*.12,center.dy-side*.20)..lineTo(center.dx+side*.12,rect.top+side*.20)..quadraticBezierTo(center.dx+side*.12,rect.top+side*.04,center.dx+side*.30,rect.top+side*.04)..lineTo(center.dx+side*.42,rect.top+side*.04);
          canvas.drawPath(p,stroke..strokeWidth=side*.17);
          break;
        case 'brand_tiktok':
          final p=Path()..moveTo(center.dx+side*.02,rect.top+side*.14)..lineTo(center.dx+side*.02,center.dy+side*.18)..cubicTo(center.dx+side*.02,center.dy+side*.48,rect.left+side*.10,rect.bottom-side*.06,rect.left+side*.28,rect.bottom-side*.06)..cubicTo(rect.left+side*.47,rect.bottom-side*.06,center.dx-side*.12,center.dy+side*.25,center.dx-side*.12,center.dy+side*.08)..lineTo(center.dx-side*.12,rect.top+side*.14);
          canvas.drawPath(p,stroke..strokeWidth=side*.14);
          canvas.drawLine(Offset(center.dx+side*.02,rect.top+side*.12),Offset(center.dx+side*.32,rect.top+side*.12),stroke..strokeWidth=side*.14);
          canvas.drawLine(Offset(center.dx+side*.28,rect.top+side*.12),Offset(center.dx+side*.28,center.dy-side*.02),stroke..strokeWidth=side*.14);
          break;
        case 'brand_youtube':
          canvas.drawRRect(RRect.fromRectAndRadius(rect.deflate(side*.10),Radius.circular(side*.22)),ink);
          final p=Path()..moveTo(center.dx-side*.09,center.dy-side*.16)..lineTo(center.dx+side*.19,center.dy)..lineTo(center.dx-side*.09,center.dy+side*.16)..close();
          canvas.drawPath(p,white);
          break;
        case 'brand_x':
          canvas.drawLine(Offset(rect.left+side*.19,rect.top+side*.13),Offset(rect.right-side*.16,rect.bottom-side*.13),stroke..strokeWidth=side*.12);
          canvas.drawLine(Offset(rect.right-side*.16,rect.top+side*.13),Offset(rect.left+side*.19,rect.bottom-side*.13),stroke..strokeWidth=side*.12);
          break;
        case 'brand_whatsapp':
          canvas.drawCircle(center,side*.34,stroke..strokeWidth=side*.085);
          final tail=Path()..moveTo(rect.left+side*.22,rect.bottom-side*.23)..lineTo(rect.left+side*.13,rect.bottom-side*.08)..lineTo(rect.left+side*.31,rect.bottom-side*.13)..close();
          canvas.drawPath(tail,ink);
          final phone=Path()..moveTo(center.dx-side*.17,center.dy-side*.19)..quadraticBezierTo(center.dx-side*.28,center.dy-side*.03,center.dx+side*.04,center.dy+side*.20)..quadraticBezierTo(center.dx+side*.17,center.dy+side*.29,center.dx+side*.23,center.dy+side*.13);
          canvas.drawPath(phone,stroke..strokeWidth=side*.11);
          break;
        case 'brand_telegram':
          final p=Path()..moveTo(rect.left+side*.10,center.dy)..lineTo(rect.right-side*.08,rect.top+side*.12)..lineTo(center.dx+side*.13,rect.bottom-side*.10)..lineTo(center.dx-side*.02,center.dy+side*.10)..lineTo(rect.left+side*.10,center.dy)..close();
          canvas.drawPath(p,ink);
          canvas.drawLine(Offset(center.dx-side*.02,center.dy+side*.10),Offset(center.dx+side*.29,rect.top+side*.18),Paint()..color=Colors.white..strokeWidth=side*.06);
          break;
        case 'brand_snapchat':
          final p=Path()..moveTo(center.dx,rect.top+side*.12)..cubicTo(rect.left+side*.20,rect.top+side*.12,rect.left+side*.17,center.dy+side*.05,rect.left+side*.19,center.dy+side*.23)..cubicTo(rect.left+side*.15,center.dy+side*.34,rect.left+side*.08,center.dy+side*.35,rect.left+side*.10,center.dy+side*.43)..quadraticBezierTo(center.dx-side*.05,center.dy+side*.51,center.dx,rect.bottom-side*.12)..quadraticBezierTo(center.dx+side*.05,center.dy+side*.51,rect.right-side*.10,center.dy+side*.43)..cubicTo(rect.right-side*.08,center.dy+side*.35,rect.right-side*.15,center.dy+side*.34,rect.right-side*.19,center.dy+side*.23)..cubicTo(rect.right-side*.17,center.dy+side*.05,rect.right-side*.20,rect.top+side*.12,center.dx,rect.top+side*.12)..close();
          canvas.drawPath(p,ink);
          break;
        case 'brand_discord':
          final p=Path()..moveTo(rect.left+side*.16,center.dy-side*.17)..quadraticBezierTo(center.dx,rect.top-side*.02,rect.right-side*.16,center.dy-side*.17)..quadraticBezierTo(rect.right-side*.04,center.dy+side*.02,rect.right-side*.08,center.dy+side*.23)..quadraticBezierTo(center.dx,rect.bottom+side*.02,rect.left+side*.08,center.dy+side*.23)..quadraticBezierTo(rect.left+side*.04,center.dy+side*.02,rect.left+side*.16,center.dy-side*.17)..close();
          canvas.drawPath(p,ink);
          canvas.drawCircle(Offset(center.dx-side*.16,center.dy+side*.03),side*.045,white);
          canvas.drawCircle(Offset(center.dx+side*.16,center.dy+side*.03),side*.045,white);
          break;
        case 'brand_linkedin':
          final tp=TextPainter(text:TextSpan(text:'in',style:TextStyle(color:foreground,fontSize:side*.60,fontWeight:FontWeight.w900)),textDirection:TextDirection.ltr)..layout();
          tp.paint(canvas,Offset(center.dx-tp.width/2,center.dy-tp.height/2));
          break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant StyledQrPainter oldDelegate) =>
      data != oldDelegate.data || foreground != oldDelegate.foreground ||
      background != oldDelegate.background || design != oldDelegate.design ||
      logo != oldDelegate.logo || logoScale != oldDelegate.logoScale ||
      errorLevel != oldDelegate.errorLevel || eyeStyle != oldDelegate.eyeStyle || logoOpacity != oldDelegate.logoOpacity;
}


class ColorWheelPainter extends CustomPainter {
  const ColorWheelPainter({required this.brightness});
  final double brightness;

  @override
  void paint(Canvas canvas,Size size){
    final center=Offset(size.width/2,size.height/2);
    final radius=math.min(size.width,size.height)*.46;
    const slices=180;
    final paint=Paint()..style=PaintingStyle.fill;
    for(var i=0;i<slices;i++){
      final start=i*2*math.pi/slices-math.pi/2;
      final sweep=2*math.pi/slices+.006;
      for(var ring=0;ring<36;ring++){
        final inner=radius*(ring/36);
        final outer=radius*((ring+1)/36);
        paint.color=HSVColor.fromAHSV(1,(i/slices)*360,(ring+1)/36,brightness).toColor();
        final path=Path()
          ..moveTo(center.dx+math.cos(start)*inner,center.dy+math.sin(start)*inner)
          ..lineTo(center.dx+math.cos(start)*outer,center.dy+math.sin(start)*outer)
          ..arcTo(Rect.fromCircle(center:center,radius:outer),start,sweep,false)
          ..lineTo(center.dx+math.cos(start+sweep)*inner,center.dy+math.sin(start+sweep)*inner)
          ..arcTo(Rect.fromCircle(center:center,radius:inner),start+sweep,-sweep,false)
          ..close();
        canvas.drawPath(path,paint);
      }
    }
    canvas.drawCircle(center,radius*.12,Paint()..color=Colors.white);
  }

  @override
  bool shouldRepaint(covariant ColorWheelPainter oldDelegate)=>brightness!=oldDelegate.brightness;
}

class ScannerCornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF08A9FF)..style = PaintingStyle.stroke..strokeWidth = 5..strokeCap = StrokeCap.round;
    const length = 34.0;
    const radius = 17.0;
    final path = Path()
      ..moveTo(0, length)..lineTo(0, radius)..quadraticBezierTo(0, 0, radius, 0)..lineTo(length, 0)
      ..moveTo(size.width-length, 0)..lineTo(size.width-radius, 0)..quadraticBezierTo(size.width, 0, size.width, radius)..lineTo(size.width, length)
      ..moveTo(size.width, size.height-length)..lineTo(size.width, size.height-radius)..quadraticBezierTo(size.width, size.height, size.width-radius, size.height)..lineTo(size.width-length, size.height)
      ..moveTo(length, size.height)..lineTo(radius, size.height)..quadraticBezierTo(0, size.height, 0, size.height-radius)..lineTo(0, size.height-length);
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}