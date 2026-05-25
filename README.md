# SentinelLink - App de Comunicacion Interna

Repositorio oficial del proyecto **SentinelLink** — TFG de DAM (Desarrollo de Aplicaciones Multiplataforma).

## Resumen del Proyecto

**SentinelLink** es una aplicacion completa de comunicacion interna desarrollada como TFG de DAM.

- **Backend**: Java puro con WebSocket + base de datos H2 (JPA/Hibernate)
- **Frontend**: Flutter (escritorio Windows + movil Android + web)
- **Comunicacion**: WebSocket con protocolo JSON propio
- **Seguridad**: Autenticacion con contrasenas hasheadas con BCrypt
- **Monitorizacion**: Metricas del sistema en tiempo real con OSHI + historial de 60 muestras
- **IA**: Integracion con Ollama (modelo local, historial de conversacion con contexto)
- **Exportacion multiplataforma**: Descarga de chats y archivos en Windows, Android y Web

## Estructura de Directorios

```
SentinelLink/
├── data/                           # Base de datos H2 (generada en tiempo de ejecucion)
├── sentinellink-backend/           # Backend Java/Maven
│   ├── src/
│   │   ├── main/
│   │   │   ├── java/com/sentinellink/
│   │   │   │   ├── server/         # Servidor WebSocket (Main, WebSocketServer)
│   │   │   │   ├── model/          # Entidades JPA (User, Channel, Message, ChannelUser)
│   │   │   │   ├── service/        # Logica de negocio (Auth, Message, Monitor, AI...)
│   │   │   │   ├── repository/     # Acceso a datos (User, Channel, Message repos)
│   │   │   │   ├── websocket/      # Handlers y router WebSocket
│   │   │   │   └── util/           # Utilidades (JpaUtil, H2ConsoleServer)
│   │   │   └── resources/META-INF/
│   │   │       └── persistence.xml
│   │   └── test/
│   └── pom.xml
│
└── sentinellink_frontend/          # Frontend Flutter
    ├── lib/
    │   ├── screens/                # Pantallas UI (Login, Chat, Monitor, AI)
    │   ├── widgets/                # Widgets personalizados
    │   ├── models/                 # Modelos de datos (ChatChannel, ChatMessage, SystemMetrics...)
    │   ├── services/               # Logica de negocio y estado (AuthProvider, WebSocket)
    │   ├── utils/                  # Utilidades multiplataforma (download_helper)
    │   └── main.dart               # Punto de entrada
    ├── assets/sounds/              # Sonidos de notificacion
    ├── pubspec.yaml
    └── analysis_options.yaml
```

## Progreso por Fases

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
- [x] Enum UserRole creado (ADMIN, USER)
- [x] Repositorios implementados: UserRepository, ChannelRepository, MessageRepository
- [x] H2 configurada en modo archivo (datos persistentes en `data/`)
- [x] Consola H2 integrada en el arranque
- [x] Datos iniciales al iniciar: canal general + usuario admin

### Fase 3 - Servidor WebSocket y Protocolo JSON (Completada)

- [x] WebSocketServer escuchando en puerto 8080
- [x] Gestion de clientes conectados con estructuras concurrentes
- [x] Eventos implementados: onOpen, onMessage, onClose, onError
- [x] Router de mensajes implementado (MessageRouter)
- [x] Protocolo JSON definido con tipos de mensaje

### Fase 4 - Autenticacion (Completada)

- [x] AuthService valida credenciales contra BD
- [x] LOGIN_RESPONSE con exito o error
- [x] LoginScreen con usuario, contrasena y boton de login
- [x] Navegacion automatica a ChatScreen si login correcto

### Fase 5 - Chat en Tiempo Real (Completada)

- [x] MessageService guarda mensajes en BD y recupera historial por canal
- [x] Lista de usuarios online actualizada al conectar y desconectar
- [x] SEND_MESSAGE retransmitido solo a clientes del canal activo
- [x] ChatScreen con sidebar de canales y usuarios online
- [x] Historial de mensajes por canal
- [x] Recepcion en tiempo real por WebSocket
- [x] Contador de mensajes sin leer por canal (badgets en sidebar)

### Fase 6 - Monitorizacion del Sistema (Completada)

- [x] SystemMonitor con recoleccion periodica de metricas (CPU, RAM, Disco) via OSHI
- [x] Broadcast de SYSTEM_METRICS cada intervalo configurable
- [x] Alertas automaticas cuando metricas superan umbrales configurables
- [x] MonitorScreen con barras de progreso y graficos por metrica
- [x] Historial en memoria de las ultimas 60 muestras de metricas
- [x] SnackBars automaticas al recibir alertas del sistema (suprime la primera al conectar)
- [x] Alertas incluyen metrica afectada, valor actual y umbral configurado

### Fase 7 - Asistente IA (Completada)

- [x] Backend con Ollama local (llama3.1) integrado via API REST
- [x] Panel de Asistente IA con historial de conversacion
- [x] Contexto de conversacion enviado en cada mensaje (ultimos 12 mensajes)
- [x] Timeout de 120 segundos para respuestas largas
- [x] Peticiones a Ollama en hilo separado (no bloquea el WebSocket)
- [x] Manejo de errores: mensaje informativo si Ollama no esta disponible

### Fase 8 - Canales Privados, DMs y Funcionalidades Avanzadas (Completada)

- [x] Canales privados con control de acceso por miembros
- [x] Sistema de invitaciones a canales privados via DM con boton "Unirse"
- [x] Mensajes directos (DM) entre usuarios
- [x] Envio y recepcion de archivos e imagenes
- [x] Sonidos de notificacion al recibir mensajes
- [x] Preferencias persistentes locales (URL del servidor, sonido on/off)
- [x] Cambio de contrasena desde perfil de usuario
- [x] Exportacion de chat a TXT desde la barra superior
- [x] Estetica pulida basada en Figma (dark mode, colores, layout)
- [x] Alternancia de tema claro/oscuro
- [x] AppBar responsive (se adapta a pantallas movil y escritorio)

### Fase 9 - Seguridad (Completada)

- [x] Contrasenas hasheadas con BCrypt (jbcrypt 0.4) — nunca en texto plano
- [x] Hash aplicado en registro, cambio de contrasena y datos iniciales
- [x] Verificacion segura en login con BCrypt.checkpw

### Fase 10 - Multiplataforma y Mejoras Finales (Completada)

- [x] Abstraccion de descarga de archivos multiplataforma (`download_helper`)
  - Windows/macOS: dialogo nativo via FilePicker
  - Android: guardado en almacenamiento externo via `path_provider`
  - Web: descarga en navegador via API Blob + elemento `<a>`
- [x] Exportacion de chats compatible con Web y Android sin dependencias nativas de IO
- [x] Guardado de archivos recibidos compatible con todas las plataformas
- [x] Dependencias `web` y `path_provider` añadidas al frontend

## Dependencias

**Backend (Maven)**:
- `com.h2database:h2` — base de datos embebida en archivo
- `org.hibernate:hibernate-core` + `hibernate-entitymanager` — ORM/JPA
- `jakarta.websocket-api` + `tyrus-server` + `tyrus-container-grizzly-server` — WebSocket
- `com.github.oshi:oshi-core` — metricas del sistema (CPU, RAM, Disco)
- `com.google.code.gson:gson` — procesamiento JSON
- `org.mindrot:jbcrypt` — hashing de contrasenas BCrypt
- `com.sun.mail:jakarta.mail` — notificaciones por email
- `org.slf4j:slf4j-api` + `ch.qos.logback:logback-classic` — logging

**Frontend (Flutter)**:
- `web_socket_channel` — comunicacion WebSocket
- `provider` — gestion de estado
- `http` — cliente HTTP
- `file_picker` — seleccion de archivos e imagenes
- `fl_chart` — graficos para el monitor del sistema
- `shared_preferences` — preferencias persistentes locales
- `audioplayers` — reproduccion de sonidos de notificacion
- `json_serializable` + `json_annotation` — serializacion JSON
- `web` — interop con APIs del navegador (descarga de archivos en web)
- `path_provider` — rutas del sistema de archivos en Android

## Inicio Rapido

### Backend

```bash
cd sentinellink-backend
mvn clean compile
mvn exec:java
```

La base de datos H2 se genera automaticamente en `SentinelLink/data/` al arrancar.

**Credenciales por defecto** (creadas automaticamente si la BD esta vacia):

| Usuario | Contrasena | Rol   |
|---------|-----------|-------|
| admin   | admin123  | ADMIN |
| user    | user123   | USER  |

**Consola H2** (para inspeccionar la BD en desarrollo):

```
http://localhost:8082
JDBC URL: jdbc:h2:file:./data/sentinellink_db
```

**Asistente IA con Ollama** (activado por defecto):

Ollama esta habilitado por defecto. Solo es necesario tenerlo instalado y en ejecucion:

```bash
ollama pull llama3.1
ollama serve
```

Para deshabilitarlo, crea `sentinellink-backend/.env` con:

```
USE_OLLAMA=false
```

Para usar un modelo o URL diferente:

```
OLLAMA_MODEL=llama3.2
OLLAMA_API_URL=http://localhost:11434/api/chat
```

**Configuracion del Monitor** (umbrales por defecto: CPU 80%, RAM 90%, Disco 90%):

```bash
set JAVA_TOOL_OPTIONS=-Dsentinellink.monitor.cpuThreshold=75 -Dsentinellink.monitor.ramThreshold=85
mvn exec:java
```

**Endpoint WebSocket**:

```
ws://localhost:8080/ws
```

### Frontend

```bash
cd sentinellink_frontend
flutter pub get
flutter run -d windows   # escritorio Windows
flutter run -d android   # movil Android
flutter run -d chrome    # navegador web
```

Ejecutar siempre desde terminal, no desde el boton Run de VS Code (puede fallar por entorno CMake).

## Protocolo WebSocket JSON

```json
{ "type": "LOGIN_REQUEST",          "data": { "username": "", "password": "" } }
{ "type": "LOGIN_RESPONSE",         "data": { "success": true, "role": "admin", "username": "" } }
{ "type": "REGISTER_REQUEST",       "data": { "username": "", "password": "" } }
{ "type": "REGISTER_RESPONSE",      "data": { "success": true, "username": "" } }
{ "type": "SEND_MESSAGE",           "data": { "channelId": 1, "content": "" } }
{ "type": "RECEIVE_MESSAGE",        "data": { "sender": "", "content": "", "timestamp": "", "channelId": 1 } }
{ "type": "USER_LIST",              "data": { "users": [] } }
{ "type": "CHANNEL_LIST",           "data": { "channels": [] } }
{ "type": "MESSAGE_HISTORY",        "data": { "channelId": 1, "messages": [] } }
{ "type": "JOIN_CHANNEL",           "data": { "channelId": 1 } }
{ "type": "CREATE_CHANNEL_REQUEST", "data": { "name": "", "private": true } }
{ "type": "CREATE_CHANNEL_RESPONSE","data": { "success": true, "channelId": 1, "name": "", "private": true } }
{ "type": "RENAME_CHANNEL_REQUEST", "data": { "channelId": 1, "name": "" } }
{ "type": "DELETE_CHANNEL_REQUEST", "data": { "channelId": 1 } }
{ "type": "CREATE_DM_REQUEST",      "data": { "targetUsername": "" } }
{ "type": "CREATE_DM_RESPONSE",     "data": { "success": true, "channelId": 1 } }
{ "type": "SEARCH_CHANNEL_REQUEST", "data": { "name": "" } }
{ "type": "SEARCH_CHANNEL_RESPONSE","data": { "success": true, "channelId": 1 } }
{ "type": "SYSTEM_METRICS",         "data": { "cpuPercent": 25.5, "ramPercent": 60.2, "diskPercent": 45.0, "timestamp": 0 } }
{ "type": "SYSTEM_ALERT",           "data": { "message": "", "level": "warning", "metric": "cpu", "value": 85.0, "threshold": 80.0 } }
{ "type": "UPDATE_THRESHOLDS",      "data": { "cpuThreshold": 80, "ramThreshold": 90, "diskThreshold": 90 } }
{ "type": "THRESHOLDS_RESPONSE",    "data": { "cpuThreshold": 80, "ramThreshold": 90, "diskThreshold": 90, "success": true } }
{ "type": "TEST_ALERT",             "data": {} }
{ "type": "AI_REQUEST",             "data": { "prompt": "", "history": [{"role": "user", "content": ""}] } }
{ "type": "AI_RESPONSE",            "data": { "response": "", "error": false } }
{ "type": "CHANGE_PASSWORD_REQUEST","data": { "currentPassword": "", "newPassword": "" } }
{ "type": "CHANGE_PASSWORD_RESPONSE","data": { "success": true } }
{ "type": "ERROR",                  "data": { "message": "" } }
```

## Notas

- La base de datos persiste entre reinicios (H2 en archivo, `SentinelLink/data/`)
- Para resetear la BD: parar el backend y borrar los archivos `.mv.db` y `.trace.db` de `data/`
- Los canales privados usan un mapa en memoria para controlar quien recibe mensajes; al reiniciar el servidor los usuarios deben volver a unirse
- Los archivos se transfieren en base64 por WebSocket; no hay limite configurado en la aplicacion (el limite practico lo impone la RAM disponible)
- El asistente IA mantiene contexto de los ultimos 12 mensajes de la conversacion
- Las metricas del sistema se guardan en memoria (ultimas 60 muestras) y se pierden al cerrar el frontend

---

