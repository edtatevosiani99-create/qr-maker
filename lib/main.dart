import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';

void main() => runApp(const QRStudioApp());

enum QRType { url, text, phone, wifi, contact, email, location }

class QRStudioApp extends StatefulWidget {
  const QRStudioApp({super.key});
  @override State<QRStudioApp> createState() => _QRStudioAppState();
}

class _QRStudioAppState extends State<QRStudioApp> {
  ThemeMode themeMode = ThemeMode.light;
  String lang = 'Русский';
  QRType type = QRType.url;
  Color fg = Colors.black, bg = Colors.white;
  double size = 684;
  double logoScale = .22;
  String error = 'M', security = 'WPA';
  bool transparentBg = false;
  Uint8List? photoBytes;
  ui.Image? photoImage;
  final picker = ImagePicker();
  final c = {for (final k in ['main','name','phone','email','subject','message','ssid','password','lat','lon','address']) k: TextEditingController()};

  final labels = const {
    'Русский': {'title':'QR Studio','subtitle':'Создавай • Кастомизируй • Сохраняй','type':'Тип QR-кода','url':'URL','text':'Текст','phone':'Телефон','wifi':'Wi‑Fi','contact':'Контакт','email':'Email','location':'Геолокация','fg':'Цвет QR','bg':'Фон','transparent':'Прозрачный фон','size':'Размер','error':'Коррекция ошибок','save':'Сохранить PNG','share':'Поделиться','name':'Имя','data':'Данные','subject':'Тема','message':'Сообщение','ssid':'Название Wi‑Fi','password':'Пароль','security':'Защита','lat':'Широта','lon':'Долгота','address':'Адрес','photo':'Выбрать фото','logo':'Логотип в QR','logoHint':'По желанию: вставьте картинку из галереи в центр QR','photoSelected':'Логотип выбран • коррекция H','removeLogo':'Удалить логотип','photoError':'Не удалось открыть это изображение','saved':'PNG сохранён в галерею','permission':'Разрешите доступ к галерее','preview':'Ваш QR-код','ready':'Готов к сохранению','logoSize':'Размер логотипа','qrColorButton':'Выбрать цвет QR','bgColorButton':'Выбрать цвет фона','lowContrastQr':'Низкий контраст: выберите более тёмный цвет QR.','lowContrastBg':'Низкий контраст: выберите более светлый фон.','none':'Без защиты'},
    'English': {'title':'QR Studio','subtitle':'Create • Customize • Save','type':'QR code type','url':'URL','text':'Text','phone':'Phone','wifi':'Wi‑Fi','contact':'Contact','email':'Email','location':'Location','fg':'QR color','bg':'Background','transparent':'Transparent background','size':'Size','error':'Error correction','save':'Save PNG','share':'Share','name':'Name','data':'Data','subject':'Subject','message':'Message','ssid':'Wi‑Fi name','password':'Password','security':'Security','lat':'Latitude','lon':'Longitude','address':'Address','photo':'Choose photo','logo':'Logo in QR','logoHint':'Optional: add an image from the gallery to the center','photoSelected':'Logo selected • correction H','removeLogo':'Remove logo','photoError':'Could not open this image','saved':'PNG saved to gallery','permission':'Please allow gallery access','preview':'Your QR code','ready':'Ready to save','logoSize':'Logo size','qrColorButton':'Choose QR color','bgColorButton':'Choose background color','lowContrastQr':'Low contrast: choose a darker QR color.','lowContrastBg':'Low contrast: choose a lighter background.','none':'No security'},
    'Deutsch': {'title':'QR Studio','subtitle':'Erstellen • Anpassen • Speichern','type':'QR-Code-Typ','url':'URL','text':'Text','phone':'Telefon','wifi':'WLAN','contact':'Kontakt','email':'E-Mail','location':'Standort','fg':'QR-Farbe','bg':'Hintergrund','transparent':'Transparenter Hintergrund','size':'Größe','error':'Fehlerkorrektur','save':'PNG speichern','share':'Teilen','name':'Name','data':'Daten','subject':'Betreff','message':'Nachricht','ssid':'WLAN-Name','password':'Passwort','security':'Sicherheit','lat':'Breitengrad','lon':'Längengrad','address':'Adresse','photo':'Foto auswählen','logo':'Logo im QR','logoHint':'Optional: Bild aus der Galerie in die Mitte einfügen','photoSelected':'Logo ausgewählt • Korrektur H','removeLogo':'Logo entfernen','photoError':'Bild konnte nicht geöffnet werden','saved':'PNG in Galerie gespeichert','permission':'Bitte Galeriezugriff erlauben','preview':'Ihr QR-Code','ready':'Bereit zum Speichern','logoSize':'Logogröße','qrColorButton':'QR-Farbe wählen','bgColorButton':'Hintergrundfarbe wählen','lowContrastQr':'Zu geringer Kontrast: Wählen Sie eine dunklere QR-Farbe.','lowContrastBg':'Zu geringer Kontrast: Wählen Sie einen helleren Hintergrund.','none':'Keine Sicherheit'},
    'ქართული': {'title':'QR Studio','subtitle':'შექმენი • მოარგე • შეინახე','type':'QR კოდის ტიპი','url':'URL','text':'ტექსტი','phone':'ტელეფონი','wifi':'Wi‑Fi','contact':'კონტაქტი','email':'ელფოსტა','location':'გეოლოკაცია','fg':'QR ფერი','bg':'ფონი','transparent':'გამჭვირვალე ფონი','size':'ზომა','error':'შეცდომის გასწორება','save':'PNG შენახვა','share':'გაზიარება','name':'სახელი','data':'მონაცემები','subject':'თემა','message':'შეტყობინება','ssid':'Wi‑Fi სახელი','password':'პაროლი','security':'დაცვა','lat':'გრძედი','lon':'განედი','address':'მისამართი','photo':'ფოტოს არჩევა','logo':'ლოგო QR-ში','logoHint':'სურვილისამებრ: გალერეიდან სურათი ჩასვით QR-ის ცენტრში','photoSelected':'ლოგო არჩეულია • კორექცია H','removeLogo':'ლოგოს წაშლა','photoError':'სურათი ვერ გაიხსნა','saved':'PNG გალერეაში შეინახა','permission':'გთხოვთ დაუშვათ გალერეაზე წვდომა','preview':'თქვენი QR კოდი','ready':'მზადაა შესანახად','logoSize':'ლოგოს ზომა','qrColorButton':'QR ფერის არჩევა','bgColorButton':'ფონის ფერის არჩევა','lowContrastQr':'კონტრასტი ძალიან დაბალია: აირჩიეთ უფრო მუქი QR ფერი.','lowContrastBg':'კონტრასტი ძალიან დაბალია: აირჩიეთ უფრო ღია ფონი.','none':'დაცვის გარეშე'}
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

  bool _safeColorPair(Color qr, Color background) =>
      _contrast(qr, background) >= 4.5;

  void _setQrColor(Color color) {
    if (!_safeColorPair(color, bg)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('lowContrastQr'))));
      return;
    }
    setState(() => fg = color);
  }

  void _setBackgroundColor(Color color) {
    if (!_safeColorPair(fg, color)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('lowContrastBg'))));
      return;
    }
    setState(() {
      bg = color;
      transparentBg = false;
    });
  }


  int get errorLevel => const {'L':1,'M':0,'Q':3,'H':2}[error] ?? 0;

  @override void initState() { super.initState(); c['main']!.text = 'https://example.com'; }
  @override void dispose() { photoImage?.dispose(); for (final x in c.values) x.dispose(); super.dispose(); }

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
      if (!mounted) { frame.image.dispose(); return; }
      setState(() {
        photoBytes = b;
        photoImage = frame.image;
        error = 'H';
      });
      old?.dispose();
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
    setState(() {
      photoBytes = null;
      photoImage = null;
    });
    old?.dispose();
  }

  Future<Uint8List?> pngBytes() async {
    final p = QrPainter(data:data.isEmpty ? ' ' : data, version:QrVersions.auto, errorCorrectionLevel:errorLevel, gapless:true, color:fg, emptyColor:transparentBg ? Colors.transparent : bg, embeddedImage:photoImage, embeddedImageStyle:photoImage == null ? null : QrEmbeddedImageStyle(size:Size(size * logoScale, size * logoScale)));
    final d = await p.toImageData(size, format:ui.ImageByteFormat.png);
    return d?.buffer.asUint8List();
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
      theme:ThemeData(useMaterial3:true, brightness:Brightness.light, scaffoldBackgroundColor:const Color(0xFFF7F8FC), colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xFF2B7FFF))),
      darkTheme:ThemeData(useMaterial3:true, brightness:Brightness.dark, scaffoldBackgroundColor:const Color(0xFF03152C), colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xFF1E9BFF), brightness:Brightness.dark)),
      home:Scaffold(
        body:SafeArea(child:LayoutBuilder(builder:(ctx,box) {
          final wide = box.maxWidth > 820;
          return SingleChildScrollView(
            padding:EdgeInsets.fromLTRB(wide ? 28 : 16,10,wide ? 28 : 16,28),
            child:Center(child:ConstrainedBox(
              constraints:const BoxConstraints(maxWidth:980),
              child:wide ? Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:form()),const SizedBox(width:24),Expanded(child:preview())]) : Column(children:[header(),const SizedBox(height:16),formBody(),const SizedBox(height:18),previewCard(),const SizedBox(height:18),footerButtons()]),
            )),
          );
        })),
      ),
    );
  }

  Widget header() => Row(children:[
    logo(54), const SizedBox(width:11),
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      ShaderMask(shaderCallback:(r)=>const LinearGradient(colors:[Color(0xFF00C8FF),Color(0xFFB000FF),Color(0xFFFF6B00)]).createShader(r),child:Text(t('title'),style:const TextStyle(fontSize:25,fontWeight:FontWeight.w800,color:Colors.white))),
      Text(t('subtitle'),style:TextStyle(fontSize:11,color:Theme.of(context).colorScheme.onSurfaceVariant)),
    ])),
    languageButton(), const SizedBox(width:4),
    IconButton(onPressed:()=>setState(()=>themeMode=themeMode==ThemeMode.light?ThemeMode.dark:ThemeMode.light),icon:Icon(themeMode==ThemeMode.light?Icons.dark_mode:Icons.light_mode)),
  ]);

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

  Widget form() => Column(children:[header(),const SizedBox(height:16),formBody(),const SizedBox(height:18),footerButtons()]);

  Widget formBody() => Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Text(t('type'),style:const TextStyle(fontSize:16,fontWeight:FontWeight.w700)),const SizedBox(height:9),
    Wrap(spacing:7,runSpacing:7,children:[QRType.url,QRType.text,QRType.phone,QRType.wifi,QRType.contact,QRType.email,QRType.location].map(typeChip).toList()),
    const SizedBox(height:16),specific(),
    if(type==QRType.wifi) ...[
      const SizedBox(height:2),
      DropdownButtonFormField<String>(value:security,decoration:fieldDecoration(t('security')),items:['WPA','WEP','None'].map((x)=>DropdownMenuItem(value:x,child:Text(x=='None'?t('none'):x))).toList(),onChanged:(x)=>setState(()=>security=x!)),
    ],
    if(type==QRType.location) ...[input('lat',t('lat'),keyboard:TextInputType.number),input('lon',t('lon'),keyboard:TextInputType.number),input('address',t('address'))],
    const SizedBox(height:4),Text(t('fg'),style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700)),const SizedBox(height:6),gradientColorBar(false),
    const SizedBox(height:12),Text(t('bg'),style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700)),const SizedBox(height:6),gradientColorBar(true),
    const SizedBox(height:13),Text(t('size') + ': ' + size.round().toString() + ' px',style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700)),
    Slider(min:256,max:1024,value:size,activeColor:const Color(0xFF5B2DFF),onChanged:(x)=>setState(()=>size=x)),
    Text(t('error'),style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700)),const SizedBox(height:6),
    DropdownButtonFormField<String>(value:error,decoration:fieldDecoration(''),items:['L','M','Q','H'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x)=>setState(()=>error=x!)),
    const SizedBox(height:10),
    logoSection(),
    if (photoImage != null) ...[
      const SizedBox(height:10),
      Text(t('logoSize') + ': ' + (logoScale * 100).round().toString() + '%',
          style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700)),
      Slider(
        min:.10,
        max:.35,
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

  Widget gradientColorBar(bool background)=>Column(
    crossAxisAlignment:CrossAxisAlignment.stretch,
    children:[
      LayoutBuilder(builder:(context,constraints){
        final width=constraints.maxWidth;
        final current=background ? bg : fg;
        return GestureDetector(
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
        );
      }),
      const SizedBox(height:7),
      Row(
        children:[
          _quickColor(background, const Color(0xFF000000)),
          const SizedBox(width:10),
          _quickColor(background, const Color(0xFFFFFFFF)),
          const SizedBox(width:10),
          Expanded(
            child:OutlinedButton.icon(
              onPressed:()=>colorPicker(background),
              icon:const Icon(Icons.palette_outlined,size:18),
              label:Text(background ? t('bgColorButton') : t('qrColorButton')),
              style:OutlinedButton.styleFrom(
                minimumSize:const Size.fromHeight(42),
                shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _quickColor(bool background, Color color){
    final selected = (background ? bg : fg).value == color.value && !(background && transparentBg);
    return InkWell(
      onTap:()=>setQuickColor(background,color),
      borderRadius:BorderRadius.circular(24),
      child:Container(
        width:42,
        height:42,
        decoration:BoxDecoration(
          color:color,
          shape:BoxShape.circle,
          border:Border.all(
            color:color.computeLuminance()>.75 ? Colors.black45 : Colors.white70,
            width:selected ? 3 : 1,
          ),
          boxShadow:selected
            ? [BoxShadow(color:color.withOpacity(.5),blurRadius:5,spreadRadius:1)]
            : null,
        ),
        child:selected
          ? Icon(Icons.check,color:color.computeLuminance()>.55 ? Colors.black : Colors.white,size:20)
          : null,
      ),
    );
  }

  double currentHue(Color color) => HSVColor.fromColor(color).hue;

  void setColorFromPosition(bool background,double x,double width){
    final p=(x/width).clamp(0.0,1.0);
    final color=HSVColor.fromAHSV(1,p*360,1,1).toColor();
    setState((){
      if(background){
        bg=color;
        transparentBg=false;
      }else{
        fg=color;
      }
    });
  }

  void setQuickColor(bool background, Color color){
    if(!_safeColorPair(background ? fg : color, background ? color : bg)){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text(background ? t('lowContrastBg') : t('lowContrastQr'))),
      );
      return;
    }
    setState((){
      if(background){
        bg=color;
        transparentBg=false;
      }else{
        fg=color;
      }
    });
  }

  Future<void> colorPicker(bool background) async {
    final colors=<Color>[
      const Color(0xFF000000),const Color(0xFFFFFFFF),const Color(0xFF263238),
      const Color(0xFFFF0000),const Color(0xFFFF5722),const Color(0xFFFF9800),const Color(0xFFFFC107),
      const Color(0xFFFFFF00),const Color(0xFF8BC34A),const Color(0xFF00A86B),const Color(0xFF00C853),
      const Color(0xFF00BCD4),const Color(0xFF00D9FF),const Color(0xFF2196F3),const Color(0xFF3155FF),
      const Color(0xFF3F51B5),const Color(0xFF673AB7),const Color(0xFF8B00FF),const Color(0xFFE000FF),
      const Color(0xFFFF1493),const Color(0xFFFF4081),const Color(0xFF795548),const Color(0xFF9E9E9E),
      const Color(0xFFBDBDBD),const Color(0xFFF5F5F5),
    ];

    final picked=await showDialog<Color>(
      context:context,
      builder:(dialogContext)=>AlertDialog(
        title:Text(background ? 'Выберите цвет фона' : 'Выберите цвет QR'),
        content:SizedBox(
          width:320,
          child:GridView.builder(
            shrinkWrap:true,
            itemCount:colors.length,
            gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount:5,
              crossAxisSpacing:12,
              mainAxisSpacing:12,
              childAspectRatio:1,
            ),
            itemBuilder:(_,i){
              final x=colors[i];
              final selected=background
                  ? (!transparentBg && bg.value==x.value)
                  : fg.value==x.value;
              return Material(
                color:Colors.transparent,
                child:InkWell(
                  borderRadius:BorderRadius.circular(30),
                  onTap:()=>Navigator.of(dialogContext).pop(x),
                  child:Container(
                    decoration:BoxDecoration(
                      color:x,
                      shape:BoxShape.circle,
                      border:Border.all(
                        color:x.computeLuminance()>.75 ? Colors.black45 : Colors.white70,
                        width:selected ? 3 : 1,
                      ),
                      boxShadow:selected
                          ? [BoxShadow(color:x.withOpacity(.6),blurRadius:6,spreadRadius:1)]
                          : null,
                    ),
                    child:selected
                        ? Icon(
                            Icons.check,
                            color:x.computeLuminance()>.55 ? Colors.black : Colors.white,
                            size:22,
                          )
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
        actions:[
          if(background)
            TextButton(
              onPressed:()=>Navigator.of(dialogContext).pop(const Color(0x00000000)),
              child:Text(t('transparent')),
            ),
          TextButton(
            onPressed:()=>Navigator.of(dialogContext).pop(),
            child:Text(MaterialLocalizations.of(dialogContext).cancelButtonLabel),
          ),
        ],
      ),
    );

    if(!mounted || picked==null) return;
    if(background){
      if(picked.value==0x00000000){
        setState(()=>transparentBg=true);
      }else{
        _setBackgroundColor(picked);
      }
    }else{
      _setQrColor(picked);
    }
  }

  Widget backgroundSelector()=>GestureDetector(
    onTap:()=>colorPicker(true),
    child:Container(
      height:48,
      padding:const EdgeInsets.symmetric(horizontal:14),
      decoration:BoxDecoration(
        color:Theme.of(context).colorScheme.surface,
        borderRadius:BorderRadius.circular(10),
        border:Border.all(color:Theme.of(context).colorScheme.outlineVariant),
      ),
      child:Row(children:[
        Container(
          width:24,height:24,
          decoration:BoxDecoration(
            color:transparentBg ? Colors.transparent : bg,
            shape:BoxShape.circle,
            border:Border.all(color:Theme.of(context).colorScheme.outlineVariant),
          ),
          child:transparentBg ? const Icon(Icons.texture,size:15) : null,
        ),
        const SizedBox(width:9),
        Expanded(child:Text(transparentBg?t('transparent'):'Цвет фона',style:const TextStyle(fontSize:12))),
        const Icon(Icons.keyboard_arrow_down,size:20),
      ]),
    ),
  );

  Widget preview()=>Column(children:[previewCard(),const SizedBox(height:18),footerButtons()]);

  Widget previewCard()=>Container(
    padding:const EdgeInsets.all(14),
    decoration:BoxDecoration(gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFF061B3B),Color(0xFF0A2D59),Color(0xFF350066)]),borderRadius:BorderRadius.circular(18)),
    child:Row(children:[
      Container(width:112,height:112,padding:const EdgeInsets.all(8),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14)),child:CustomPaint(
        key:ValueKey('\${fg.value}-\${bg.value}-\${transparentBg}-\${error}-\${photoImage != null}-\${data}'),
        size:const Size(96,96),
        painter:QrPainter(
          data:data.isEmpty?' ':data,
          version:QrVersions.auto,
          errorCorrectionLevel:errorLevel,
          gapless:true,
          color:fg,
          emptyColor:transparentBg?Colors.transparent:bg,
          embeddedImage:photoImage,
          embeddedImageStyle:photoImage == null ? null : QrEmbeddedImageStyle(size:Size(96 * logoScale,96 * logoScale)),
        ),
      )),
      const SizedBox(width:14),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(t('preview'),style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700,fontSize:14)),const SizedBox(height:5),Text(t('ready'),style:TextStyle(color:Colors.white.withOpacity(.78),fontSize:11))])),
    ]),
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
