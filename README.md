# QuizArena 🎮

Een moderne, realtime multiplayer quiz applicatie gebouwd met SwiftUI en Firebase. Speel samen met vrienden, test je kennis en bekijk wie de hoogste score haalt!

## ✨ Features

### 🎯 Core Functies
- **Realtime Multiplayer** - Host een game of join met een room code
- **Live Quizzes** - Beantwoord vragen binnen 30 seconden
- **Leaderboard** - Zie direct wie wint met een mooi podium
- **Offline Modus** - Download vragen en speel zonder internet

### 🗺️ Extra Features
- **Locatie Service** - Bekijk je locatie op een interactieve kaart
- **Firebase Sync** - Realtime synchronisatie tussen alle spelers
- **Modern Design** - Mooie gradients en glassmorphism effecten

## 📱 Screenshots
<img width="382" height="773" alt="Capture d’écran 2026-01-09 à 21 37 31" src="https://github.com/user-attachments/assets/92bff3aa-585f-4179-bfb0-7fc6efed187a" />
<img width="372" height="780" alt="Capture d’écran 2026-01-09 à 21 38 55" src="https://github.com/user-attachments/assets/1e08421c-0854-4064-b823-a0121a454cda" />
<img width="369" height="767" alt="Capture d’écran 2026-01-09 à 21 39 37" src="https://github.com/user-attachments/assets/d88b8658-88d3-408d-bb5a-0ef3d44423ce" />


## 🛠️ Technische Stack

- **Frontend:** SwiftUI
- **Backend:** Firebase (Firestore, Authentication)
- **Database:** Core Data (offline caching)
- **Maps:** MapKit & CoreLocation
- **Minimum iOS:** 17.0

## 🏗️ Project Structuur
```
QuizArena/
├── Models/
│   ├── PlayerDoc.swift
│   ├── QuizQuestion.swift
│   └── OfflineRow.swift
├── ViewModels/
│   ├── LobbyViewModel.swift
│   ├── QuizViewModel.swift
│   └── OfflineQuestionsViewModel.swift
├── Views/
│   ├── HomeView.swift
│   ├── LobbyView.swift
│   ├── QuizView.swift
│   ├── PodiumView.swift
│   ├── OfflineQuestionsView.swift
│   └── MapScreen.swift
├── Services/
│   ├── FirestoreService.swift
│   ├── AuthService.swift
│   └── LocationService.swift
└── Core/
    ├── QuizArenaApp.swift
    └── Persistence.swift
```

## 🚀 Installatie & Setup

### Vereisten
- Xcode 16.0 of hoger
- macOS Sequoia of hoger
- iOS 17.0+ device of simulator
- Firebase account

### Stappen

1. **Clone de repository**
```bash
git clone https://github.com/ebenhaj2005/QuizArena.git
cd QuizArena
```

2. **Firebase Setup**
- Ga naar [Firebase Console](https://console.firebase.google.com/)
- Maak een nieuw project aan
- Voeg een iOS app toe met Bundle ID: `be.ehb.QuizArena`
- Download `GoogleService-Info.plist`
- Sleep het bestand naar je Xcode project

3. **Dependencies Installeren**
- Firebase is al geïntegreerd via Swift Package Manager
- Open `QuizArena.xcodeproj` in Xcode


5. **Core Data Model**
- Het project gebruikt Core Data voor offline caching
- Entity: `CachedQuestion` met attributes:
  - `questionText` (String)
  - `savedAt` (Date)

6. **Build & Run**
```bash
# Open in Xcode
open QuizArena.xcodeproj

# Of gebruik command line
xcodebuild -scheme QuizArena -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build
```

## 🎮 Hoe te Gebruiken

### Als Host:
1. Open de app en voer je naam in
2. Klik op "Maak Room"
3. Deel de 4-cijferige room code met vrienden
4. Wacht tot spelers joinen
5. Klik "Start Game" wanneer iedereen er is

### Als Speler:
1. Open de app en voer je naam in
2. Voer de room code in die je van de host kreeg
3. Klik "Join Room"
4. Wacht op de host om de game te starten

### Tijdens de Quiz:
- Je hebt 30 seconden per vraag
- Klik op het juiste antwoord
- Zie direct of je goed of fout zat
- Bekijk het eindklassement op het podium

## 🔧 Configuratie

### Bundle Identifier
Zorg dat je Bundle ID matcht met Firebase:
```
be.ehb.QuizArena
```

### Info.plist Keys
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We gebruiken je locatie om de kaart te tonen</string>
```



## 🤝 Contributing

Contributions zijn welkom! 

1. Fork het project
2. Maak een feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit je changes (`git commit -m 'Add some AmazingFeature'`)
4. Push naar de branch (`git push origin feature/AmazingFeature`)
5. Open een Pull Request



## 👨‍💻 Auteur

**Elias Benhaj**
- Email: ebenhaj2005@gmail.coml

## 🙏 Acknowledgments

- Firebase voor de realtime database
- Apple's SwiftUI framework
- MapKit voor de kaart functionaliteit
- De quiz community voor inspiratie
- Ai gebruikt voor errors op te lossen

