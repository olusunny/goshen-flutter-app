# AGENTS.md — Goshen Flutter App

This repository is the Flutter mobile app for the Goshen Retreat / MFM Triumphant Church platform.

Authoritative repo path:

- `C:\Appbuild\Goshen-Flutter-App`

GitHub:

- `olusunny/goshen-flutter-app`

Related Laravel/admin/web repo:

- `C:\Appbuild\Goshen-Laravel-Admin-Staging`
- `olusunny/goshen-laravel-admin`

Do not use or modify older `C:\ScriptsDev\CovenantofmercyAPP...` workspaces unless explicitly asked.

## Required operating rules

- Preserve existing Flutter app conventions.
- Check git status before changing files.
- Do not expose secrets, Firebase private configuration secrets, API keys beyond existing public app config, tokens, private keys, or backend credentials.
- Commit and push completed implementation changes.
- Build release APK when requested.
- Install APK when requested.
- Compare with Laravel/web behavior when features overlap.

## Backend/server context

- Production Laravel portal/API host: `https://portal.goshenretreat.uk`
- cPanel account: `goshenretreat`
- Related Laravel repo: `C:\Appbuild\Goshen-Laravel-Admin-Staging`

The old URL should remain intact unless the user explicitly requests redirect behavior.

## Identity/authentication rules

- Laravel/mobile-user database is the source of truth for real users.
- Google/Firebase login must not let unknown users operate as registered members outside the real database.
- A user must not receive duplicate Triumphant IDs.
- One email/person must not have two Triumphant IDs.
- Existing same-email merge behavior should be preserved and verified before changing.
- Registered members should have linked wallet records.

## Flutter feature consistency

Keep Flutter consistent with the web portal for:

- Goshen registration
- Ticket type min/max attendee behavior
- `Goshen Family` attendee quantity logic
- Voucher payment
- Wallet payment/security
- Control hub
- Event details page
- Countdown
- Ticket PDF/QR behavior
- Google/Firebase login
- Logo/app icon usage

## Payment and wallet rules

- Do not reintroduce installment payments.
- Only full payment is allowed.
- Active payment systems are Stripe, wallet, and voucher.
- Paystack is suspended for now.
- Wallet payments in Flutter are gated by biometric/PIN security.
- Voucher purpose types:
  - `Wallet Funding`
  - `For Payments`
- `Wallet Funding` vouchers can only add funds to wallet.
- `For Payments` vouchers can be used for supported retreat/ticket/payment flows.

## Goshen retreat rules

- Countdown should use retreat start date from the backend.
- Do not show “Dates will be announced” when a start date exists.
- Event details should match web portal content.
- Ticket registration must respect ticket `min_per_booking` and `max_per_booking`.
- `Goshen Family` should show attendee quantity behavior consistent with web.

## Testing/build checklist

For Flutter changes:

1. Run relevant Flutter analysis/tests where practical.
2. Build release APK when requested.
3. Install APK when requested.
4. Verify changed screens manually where possible.
5. Commit and push relevant changes.

