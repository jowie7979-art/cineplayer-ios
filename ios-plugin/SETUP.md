# CinePlayer Native Plugin – Setup

## Vereisten
- macOS met Xcode 14+
- Node.js + npm
- `@capacitor/core` en `@capacitor/ios` geïnstalleerd

## Stap 1 – iOS platform toevoegen (eenmalig)
```bash
npx cap add ios
npx cap sync
```

## Stap 2 – Plugin-bestanden kopiëren naar Xcode-project
Kopieer de drie Swift/ObjC-bestanden naar de app-map:

```
ios-plugin/ios/Sources/CinePlayerPlugin/CinePlayerPlugin.swift
ios-plugin/ios/Sources/CinePlayerPlugin/CineWebPlayerViewController.swift
ios-plugin/ios/Sources/CinePlayerPlugin/CinePlayerPlugin.m
```

→ Bestemming: `ios/App/App/`

In Xcode: rechtermuisklik op de `App`-groep → **Add Files to "App"** → selecteer de drie bestanden.

## Stap 3 – Capacitor plugin registreren
Open `ios/App/App/AppDelegate.swift` en zorg dat de bridge de plugin automatisch vindt.
In Capacitor 4+/5+ wordt dit automatisch gedaan voor klassen in de app-bundle — geen extra registratie nodig.

## Stap 4 – Info.plist (AirPlay achtergrond)
Voeg in `ios/App/App/Info.plist` toe onder `UIBackgroundModes`:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

## Stap 5 – Bouwen
```bash
npx cap sync
```
Open daarna Xcode: `npx cap open ios` en run op een echt apparaat (simulator ondersteunt geen AirPlay).

## Werking
- Op iOS: tikt de gebruiker op een film → native WKWebView overlay met echte AirPlay-knop (AVRoutePickerView)
- Op web/Android: gewone iframe-speler als fallback
- De AirPlay-knop verschijnt automatisch in de native overlay; geen extra UI nodig in HTML
