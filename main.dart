import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

void main() => runApp(const QRStudioApp());

enum QRType { url, text, phone, wifi, contact, email, location }

class _QRStudioAppState extends State<QRStudioApp> {
  ThemeMode themeMode = ThemeMode.light;
  String lang = 'Русский';
  QRType type = QRType.url;
  Color fg = Colors.black, bg = Colors.white;
  double size = 280;
  String error = 'M';
  String security = 'WPA';
  Uint8List? photoBytes;
  int logoSize = 1; // 0 small, 1 medium, 2 large
  final picker = ImagePicker();
  final c = {for (final k in ['main','name','phone','email','subject','message','ssid','password','lat','lon','address']) k: TextEditingController()};

  final labels = const {
    'Русский': {'title':'QR Studio','type':'Тип QR-кода','data':'Данные','fg':'Цвет QR','bg':'Фон','chooseFg':'Выбрать цвет','chooseBg':'Выбрать цвет фона','size':'Размер','error':'Коррекция ошибок','save':'Сохранить PNG','share':'Поделиться','name':'Имя','phone':'Телефон','email':'Email','subject':'Тема','message':'Сообщение','ssid':'Название Wi‑Fi','password':'Пароль','security':'Защита','lat':'Широта','lon':'Долгота','address':'Адрес','photo':'Выбрать фото','logoSize':'Размер логотипа','small':'Маленький','medium':'Средний','large':'Большой'},
    'English': {'title':'QR Studio','type':'QR type','data':'Data','fg':'QR color','bg':'Background','chooseFg':'Choose color','chooseBg':'Choose background color','size':'Size','error':'Error correction','save':'Save PNG','share':'Share','name':'Name','phone':'Phone','email':'Email','subject':'Subject','message':'Message','ssid':'Wi‑Fi name','password':'Password','security':'Security','lat':'Latitude','lon':'Longitude','address':'Address','photo':'Choose photo','logoSize':'Logo size','small':'Small','medium':'Medium','large':'Large'},
    'Deutsch': {'title':'QR Studio','type':'QR-Typ','data':'Daten','fg':'QR-Farbe','bg':'Hintergrund','chooseFg':'Farbe auswählen','chooseBg':'Hintergrundfarbe auswählen','size':'Größe','error':'Fehlerkorrektur','save':'PNG speichern','share':'Teilen','name':'Name','phone':'Telefon','email':'E-Mail','subject':'Betreff','message':'Nachricht','ssid':'WLAN-Name','password':'Passwort','security':'Sicherheit','lat':'Breitengrad','lon':'Längengrad','address':'Adresse','photo':'Foto auswählen','logoSize':'Logo-Größe','small':'Klein','medium':'Mittel','large':'Groß'},
    'ქართული': {'title':'QR Studio','type':'QR ტიპი','data':'მონაცემები','fg':'QR ფერი','bg':'ფონი','chooseFg':'ფერის არჩევა','chooseBg':'ფონის ფერის არჩევა','size':'ზომა','error':'შეცდომის გასწორება','save':'PNG შენახვა','share':'გაზიარება','name':'სახელი','phone':'ტელეფონი','email':'ელფოსტა','subject':'თემა','message':'შეტყობინება','ssid':'Wi‑Fi სახელი','password':'პაროლი','security':'დაცვა','lat':'გრძედი','lon':'განედი','address':'მისამართი','photo':'ფოტოს არჩევა','logoSize':'ლოგოს ზომა','small':'პატარა','medium':'საშუალო','large':'დიდი'}
  };
  String t(String k) => labels[lang]![k] ?? k;
  String v(String k) => c[k]!.text.trim();
  double _luminance(Color c) {
    double f(int x) {
      final v = x / 255.0;
      return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) * ((v + 0.055) / 1.055) * ((v + 0.055) / 1.055);
    }
    return 0.2126 * f(c.red) + 0.7152 * f(c.green) + 0.0722 * f(c.blue);
  }

  double _contrast(Color a, Color b) {
    final l1 = _luminance(a), l2 = _luminance(b);
    final hi = l1 > l2 ? l1 : l2, lo = l1 > l2 ? l2 : l1;
    return (hi + 0.05) / (lo + 0.05);
  }

  bool _safePair(Color qr, Color background) {
    final contrast = _contrast(qr, background);
    return contrast >= 4.5 && _luminance(qr) < _luminance(background);
  }

  void _setQrColor(Color color) {
    if (!_safePair(color, bg)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Предупреждение: низкий контраст QR и фона — сканирование может быть затруднено.')),
      );
    }
    setState(() => fg = color);
  }

  void _setBackgroundColor(Color color) {
    if (!_safePair(fg, color)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Предупреждение: низкий контраст QR и фона — сканирование может быть затруднено.')),
      );
    }
    setState(() => bg = color);
  }


  @override void initState() { super.initState(); c['main']!.text='https://example.com'; }
  @override void dispose() { for(final x in c.values) x.dispose(); super.dispose(); }

  String get data {
    switch(type) {
      case QRType.url: case QRType.text: return v('main');
      case QRType.phone: return 'tel:${v('phone')}';
      case QRType.wifi:
        final s = security == 'None' ? 'nopass' : security;
        String e(String x) => x.replaceAll(r'\\',r'\\\\').replaceAll(';',r'\\;').replaceAll(':',r'\\:').replaceAll(',',r'\\,');
        return 'WIFI:T:$s;S:${e(v('ssid'))};P:${e(v('password'))};;';
      case QRType.contact: return 'BEGIN:VCARD\\nVERSION:3.0\\nFN:${v('name')}\\nTEL:${v('phone')}\\nEMAIL:${v('email')}\\nEND:VCARD';
      case QRType.email: return 'mailto:${v('email')}?subject=${Uri.encodeComponent(v('subject'))}&body=${Uri.encodeComponent(v('message'))}';
      case QRType.location: return 'geo:${v('lat')},${v('lon')}?q=${Uri.encodeComponent(v('address'))}';
    }
  }

  Future<void> choosePhoto() async {
    final x=await picker.pickImage(source: ImageSource.gallery);
    if(x!=null){ final b=await x.readAsBytes(); if(mounted)setState(()=>photoBytes=b); }
  }

  double get logoFactor => const [0.18, 0.24, 0.30][logoSize];
  double logoPx(double qrSize) => qrSize * logoFactor;

  Future<ui.Image?> logoImage() async {
    if(photoBytes == null) return null;
    final c = Completer<ui.Image>();
    ui.decodeImageFromList(photoBytes!, (image) => c.complete(image));
    return c.future;
  }

  QrPainter painterFor(ui.Image? logo) => QrPainter(
    data:data.isEmpty?' ':data,
    version:QrVersions.auto,
    errorCorrectionLevel:error,
    gapless:true,
    color:fg,
    emptyColor:bg,
    eyeStyle:QrEyeStyle(eyeShape:QrEyeShape.square,color:fg),
    dataModuleStyle:QrDataModuleStyle(dataModuleShape:QrDataModuleShape.square,color:fg),
    embeddedImage:logo,
    embeddedImageStyle: logo == null ? null : QrEmbeddedImageStyle(
      size:Size.square(logoPx(size)),
      safeArea:true,
      safeAreaMultiplier:1.15,
      embeddedImageShape:EmbeddedImageShape.square,
      shapeColor:bg,
    ),
  );

  Future<Uint8List?> pngBytes() async {
    final logo = await logoImage();
    final p=painterFor(logo);
    final d=await p.toImageData(size,format:ui.ImageByteFormat.png);
    return d?.buffer.asUint8List();
  }

  Future<void> savePng() async {
    final b=await pngBytes(); if(b==null)return;
    final dir=await getApplicationDocumentsDirectory();
    await File('${dir.path}/QR_${DateTime.now().millisecondsSinceEpoch}.png').writeAsBytes(b);
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('PNG saved')));
  }

  Future<void> sharePng() async {
    final b=await pngBytes(); if(b==null)return;
    final dir=await getTemporaryDirectory();
    final f=File('${dir.path}/QR_Studio.png'); await f.writeAsBytes(b);
    await Share.shareXFiles([XFile(f.path)],text:'QR Studio');
  }

  Widget input(String key,String label,{TextInputType? keyboard}) => Padding(
    padding:const EdgeInsets.only(bottom:12),
    child:TextField(controller:c[key],keyboardType:keyboard,onChanged:(_)=>setState((){}),decoration:InputDecoration(labelText:label,border:const OutlineInputBorder())));

  @override Widget build(BuildContext context)=>MaterialApp(
    debugShowCheckedModeBanner:false,themeMode:themeMode,
    theme:ThemeData(useMaterial3:true,colorSchemeSeed:Colors.indigo),
    darkTheme:ThemeData(useMaterial3:true,colorSchemeSeed:Colors.indigo,brightness:Brightness.dark),
    home:Scaffold(appBar:AppBar(title:Row(mainAxisSize:MainAxisSize.min,children:[Image.asset('app_icon.png',width:32,height:32,fit:BoxFit.contain),const SizedBox(width:8),Text(t('title'))]),actions:[
      DropdownButton<String>(value:lang,underline:const SizedBox(),items:labels.keys.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x)=>setState(()=>lang=x!)),
      IconButton(onPressed:()=>setState(()=>themeMode=themeMode==ThemeMode.light?ThemeMode.dark:ThemeMode.light),icon:Icon(themeMode==ThemeMode.light?Icons.dark_mode:Icons.light_mode))
    ]),
    body:LayoutBuilder(builder:(ctx,box)=>SingleChildScrollView(padding:const EdgeInsets.all(16),child:Center(child:ConstrainedBox(
      constraints:const BoxConstraints(maxWidth:1050),
      child:box.maxWidth>760?Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:form()),const SizedBox(width:24),Expanded(child:preview())]):Column(children:[form(),const SizedBox(height:20),preview()])
    ))))
  );

  Widget form()=>Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Text(t('type'),style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:10),
    Wrap(spacing:8,runSpacing:8,children:[
      (QRType.url,'🔗 URL'),(QRType.text,'📝 Text'),(QRType.phone,'📞 Phone'),(QRType.wifi,'📶 Wi‑Fi'),(QRType.contact,'👤 Contact'),(QRType.email,'✉️ Email'),(QRType.location,'📍 Location')
    ].map((x)=>ChoiceChip(label:Text(x.$2),selected:type==x.$1,onSelected:(_)=>setState(()=>type=x.$1))).toList()),
    const SizedBox(height:18),specific(),
    if(type==QRType.wifi)DropdownButtonFormField<String>(value:security,decoration:InputDecoration(labelText:t('security'),border:const OutlineInputBorder()),items:const ['WPA','WEP','None'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x)=>setState(()=>security=x!)),
    if(type==QRType.location)...[input('lat',t('lat'),keyboard:TextInputType.number),input('lon',t('lon'),keyboard:TextInputType.number),input('address',t('address'))],
    Text(t('fg')),const SizedBox(height:5),colorButton(t('chooseFg'),fg,_setQrColor),const SizedBox(height:12),
    Text(t('bg')),const SizedBox(height:5),colorButton(t('chooseBg'),bg,_setBackgroundColor),const SizedBox(height:12),
    Text('${t('size')}: ${size.round()} px'),Slider(min:128,max:1024,value:size,onChanged:(x)=>setState(()=>size=x)),
    Text(t('error')),DropdownButton<String>(value:error,items:const ['L','M','Q','H'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x)=>setState(()=>error=x!)),
    if(photoBytes!=null)...[
      const SizedBox(height:8),Text(t('logoSize')),const SizedBox(height:5),
      Wrap(spacing:8,children:[
        ChoiceChip(label:Text(t('small')),selected:logoSize==0,onSelected:(_)=>setState(()=>logoSize=0)),
        ChoiceChip(label:Text(t('medium')),selected:logoSize==1,onSelected:(_)=>setState(()=>logoSize=1)),
        ChoiceChip(label:Text(t('large')),selected:logoSize==2,onSelected:(_)=>setState(()=>logoSize=2)),
      ]),
    ],
    OutlinedButton.icon(onPressed:choosePhoto,icon:const Icon(Icons.photo),label:Text(t('photo'))),
    const SizedBox(height:12),Row(children:[Expanded(child:FilledButton.icon(onPressed:savePng,icon:const Icon(Icons.download),label:Text(t('save')))),const SizedBox(width:10),Expanded(child:OutlinedButton.icon(onPressed:sharePng,icon:const Icon(Icons.share),label:Text(t('share'))))])
  ]);

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

  Widget preview()=>Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(children:[
    Text('Preview',style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:16),
    QrImageView(
      key:ValueKey('${fg.value}-${bg.value}-$logoSize-${photoBytes?.length}'),
      data:data.isEmpty?' ':data,
      size:size.clamp(180,340),
      version:QrVersions.auto,
      errorCorrectionLevel:error,
      gapless:true,
      foregroundColor:fg,
      backgroundColor:bg,
      embeddedImage:photoBytes==null?null:MemoryImage(photoBytes!),
      embeddedImageStyle:photoBytes==null?null:QrEmbeddedImageStyle(
        size:Size.square(logoPx(size.clamp(180,340))),
        safeArea:true,
        safeAreaMultiplier:1.15,
        embeddedImageShape:EmbeddedImageShape.square,
        shapeColor:bg,
      ),
    ),
    const SizedBox(height:12),SelectableText(data.isEmpty?' ':data,textAlign:TextAlign.center,maxLines:7),
  ]));

  Widget colorButton(String label,Color color,ValueChanged<Color> cb)=>OutlinedButton.icon(
    onPressed:()=>showModalBottomSheet(context:context,builder:(_)=>SafeArea(child:Padding(
      padding:const EdgeInsets.all(24),
      child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Text(label,style:Theme.of(context).textTheme.titleMedium),
        const SizedBox(height:16),
        Wrap(spacing:14,runSpacing:14,children:[
          Colors.black,Colors.white,Colors.grey,Colors.indigo,Colors.blue,Colors.red,
          Colors.green,Colors.orange,Colors.purple,Colors.teal
        ].map((x)=>GestureDetector(
          onTap:(){cb(x);Navigator.pop(context);},
          child:Container(width:48,height:48,decoration:BoxDecoration(
            color:x,shape:BoxShape.circle,border:Border.all(color:Colors.grey,width:1.5)
          ))
        )).toList()),
        const SizedBox(height:12),
        Container(height:10,decoration:BoxDecoration(color:color,borderRadius:BorderRadius.circular(5))),
      ])
    ))),
    icon:Container(width:24,height:24,decoration:BoxDecoration(color:color,shape:BoxShape.circle,border:Border.all())),
    label:Text(label),
  );
}

class QRStudioApp extends StatefulWidget {
  const QRStudioApp({super.key});
  @override State<QRStudioApp> createState() => _QRStudioAppState();
}
