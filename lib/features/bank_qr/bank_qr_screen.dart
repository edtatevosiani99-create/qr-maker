import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

/// Independent free Bank QR screen; the existing QR generator stays separate.
class BankQrScreen extends StatefulWidget {
  const BankQrScreen({super.key, this.language = 'English'});
  final String language;
  @override State<BankQrScreen> createState() => _BankQrScreenState();
}
class _BankQrScreenState extends State<BankQrScreen> {
  final name = TextEditingController();
  final card = TextEditingController();
  final iban = TextEditingController();
  final amount = TextEditingController();
  final reference = TextEditingController();
  bool cardMode = true;
  bool get ru => widget.language == 'Русский';
  bool get de => widget.language == 'Deutsch';
  bool get ka => widget.language == 'ქართული';
  String tr(String en, String r, String d, String k) => ru ? r : de ? d : ka ? k : en;
  String get cardDigits => card.text.replaceAll(RegExp(r'\D'), '');
  String get cleanIban => iban.text.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  String get payload {
    final recipient = name.text.trim();
    if (recipient.isEmpty) return '';
    if (cardMode) {
      if (cardDigits.length != 16) return '';
      return 'QR Studio — card payment details\nName: ' + recipient +
        '\nCard: ' + cardDigits +
        '\nUse your bank/provider app if it supports transfers to this card.';
    }
    if (cleanIban.length < 15 || cleanIban.length > 34) return '';
    final rawAmount = amount.text.trim().replaceAll(',', '.');
    final parsed = double.tryParse(rawAmount);
    if (rawAmount.isNotEmpty && (parsed == null || parsed <= 0)) return '';
    final formattedAmount = rawAmount.isEmpty ? '' : 'EUR' + parsed!.toStringAsFixed(2);
    final memo = reference.text.trim().replaceAll('\n', ' ');
    return ['BCD', '002', '1', 'SCT', '', recipient, cleanIban, formattedAmount, '', memo].join('\n');
  }
  @override void dispose() {
    name.dispose(); card.dispose(); iban.dispose(); amount.dispose(); reference.dispose(); super.dispose();
  }
  Widget field(String label, TextEditingController controller, {TextInputType? keyboard, List<TextInputFormatter>? formatters, String? hint, String? helper}) =>
    Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(
      controller: controller, keyboardType: keyboard, inputFormatters: formatters, onChanged: (_) => setState(() {}),
      decoration: InputDecoration(labelText: label, hintText: hint, helperText: helper, filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
    ));
  void message(String text) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); }
  Future<Uint8List?> png() async {
    if (payload.isEmpty) return null;
    final painter = QrPainter(data: payload, version: QrVersions.auto, gapless: true, color: const Color(0xFF06172B), emptyColor: Colors.white);
    final bytes = await painter.toImageData(1000, format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  }
  Future<void> save() async {
    final bytes = await png();
    if (bytes == null) { message(tr('Complete required fields first.', 'Сначала заполните обязательные поля.', 'Bitte Pflichtfelder ausfüllen.', 'შეავსეთ აუცილებელი ველები.')); return; }
    try {
      if (!await Gal.hasAccess() && !await Gal.requestAccess()) { message(tr('Gallery access is required.', 'Нужен доступ к галерее.', 'Galerie-Zugriff erforderlich.', 'საჭიროა გალერეაზე წვდომა.')); return; }
      await Gal.putImageBytes(bytes, album: 'QR Studio Bank QR');
      message(tr('QR saved to gallery.', 'QR сохранён в галерею.', 'QR in Galerie gespeichert.', 'QR გალერეაში შეინახა.'));
    } catch (_) { message(tr('Could not save QR.', 'Не удалось сохранить QR.', 'QR konnte nicht gespeichert werden.', 'QR-ის შენახვა ვერ მოხერხდა.')); }
  }
  Future<void> share() async {
    final bytes = await png();
    if (bytes == null) { message(tr('Complete required fields first.', 'Сначала заполните обязательные поля.', 'Bitte Pflichtfelder ausfüllen.', 'შეავსეთ აუცილებელი ველები.')); return; }
    try {
      final dir = await getTemporaryDirectory();
      final file = File(dir.path + '/bank_qr.png');
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles([XFile(file.path)], text: 'QR Studio Bank QR');
    } catch (_) { message(tr('Could not share QR.', 'Не удалось поделиться QR.', 'QR konnte nicht geteilt werden.', 'QR-ის გაზიარება ვერ მოხერხდა.')); }
  }
  @override Widget build(BuildContext context) {
    final valid = payload.isNotEmpty;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Bank QR')),
      body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Center(
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 620), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('Choose QR type', 'Выберите тип QR', 'QR-Typ wählen', 'აირჩიეთ QR-ის ტიპი'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              ChoiceChip(selected: cardMode, avatar: const Icon(Icons.credit_card, size: 18), label: const Text('Visa / Mastercard'), onSelected: (_) => setState(() => cardMode = true)),
              ChoiceChip(selected: !cardMode, avatar: const Icon(Icons.account_balance, size: 18), label: Text(tr('IBAN transfer', 'Перевод по IBAN', 'IBAN-Überweisung', 'IBAN გადარიცხვა')), onSelected: (_) => setState(() => cardMode = false)),
            ]),
            const SizedBox(height: 12),
            field(tr('Recipient full name', 'Имя и фамилия получателя', 'Vollständiger Empfängername', 'მიმღების სახელი და გვარი'), name),
            if (cardMode) field(tr('16-digit card number', 'Номер карты из 16 цифр', '16-stellige Kartennummer', 'ბარათის 16-ნიშნა ნომერი'), card, keyboard: TextInputType.number, formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(16)], hint: '0000 0000 0000 0000', helper: tr('Never enter PIN, CVV, or expiry date.', 'Не вводите PIN, CVV или срок действия.', 'Niemals PIN, CVV oder Ablaufdatum eingeben.', 'არ შეიყვანოთ PIN, CVV ან ვადის თარიღი.')),
            if (!cardMode) ...[
              field('IBAN', iban, hint: 'DE00 0000 0000 0000 0000 00'),
              field(tr('Amount in EUR (optional)', 'Сумма в EUR (необязательно)', 'Betrag in EUR (optional)', 'თანხა EUR-ში (არასავალდებულო)'), amount, keyboard: const TextInputType.numberWithOptions(decimal: true), hint: '0.00'),
              field(tr('Payment reference (optional)', 'Назначение платежа (необязательно)', 'Verwendungszweck (optional)', 'გადახდის დანიშნულება (არასავალდებულო)'), reference),
            ],
          ]))),
          const SizedBox(height: 14),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            Text(tr('QR preview', 'Предпросмотр QR', 'QR-Vorschau', 'QR-ის წინასწარი ნახვა'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(width: 260, height: 260, alignment: Alignment.center, padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFB8D9F5))),
              child: valid ? QrImageView(data: payload, version: QrVersions.auto, size: 240, backgroundColor: Colors.white, foregroundColor: const Color(0xFF06172B))
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.qr_code_2, size: 64, color: Color(0xFF9AAFC2)), const SizedBox(height: 8), Text(tr('Fill in required fields', 'Заполните обязательные поля', 'Pflichtfelder ausfüllen', 'შეავსეთ აუცილებელი ველები'), textAlign: TextAlign.center)])),
            const SizedBox(height: 12),
            if (valid) OutlinedButton.icon(onPressed: () { Clipboard.setData(ClipboardData(text: payload)); message(tr('Copied.', 'Скопировано.', 'Kopiert.', 'კოპირებულია.')); }, icon: const Icon(Icons.copy), label: Text(tr('Copy data', 'Копировать данные', 'Daten kopieren', 'მონაცემების კოპირება'))),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: FilledButton.icon(onPressed: valid ? save : null, icon: const Icon(Icons.download), label: Text(tr('Save PNG', 'Сохранить PNG', 'PNG speichern', 'PNG-ის შენახვა')))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(onPressed: valid ? share : null, icon: const Icon(Icons.share), label: Text(tr('Share', 'Поделиться', 'Teilen', 'გაზიარება')))),
            ]),
          ]))),
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer.withOpacity(.55), borderRadius: BorderRadius.circular(14)),
            child: Text(cardMode
              ? tr('Important: the card QR only displays the recipient name and card number. It does not automatically start a card payment. Transfers depend on the customer’s bank or payment provider. Never include PIN, CVV, or expiry date.', 'Важно: QR карты только показывает имя и номер карты и не запускает платёж автоматически. Перевод зависит от банка или платёжного сервиса клиента. Не указывайте PIN, CVV или срок действия.', 'Wichtig: Der Karten-QR zeigt nur Name und Kartennummer und startet keine Zahlung automatisch. Überweisungen hängen von Bank oder Zahlungsanbieter ab. Niemals PIN, CVV oder Ablaufdatum eintragen.', 'მნიშვნელოვანია: ბარათის QR მხოლოდ სახელსა და ნომერს აჩვენებს და ავტომატურად არ იწყებს გადახდას. გადარიცხვა დამოკიდებულია ბანკზე ან პროვაიდერზე. არ შეიყვანოთ PIN, CVV ან ვადის თარიღი.')
              : tr('IBAN QR uses EPC/GiroCode for euro SEPA transfers. Compatible banking apps may prefill a transfer; the customer must review and confirm it. It is not a universal worldwide format.', 'IBAN QR использует EPC/GiroCode для переводов в евро внутри SEPA. Совместимое банковское приложение может заполнить перевод; клиент должен проверить и подтвердить его. Это не универсальный мировой формат.', 'IBAN-QR nutzt EPC/GiroCode für Euro-SEPA-Überweisungen. Kompatible Banking-Apps können die Überweisung vorausfüllen; der Kunde muss sie prüfen und bestätigen. Kein weltweit universelles Format.', 'IBAN QR იყენებს EPC/GiroCode ფორმატს ევროს SEPA გადარიცხვებისთვის. თავსებად აპს შეუძლია ველების შევსება; მომხმარებელმა უნდა შეამოწმოს და დაადასტუროს. ეს არ არის უნივერსალური მსოფლიო ფორმატი.'),
              style: theme.textTheme.bodySmall)),
        ])),
      ))),
    );
  }
}
