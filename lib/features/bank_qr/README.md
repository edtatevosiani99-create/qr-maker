# Bank QR (free, standalone feature)

This feature lives in `lib/features/bank_qr/bank_qr_screen.dart`. The main app only imports the screen and provides a navigation button.

- **Visa / Mastercard details QR:** encodes recipient name and a 16-digit card number as readable text. It does not initiate a card payment; transfers to a card depend on the customer's bank/payment provider. Never collect a PIN, CVV, or expiry date.
- **IBAN transfer QR:** uses EPC/GiroCode for euro SEPA credit transfers. Compatible banking apps may prefill a transfer; the customer must review and confirm it. Not a universal worldwide payment format.
- PNG saving and sharing happen on-device. No paid QR API or payment processor is used.

To remove this feature, delete this folder and remove its import and Bank QR button in `lib/main.dart`. The original QR generator logic remains separate.

Before merging to main, run `flutter analyze`, tests, and the Android APK build workflow.
