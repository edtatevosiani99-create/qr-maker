import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qr/qr.dart' as qr;
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() => runApp(const QRStudioApp());

enum QRType { url, text, phone, wifi, contact, email, location }

class QRStudioApp extends StatefulWidget {
  const QRStudioApp({super.key});
  @override State<QRStudioApp> createState() => _QRStudioAppState();
}

class _QRStudioAppState extends State<QRStudioApp> with SingleTickerProviderStateMixin {
  ThemeMode themeMode = ThemeMode.light;
  String lang = 'English';
  QRType type = QRType.url;
  Color fg = Colors.black, bg = Colors.white;
  double size = 684;
  double logoScale = .15;
  String error = 'M', security = 'WPA';
  String selectedDesign = 'classic';
  bool transparentBg = false;
  bool isCheckingQr = false;
  String? qrCheckState;
  bool isScannerOpen = false;
  String? scannedValue;
  bool torchEnabled = false;
  final MobileScannerController scannerController = MobileScannerController();
  late final AnimationController _scanLineController;
  Uint8List? photoBytes;
  ui.Image? photoImage;
  ui.Image? qrLogoImage;
  final picker = ImagePicker();
  Timer? _logoRefreshTimer;
  int _logoRefreshSerial = 0;
  final c = {for (final k in ['main','name','phone','email','subject','message','ssid','password','lat','lon','address']) k: TextEditingController()};

  final labels = const {
    'Русский': {'title':'QR Studio','subtitle':'Создавай • Кастомизируй • Сохраняй','type':'Тип QR-кода','url':'URL','text':'Текст','phone':'Телефон','wifi':'Wi‑Fi','contact':'Контакт','email':'Email','location':'Геолокация','fg':'Цвет QR','bg':'Фон','transparent':'Прозрачный фон','size':'Размер','error':'Коррекция ошибок','save':'Сохранить PNG','share':'Поделиться','checkQr':'Проверить QR','qrEmpty':'Данные QR-кода пусты.','qrReadable':'QR-код читается','qrMismatch':'Содержимое QR не совпадает','qrConfirmed':'Приложение отсканировало созданное изображение QR и подтвердило, что его содержимое совпадает с исходными данными.','qrMismatchHint':'QR-код считан, но данные не совпадают с исходными. Попробуйте другой дизайн или удалите логотип.','qrFailed':'Не удалось отсканировать QR-код','qrFailedHint':'Приложение попыталось проверить созданное изображение QR, но не смогло его распознать. Попробуйте простой дизайн, более высокий контраст или уменьшите логотип.','ok':'ОК','name':'Имя','data':'Данные','subject':'Тема','message':'Сообщение','ssid':'Название Wi‑Fi','password':'Пароль','security':'Защита','lat':'Широта','lon':'Долгота','address':'Адрес','photo':'Выбрать фото','logo':'Логотип в QR','logoHint':'По желанию: вставьте картинку из галереи в центр QR','photoSelected':'Логотип выбран • коррекция H','removeLogo':'Удалить логотип','photoError':'Не удалось открыть это изображение','saved':'PNG сохранён в галерею','permission':'Разрешите доступ к галерее','preview':'Ваш QR-код','ready':'Готов к сохранению','logoSize':'Размер логотипа','lowContrastQr':'Низкий контраст: выберите более тёмный цвет QR.','lowContrastBg':'Низкий контраст: выберите более светлый фон.','contrastWarning':'Предупреждение: низкий контраст QR и фона — сканирование может быть затруднено.','none':'Без защиты','designs':'Дизайн QR-кода','classic':'Классика','neon':'Неон','sunset':'Закат','mint':'Мята','violet':'Фиолетовый'},
    'English': {'title':'QR Studio','subtitle':'Create • Customize • Save','type':'QR code type','url':'URL','text':'Text','phone':'Phone','wifi':'Wi‑Fi','contact':'Contact','email':'Email','location':'Location','fg':'QR color','bg':'Background','transparent':'Transparent background','size':'Size','error':'Error correction','save':'Save PNG','share':'Share','checkQr':'Check QR','qrEmpty':'QR data is empty.','qrReadable':'QR code is readable','qrMismatch':'QR code data mismatch','qrConfirmed':'The app scanned the generated QR image and confirmed that its contents match your data.','qrMismatchHint':'The QR image was read, but the decoded content does not match the original data. Try another design or remove the logo.','qrFailed':'QR code could not be scanned','qrFailedHint':'The app tried to scan the actual generated QR image but could not decode it. Try a simpler design, stronger contrast, or a smaller logo.','ok':'OK','name':'Name','data':'Data','subject':'Subject','message':'Message','ssid':'Wi‑Fi name','password':'Password','security':'Security','lat':'Latitude','lon':'Longitude','address':'Address','photo':'Choose photo','logo':'Logo in QR','logoHint':'Optional: add an image from the gallery to the center','photoSelected':'Logo selected • correction H','removeLogo':'Remove logo','photoError':'Could not open this image','saved':'PNG saved to gallery','permission':'Please allow gallery access','preview':'Your QR code','ready':'Ready to save','logoSize':'Logo size','lowContrastQr':'Low contrast: choose a darker QR color.','lowContrastBg':'Low contrast: choose a lighter background.','contrastWarning':'Warning: QR and background contrast is low — scanning may be difficult.','none':'No security','designs':'QR design','classic':'Classic','green':'Green style','social':'Blue corners','maze':'Geometric','gold':'Gold frame','pink':'Pink frame','red':'Red style','neon':'Neon','sunset':'Sunset','mint':'Mint','violet':'Violet'},
    'Deutsch': {'title':'QR Studio','subtitle':'Erstellen • Anpassen • Speichern','type':'QR-Code-Typ','url':'URL','text':'Text','phone':'Telefon','wifi':'WLAN','contact':'Kontakt','email':'E-Mail','location':'Standort','fg':'QR-Farbe','bg':'Hintergrund','transparent':'Transparenter Hintergrund','size':'Größe','error':'Fehlerkorrektur','save':'PNG speichern','share':'Teilen','checkQr':'QR prüfen','qrEmpty':'Die QR-Daten sind leer.','qrReadable':'QR-Code ist lesbar','qrMismatch':'QR-Code-Inhalt stimmt nicht überein','qrConfirmed':'Die App hat das erzeugte QR-Bild gescannt und bestätigt, dass der Inhalt mit den ursprünglichen Daten übereinstimmt.','qrMismatchHint':'Das QR-Bild wurde gelesen, aber der Inhalt stimmt nicht mit den ursprünglichen Daten überein. Versuchen Sie ein anderes Design oder entfernen Sie das Logo.','qrFailed':'QR-Code konnte nicht gescannt werden','qrFailedHint':'Das erzeugte QR-Bild konnte nicht gelesen werden. Versuchen Sie ein einfacheres Design, stärkeren Kontrast oder ein kleineres Logo.','ok':'OK','name':'Name','data':'Daten','subject':'Betreff','message':'Nachricht','ssid':'WLAN-Name','password':'Passwort','security':'Sicherheit','lat':'Breitengrad','lon':'Längengrad','address':'Adresse','photo':'Foto auswählen','logo':'Logo im QR','logoHint':'Optional: Bild aus der Galerie in die Mitte einfügen','photoSelected':'Logo ausgewählt • Korrektur H','removeLogo':'Logo entfernen','photoError':'Bild konnte nicht geöffnet werden','saved':'PNG in Galerie gespeichert','permission':'Bitte Galeriezugriff erlauben','preview':'Ihr QR-Code','ready':'Bereit zum Speichern','logoSize':'Logogröße','lowContrastQr':'Zu geringer Kontrast: Wählen Sie eine dunklere QR-Farbe.','lowContrastBg':'Zu geringer Kontrast: Wählen Sie einen helleren Hintergrund.','contrastWarning':'Warnung: Der Kontrast zwischen QR und Hintergrund ist niedrig — das Scannen kann schwierig sein.','none':'Keine Sicherheit','designs':'QR-Design','classic':'Klassisch','neon':'Neon','sunset':'Sonnenuntergang','mint':'Minze','violet':'Violett'},
    'ქართული': {'title':'QR Studio','subtitle':'შექმენი • მოარგე • შეინახე','type':'QR კოდის ტიპი','url':'URL','text':'ტექსტი','phone':'ტელეფონი','wifi':'Wi‑Fi','contact':'კონტაქტი','email':'ელფოსტა','location':'გეოლოკაცია','fg':'QR ფერი','bg':'ფონი','transparent':'გამჭვირვალე ფონი','size':'ზომა','error':'შეცდომის გასწორება','save':'PNG შენახვა','share':'გაზიარება','checkQr':'QR-ის შემოწმება','qrEmpty':'QR კოდის მონაცემები ცარიელია.','qrReadable':'QR კოდი იკითხება','qrMismatch':'QR კოდის მონაცემები არ ემთხვევა','qrConfirmed':'აპმა დაასკანერა შექმნილი QR გამოსახულება და დაადასტურა, რომ შიგთავსი საწყის მონაცემებს ემთხვევა.','qrMismatchHint':'QR გამოსახულება წაიკითხა, მაგრამ მონაცემები საწყისს არ ემთხვევა. სცადეთ სხვა დიზაინი ან წაშალეთ ლოგო.','qrFailed':'QR კოდის წაკითხვა ვერ მოხერხდა','qrFailedHint':'აპმა სცადა შექმნილი QR გამოსახულების წაკითხვა, მაგრამ ვერ შეძლო. სცადეთ მარტივი დიზაინი, უფრო მაღალი კონტრასტი ან პატარა ლოგო.','ok':'კარგი','name':'სახელი','data':'მონაცემები','subject':'თემა','message':'შეტყობინება','ssid':'Wi‑Fi სახელი','password':'პაროლი','security':'დაცვა','lat':'გრძედი','lon':'განედი','address':'მისამართი','photo':'ფოტოს არჩევა','logo':'ლოგო QR-ში','logoHint':'სურვილისამებრ: გალერეიდან სურათი ჩასვით QR-ის ცენტრში','photoSelected':'ლოგო არჩეულია • კორექცია H','removeLogo':'ლოგოს წაშლა','photoError':'სურათი ვერ გაიხსნა','saved':'PNG გალერეაში შეინახა','permission':'გთხოვთ დაუშვათ გალერეაზე წვდომა','preview':'თქვენი QR კოდი','ready':'მზადაა შესანახად','logoSize':'ლოგოს ზომა','lowContrastQr':'კონტრასტი ძალიან დაბალია: აირჩიეთ უფრო მუქი QR ფერი.','lowContrastBg':'კონტრასტი ძალიან დაბალია: აირჩიეთ უფრო ღია ფონი.','contrastWarning':'გაფრთხილება: QR-სა და ფონს შორის კონტრასტი დაბალია — სკანირება შეიძლება გართულდეს.','none':'დაცვის გარეშე','designs':'QR დიზაინი','classic':'კლასიკური','neon':'ნეონი','sunset':'მზის ჩასვლა','mint':'პიტნა','violet':'იისფერი'}
  };

  String t(String k) => labels[lang]![k] ?? k;
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
 
  int get errorLevel => photoImage != null ? 2 : (const {'L':1,'M':0,'Q':3,'H':2}[error] ?? 0);

  @override void initState() {
    super.initState();
    c['main']!.text = 'https://example.com';
    _scanLineController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
  }
  @override void dispose() { _logoRefreshTimer?.cancel(); _scanLineController.dispose(); scannerController.dispose(); photoImage?.dispose(); qrLogoImage?.dispose(); for (final x in c.values) x.dispose(); super.dispose(); }

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
      case QRType.url:
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
    );
    painter.paint(canvas, Size(size, size));
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.round(), size.round());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    return bytes?.buffer.asUint8List();
  }

  Future<void> savePng() async {
    final b = await pngBytes(); if (b == null) return;
    try {
      if (!await Gal.hasAccess()) {
        final ok = await Gal.requestAccess();
        if (!ok) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(t('permission')))); return; }
      }
      await Gal.putImageBytes(b, album:'QR Studio');
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
    return MaterialApp(
      debugShowCheckedModeBanner:false, themeMode:themeMode,
      theme:ThemeData(useMaterial3:true, brightness:Brightness.light, scaffoldBackgroundColor:const Color(0xFFE8F5FF), colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xFF2B7FFF))),
      darkTheme:ThemeData(useMaterial3:true, brightness:Brightness.dark, scaffoldBackgroundColor:const Color(0xFF03152C), colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xFF1E9BFF), brightness:Brightness.dark)),
      home:Scaffold(
        body:SafeArea(child:LayoutBuilder(builder:(ctx,box) {
          final wide = box.maxWidth > 820;
          return SingleChildScrollView(
            padding:EdgeInsets.fromLTRB(wide ? 28 : 16,10,wide ? 28 : 16,28),
            child:Center(child:ConstrainedBox(
              constraints:const BoxConstraints(maxWidth:980),
              child:wide ? (isScannerOpen ? Column(children:[header(),const SizedBox(height:12),modeSelector(),const SizedBox(height:16),scannerView()]) : Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:form()),const SizedBox(width:24),Expanded(child:preview())])) : Column(children:[header(),const SizedBox(height:12),modeSelector(),const SizedBox(height:16),if(isScannerOpen) scannerView() else ...[formBody(),const SizedBox(height:18),previewCard(),const SizedBox(height:10),checkQrButton(),const SizedBox(height:18),footerButtons()]]),
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
        Text(t('subtitle'),style:TextStyle(fontSize:11,color:Theme.of(context).colorScheme.onSurfaceVariant)),
      ])),
      languageButton(), const SizedBox(width:4),
      IconButton(onPressed:()=>setState(()=>themeMode=themeMode==ThemeMode.light?ThemeMode.dark:ThemeMode.light),icon:Icon(themeMode==ThemeMode.light?Icons.dark_mode:Icons.light_mode)),
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
      onSelected:(x)=>setState(()=>lang=x),
      itemBuilder:(_)=>flags.entries.map((e)=>PopupMenuItem(value:e.key,child:Text(e.value + '  ' + e.key))).toList(),
      child:Row(children:[Text(flags[lang]!,style:const TextStyle(fontSize:20)),const Icon(Icons.keyboard_arrow_down)]),
    );
  }

  Widget form() => Column(children:[header(),const SizedBox(height:12),modeSelector(),const SizedBox(height:16),formBody(),const SizedBox(height:18),footerButtons()]);

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
      onPressed:()=>setState(() { isScannerOpen=true; scannedValue=null; }),
      icon:const Icon(Icons.qr_code_scanner),
      label:Text(scannerText('scan'),maxLines:1,overflow:TextOverflow.ellipsis),
      style:FilledButton.styleFrom(minimumSize:const Size.fromHeight(48),backgroundColor:isScannerOpen?const Color(0xFF1877D2):Theme.of(context).colorScheme.surfaceVariant,foregroundColor:isScannerOpen?Colors.white:Theme.of(context).colorScheme.onSurfaceVariant),
    )),
  ]);

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
      if (mounted) setState(() => scannedValue = result.text.trim());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(scannerText('galleryError'))));
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
                        final value = barcode.rawValue;
                        if (value != null && value.trim().isNotEmpty) {
                          setState(() => scannedValue = value.trim());
                          break;
                        }
                      }
                    },
                  )
                else
                  Container(color: const Color(0xFF20252D), child: const Center(child: Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 58))),
                if (scannedValue == null) ...[
                  Container(color: Colors.black.withOpacity(.16)),
                  Center(child: Container(
                    width: 230, height: 230,
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
            ),
          ),
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

  Widget formBody() => Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Text(t('type'),style:const TextStyle(fontSize:16,fontWeight:FontWeight.w700)),const SizedBox(height:9),
    Wrap(spacing:7,runSpacing:7,children:[QRType.url,QRType.text,QRType.phone,QRType.wifi,QRType.contact,QRType.email,QRType.location].map(typeChip).toList()),
    const SizedBox(height:14),
    const SizedBox(height:12),specific(),
    if(type==QRType.wifi) ...[
      const SizedBox(height:2),
      DropdownButtonFormField<String>(value:security,decoration:fieldDecoration(t('security')),items:['WPA','WEP','None'].map((x)=>DropdownMenuItem(value:x,child:Text(x=='None'?t('none'):x))).toList(),onChanged:(x)=>setState(()=>security=x!)),
    ],
    if(type==QRType.location) ...[input('lat',t('lat'),keyboard:TextInputType.number),input('lon',t('lon'),keyboard:TextInputType.number),input('address',t('address'))],
    const SizedBox(height:4),Text(t('fg'),style:const TextStyle(fontSize:13,fontWeight:FontWeight.w700)),const SizedBox(height:6),gradientColorBar(false),
    const SizedBox(height:12),Text(t('bg'),style:const TextStyle(fontSize:13,fontWeight:FontWeight.w700)),const SizedBox(height:6),gradientColorBar(true),
    const SizedBox(height:14),
    Container(
      width:double.infinity,
      padding:const EdgeInsets.fromLTRB(10,10,10,12),
      decoration:BoxDecoration(
        color:Theme.of(context).colorScheme.surface,
        borderRadius:BorderRadius.circular(14),
        border:Border.all(color:const Color(0xFF5B2DFF).withOpacity(.55),width:1.4),
      ),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          const Icon(Icons.palette_outlined,size:19,color:Color(0xFF5B2DFF)),
          const SizedBox(width:7),
          Expanded(child:Text(t('designs'),style:const TextStyle(fontSize:14,fontWeight:FontWeight.w800))),
        ]),
        const SizedBox(height:9),
        SizedBox(height:112,child:ListView(
          scrollDirection:Axis.horizontal,
          children:[
            designOption('green',const Color(0xFF078F42),Colors.white),
            designOption('social',const Color(0xFF1749C8),const Color(0xFFEAF1FF)),
            designOption('classic',Colors.black,Colors.white),
            designOption('maze',const Color(0xFF3978F6),Colors.white),
            designOption('gold',const Color(0xFF8A5A00),const Color(0xFFFFFDF5)),
            designOption('pink',const Color(0xFFDB4F9B),const Color(0xFFFFF2FA)),
            designOption('red',const Color(0xFFD60018),const Color(0xFFFFF7F7)),
          ],
        )),
      ]),
    ),
    const SizedBox(height:13),Text(t('size') + ': ' + size.round().toString() + ' px',style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700)),
    Slider(min:256,max:1024,value:size,activeColor:const Color(0xFF5B2DFF),onChanged:(x)=>setState(()=>size=x)),
    Text(t('error'),style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700)),const SizedBox(height:6),
    DropdownButtonFormField<String>(value:photoImage != null ? 'H' : error,decoration:fieldDecoration(''),items:['L','M','Q','H'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:photoImage != null ? null : (x)=>setState(()=>error=x!)),
    const SizedBox(height:10),
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
    ],
  ]);

  Widget logoSection()=>Container(
    padding:const EdgeInsets.all(12),
    decoration:BoxDecoration(
      color:Theme.of(context).colorScheme.surface,
      borderRadius:BorderRadius.circular(14),
      border:Border.all(color:Theme.of(context).colorScheme.outlineVariant),
    ),
    child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Row(children:[
        const Icon(Icons.add_photo_alternate_outlined,size:20),
        const SizedBox(width:8),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(t('logo'),style:const TextStyle(fontSize:13,fontWeight:FontWeight.w700)),
          Text(photoImage == null ? t('logoHint') : t('photoSelected'),style:TextStyle(fontSize:10,color:Theme.of(context).colorScheme.onSurfaceVariant)),
        ])),
        if(photoImage != null)
          ClipRRect(borderRadius:BorderRadius.circular(8),child:Image.memory(photoBytes!,width:42,height:42,fit:BoxFit.cover)),
      ]),
      const SizedBox(height:9),
      Row(children:[
        Expanded(child:OutlinedButton.icon(
          onPressed:choosePhoto,
          icon:const Icon(Icons.photo_library_outlined,size:18),
          label:Text(t('photo')),
          style:OutlinedButton.styleFrom(minimumSize:const Size.fromHeight(42),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
        )),
        if(photoImage != null) ...[
          const SizedBox(width:8),
          IconButton(
            onPressed:removePhoto,
            tooltip:t('removeLogo'),
            icon:const Icon(Icons.delete_outline),
            style:IconButton.styleFrom(minimumSize:const Size(42,42)),
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

  Widget designOption(String id, Color qrColor, Color backgroundColor) {
    final chosen = selectedDesign == id;
    return GestureDetector(
      onTap:() {
        setState(() {
          selectedDesign = id;
          fg = qrColor;
          bg = backgroundColor;
          transparentBg = false;
        });
        scheduleQrLogoRefresh();
      },
      child:AnimatedContainer(
        duration:const Duration(milliseconds:160),
        width:82,
        margin:const EdgeInsets.only(right:9),
        padding:const EdgeInsets.all(7),
        decoration:BoxDecoration(
          color:Theme.of(context).colorScheme.surface,
          borderRadius:BorderRadius.circular(12),
          border:Border.all(color:chosen ? const Color(0xFF00B89C) : Theme.of(context).colorScheme.outlineVariant,width:chosen ? 2.5 : 1),
        ),
        child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
          Container(
            width:35,height:35,
            decoration:BoxDecoration(color:backgroundColor,borderRadius:BorderRadius.circular(7)),
            child:Icon(Icons.qr_code_2_rounded,size:31,color:qrColor),
          ),
          const SizedBox(height:4),
          Text(t(id),maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(fontSize:10,fontWeight:chosen ? FontWeight.w800 : FontWeight.w500)),
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
        decoration:BoxDecoration(gradient:selected?const LinearGradient(colors:[Color(0xFF00CFFF),Color(0xFF7A00FF),Color(0xFFFF1BC7)]):null,color:selected?null:Theme.of(context).colorScheme.surface,borderRadius:BorderRadius.circular(10),border:Border.all(color:selected?Colors.transparent:Theme.of(context).colorScheme.outlineVariant)),
        child:Row(mainAxisSize:MainAxisSize.min,children:[Icon(icons[x],size:18,color:selected?Colors.white:Theme.of(context).colorScheme.onSurfaceVariant),const SizedBox(width:7),Text(t(key),style:TextStyle(fontSize:12,fontWeight:FontWeight.w600,color:selected?Colors.white:Theme.of(context).colorScheme.onSurface))]),
      ),
    );
  }

  InputDecoration fieldDecoration(String label)=>InputDecoration(labelText:label.isEmpty?null:label,filled:true,fillColor:Theme.of(context).colorScheme.surface,contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:13),border:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:BorderSide(color:Theme.of(context).colorScheme.outlineVariant)),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:BorderSide(color:Theme.of(context).colorScheme.outlineVariant)));

  Widget input(String key,String label,{TextInputType? keyboard})=>Padding(
    padding:const EdgeInsets.only(bottom:10),
    child:TextField(controller:c[key],keyboardType:keyboard,onChanged:(_)=>setState((){}),decoration:fieldDecoration(label)),
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
            onTapDown:(d)=>setColorFromPosition(background,d.localPosition.dx,width),
            onPanStart:(d)=>setColorFromPosition(background,d.localPosition.dx,width),
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
                borderRadius:BorderRadius.circular(10),
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
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height:7),
          Text(
            'RGB: #' + current.value.toRadixString(16).padLeft(8,'0').substring(2).toUpperCase(),
            textAlign:TextAlign.center,
            style:TextStyle(fontSize:11,color:Theme.of(context).colorScheme.onSurfaceVariant,fontWeight:FontWeight.w600),
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
                  color:Theme.of(context).colorScheme.surface,
                  borderRadius:BorderRadius.circular(10),
                  border:Border.all(
                    color:transparentBg ? const Color(0xFF7A00FF) : Theme.of(context).colorScheme.outline,
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
                        border:Border.all(color:Theme.of(context).colorScheme.outline),
                        gradient:const LinearGradient(
                          begin:Alignment.topLeft,end:Alignment.bottomRight,
                          colors:[Colors.white,Colors.white,Color(0xFFBDBDBD),Color(0xFFBDBDBD)],
                          stops:[0,.5,.5,1],
                        ),
                      ),
                    ),
                    const SizedBox(width:8),
                    Text(t('transparent'),style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700)),
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
        if(_contrast(background ? fg : color, background ? color : bg) < 4.5){
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
            color:selected ? const Color(0xFF7A00FF) : Theme.of(context).colorScheme.outline,
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

  Widget preview()=>Column(children:[previewCard(),const SizedBox(height:10),checkQrButton(),const SizedBox(height:12),footerButtons()]);

  Widget contrastWarning()=>Container(
    margin:const EdgeInsets.only(bottom:10),
    padding:const EdgeInsets.symmetric(horizontal:12,vertical:9),
    decoration:BoxDecoration(
      color:Colors.orange.withOpacity(.14),
      borderRadius:BorderRadius.circular(10),
      border:Border.all(color:Colors.orange.withOpacity(.55)),
    ),
    child:Row(children:[
      const Icon(Icons.warning_amber_rounded,size:19,color:Colors.orange),
      const SizedBox(width:8),
      Expanded(child:Text(t('contrastWarning'),style:const TextStyle(fontSize:11,fontWeight:FontWeight.w600))),
    ]),
  );

  Widget previewCard()=>Container(
    padding:const EdgeInsets.all(14),
    decoration:BoxDecoration(gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFF061B3B),Color(0xFF0A2D59),Color(0xFF350066)]),borderRadius:BorderRadius.circular(18)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      if (_contrast(fg,bg) < 4.5 && !transparentBg) contrastWarning(),
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
        ),
      )),
      const SizedBox(width:14),
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
      final source = RGBLuminanceSource(decodedImage.width, decodedImage.height, pixels);
      final result = QRCodeReader().decode(BinaryBitmap(HybridBinarizer(source)));
      if (!mounted) return;
      setState(() => qrCheckState = result.text == expected ? 'success' : 'mismatch');
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
            shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22)),
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
      child:Container(
        decoration:BoxDecoration(
          gradient:const LinearGradient(colors:[Color(0xFF00C8FF),Color(0xFF7A00FF),Color(0xFFFF5A00)]),
          borderRadius:BorderRadius.circular(24),
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
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(24)),
        ),
      ),
    ),
  ]);
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
  });

  final String data;
  final Color foreground;
  final Color background;
  final String design;
  final ui.Image? logo;
  final double logoScale;
  final int errorLevel;

  @override
  void paint(Canvas canvas, Size size) {
    final level = switch (errorLevel) {
      1 => qr.QrErrorCorrectLevel.L,
      2 => qr.QrErrorCorrectLevel.H,
      3 => qr.QrErrorCorrectLevel.Q,
      _ => qr.QrErrorCorrectLevel.M,
    };
    final code = qr.QrCode.fromData(data: data, errorCorrectLevel: level);
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
      final outer = RRect.fromRectAndRadius(rect, Radius.circular(unit * (design == 'neon' || design == 'mint' || design == 'green' || design == 'red' ? 1.5 : design == 'sunset' || design == 'gold' ? .6 : .15)));
      final scanBacking = background.alpha == 0 ? Colors.white : background;
      final clear = Paint()..color = scanBacking;
      canvas.drawRRect(outer, modules);
      final inset = rect.deflate(unit * 1.15);
      canvas.drawRRect(RRect.fromRectAndRadius(inset, Radius.circular(unit * .25)), clear);
      final inner = inset.deflate(unit * 1.1);      final innerRect = RRect.fromRectAndRadius(inner, Radius.circular(unit * (design == 'neon' ? .5 : .05)));
      canvas.drawRRect(innerRect, modules);
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
      canvas.drawImageRect(logo!, Rect.fromLTWH(0, 0, logo!.width.toDouble(), logo!.height.toDouble()), rect, Paint()..filterQuality = FilterQuality.high);
    }
  }

  @override
  bool shouldRepaint(covariant StyledQrPainter oldDelegate) =>
      data != oldDelegate.data || foreground != oldDelegate.foreground ||
      background != oldDelegate.background || design != oldDelegate.design ||
      logo != oldDelegate.logo || logoScale != oldDelegate.logoScale ||
      errorLevel != oldDelegate.errorLevel;
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
