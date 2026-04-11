# 🔗 SentinelLink - App de Comunicacion Interna

Repositorio oficial del proyecto **SentinelLink** - Manual vivo actualizado por fases de desarrollo

## 📋 Resumen del Proyecto

**SentinelLink** es una aplicacion completa de comunicacion interna desarrollada como TFG de DAM (Desarrollo de Aplicaciones Multiplataforma).

- **Backend**: Java puro con WebSocket + base de datos H2
- **Frontend**: Flutter (escritorio + movil)
- **Comunicacion**: WebSocket con protocolo JSON
- **Monitorizacion**: Metricas del sistema con OSHI
- **IA**: Integracion con APIs externas

## 📁 Estructura de Directorios

```
SentinelLink/
├── sentinellink-backend/       # Backend Java/Maven
│   ├── src/
│   │   ├── main/
│   │   │   ├── java/com/sentinellink/
│   │   │   │   ├── server/       # Servidor WebSocket
│   │   │   │   ├── model/        # Entidades JPA
│   │   │   │   ├── service/      # Logica de negocio
│   │   │   │   ├── repository/   # Acceso a datos
│   │   │   │   ├── websocket/    # Handlers WebSocket
│   │   │   │   └── util/         # Utilidades
│   │   │   └── resources/META-INF/
│   │   │       └── persistence.xml
│   │   └── test/
│   └── pom.xml
│
└── sentinellink_frontend/       # Frontend Flutter
    ├── lib/
    │   ├── screens/             # Pantallas UI
    │   ├── widgets/             # Widgets personalizados
    │   ├── models/              # Modelos de datos
    │   ├── services/            # Logica de negocio
    │   └── main.dart            # Punto de entrada
    ├── pubspec.yaml
    ├── analysis_options.yaml
    └── README.md

```

## 🚀 Fase Actual: Fase 2 - Base de Datos y Modelos

**Objetivo**: Entidades JPA definidas y base de datos H2 funcionando con persistencia.

## ✅ Progreso por Fases

### Fase 1 - Inicializacion del Proyecto (Completada)

- [x] Proyecto backend Maven creado
- [x] Dependencias configuradas en pom.xml (H2, Hibernate+JPA, WebSocket, OSHI)
- [x] Estructura de paquetes creada
- [x] persistence.xml configurado
- [x] Backend compila correctamente
- [x] Estructura del proyecto Flutter creada
- [x] pubspec.yaml configurado con dependencias requeridas
- [x] main.dart implementado como punto de entrada

### Fase 2 - Base de Datos y Modelos (Completada)

- [x] Entidades JPA implementadas: User, Channel, Message, ChannelUser
- [x] Enum UserRole creado
- [x] Repositorios implementados:
    - [x] UserRepository (CRUD basico + findByUsername)
    - [x] ChannelRepository (CRUD basico + findByName)
    - [x] MessageRepository (save, findById, findAll, findByChannelId)
- [x] H2 configurada en modo archivo (datos persistentes)
- [x] Consola H2 integrada en el arranque
- [x] Datos iniciales al iniciar:
    - [x] Canal por defecto: general
    - [x] Usuario admin por defecto: admin
- [x] Validacion de arranque realizada con conteos persistentes entre reinicios

### 📦 Dependencias

**Backend (Maven - pom.xml)**:
- H2 Database
- Hibernate + JPA
- Jakarta WebSocket
- OSHI (Monitorizacion del sistema)
- Gson (Procesamiento JSON)
- SLF4J + Logback (Logging)

**Frontend (Flutter - pubspec.yaml)**:
- web_socket_channel
- provider (Gestion de estado)
- http (Cliente)
- json_serializable, json_annotation

## 🔧 Inicio Rapido

### Backend

```bash
cd sentinellink-backend
mvn clean compile
mvn exec:java
```

Los archivos de la base de datos H2 se generan automaticamente en:

```bash
sentinellink-backend/data/
```

Credenciales iniciales por defecto para desarrollo:

- usuario: admin
- contrasena: admin123

### Frontend

```bash
cd sentinellink_frontend
flutter pub get
flutter run -d windows  # o macos, linux, android, ios
```

## 📅 Roadmap de Desarrollo

- **Fase 1** ✅ Estructura y configuracion
- **Fase 2** ✅ Base de datos y modelos
- **Fase 3** Servidor WebSocket y protocolo JSON
- **Fase 4** Autenticacion
- **Fase 5** Chat en tiempo real
- **Fase 6** Monitorizacion del sistema
- **Fase 7** Asistente IA
- **Fase 8** Pulido final y pruebas

## 📘 Regla de Mantenimiento del README

Este README es el manual vivo del proyecto.

- Al finalizar cada fase completada, actualizar:
    - Seccion de fase actual
    - Checklist de progreso por fases
    - Estado del roadmap
    - Nuevas instrucciones de ejecucion, valores por defecto o notas para usuarios

## 📝 Notas

- La base de datos persiste entre reinicios (H2 en archivo)
- La arquitectura permite extender funcionalidades en las siguientes fases
- Ambos proyectos siguen buenas practicas de sus respectivos ecosistemas

---

