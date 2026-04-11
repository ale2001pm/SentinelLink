# 🔗 SentinelLink - Internal Communication App

Official repository for the **SentinelLink** project - Phase 1: Project Structure & Initial Configuration

## 📋 Project Overview

**SentinelLink** is a complete internal communication application built as a DAM (Ciclo de Desarrollo de Aplicaciones Multiplataforma) TFG project.

- **Backend**: Pure Java with WebSocket + H2 Database
- **Frontend**: Flutter (Desktop + Mobile)
- **Communication**: WebSocket with JSON protocol
- **Monitoring**: System metrics via OSHI
- **AI**: Integration with external AI APIs

## 📁 Directory Structure

```
SentinelLink/
├── sentinellink-backend/       # Java/Maven backend
│   ├── src/
│   │   ├── main/
│   │   │   ├── java/com/sentinellink/
│   │   │   │   ├── server/       # WebSocket server
│   │   │   │   ├── model/        # JPA entities
│   │   │   │   ├── service/      # Business logic
│   │   │   │   ├── repository/   # Data access
│   │   │   │   ├── websocket/    # WebSocket handlers
│   │   │   │   └── util/         # Utilities
│   │   │   └── resources/META-INF/
│   │   │       └── persistence.xml
│   │   └── test/
│   └── pom.xml
│
└── sentinellink_frontend/       # Flutter frontend
    ├── lib/
    │   ├── screens/             # UI screens
    │   ├── widgets/             # Custom widgets
    │   ├── models/              # Data models
    │   ├── services/            # Business logic
    │   └── main.dart            # Entry point
    ├── pubspec.yaml
    ├── analysis_options.yaml
    └── README.md

```

## 🚀 Current Phase: Phase 1 - Project Initialization

**Objective**: Both projects created and running without errors.

### ✅ Completed

- [x] Maven backend project created
- [x] Dependencies configured in pom.xml (H2, Hibernate+JPA, WebSocket, OSHI)
- [x] Package structure established
- [x] persistence.xml configured for H2 embedded database
- [x] Backend compiles successfully
- [x] Flutter project structure created
- [x] pubspec.yaml configured with required dependencies
- [x] main.dart entry point implemented

### 📦 Dependencies

**Backend (Maven - pom.xml)**:
- H2 Database
- Hibernate + JPA
- Jakarta WebSocket
- OSHI (System Monitoring)
- Gson (JSON Processing)
- SLF4J + Logback (Logging)

**Frontend (Flutter - pubspec.yaml)**:
- web_socket_channel
- provider (State management)
- http (Client)
- json_serializable, json_annotation

## 🔧 Quick Start

### Backend

```bash
cd sentinellink-backend
mvn clean compile
mvn exec:java
```

### Frontend

```bash
cd sentinellink_frontend
flutter pub get
flutter run -d windows  # or macos, linux, android, ios
```

## 📅 Development Timeline

- **Phase 1** ✅ Structure & Configuration
- **Phase 2** Database & Models
- **Phase 3** WebSocket Server & JSON Protocol
- **Phase 4** Authentication
- **Phase 5** Real-time Chat
- **Phase 6** System Monitoring
- **Phase 7** AI Assistant
- **Phase 8** Polish & Testing

## 📝 Notes

- Database persists between restarts (H2 file-based)
- Architecture supports extensibility for future phases
- Both projects follow best practices for their respective ecosystems

---

