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

## 🚀 Fase Actual: Fase 6 - Monitorizacion del sistema

**Objetivo**: Monitorización en tiempo real de CPU, RAM y Disco con alertas automáticas.

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

### Fase 3 - Servidor WebSocket y Protocolo JSON (Completada)

- [x] Clase WebSocketServer implementada y escuchando en puerto 8080
- [x] Gestion de clientes conectados con estructura concurrente
- [x] Eventos implementados: onOpen, onMessage, onClose, onError
- [x] Router de mensajes implementado (MessageRouter)
- [x] Protocolo JSON definido con tipos:
    - [x] LOGIN_REQUEST
    - [x] LOGIN_RESPONSE
    - [x] SEND_MESSAGE
    - [x] RECEIVE_MESSAGE
    - [x] USER_LIST
    - [x] SYSTEM_ALERT
    - [x] AI_REQUEST
    - [x] AI_RESPONSE
- [x] Validacion E2E de parseo y respuesta JSON por WebSocket

### Fase 4 - Autenticacion (Completada)

- [x] Backend:
    - [x] AuthService valida credenciales contra BD
    - [x] Gestion de sesion del cliente WebSocket conectado
    - [x] LOGIN_RESPONSE con exito o error
- [x] Flutter:
    - [x] LoginScreen implementada (usuario + contrasena + boton)
    - [x] Conexion WebSocket al pulsar login
    - [x] Envio de LOGIN_REQUEST
    - [x] Navegacion a ChatScreen si LOGIN_RESPONSE.success es true
- [x] Validacion E2E completada (backend responde LOGIN_RESPONSE correcto)

### Fase 5 - Chat en tiempo real (Completada)

- [x] Backend:
    - [x] MessageService guarda mensajes en BD y genera historial por canal
    - [x] Lista de usuarios online actualizada al conectar y desconectar
    - [x] USER_LIST, CHANNEL_LIST y MESSAGE_HISTORY enviados desde WebSocket
    - [x] SEND_MESSAGE retransmitido solo a clientes del canal activo
- [x] Flutter:
    - [x] ChatScreen con sidebar de canales y usuarios online
    - [x] Historial de mensajes por canal
    - [x] Input para escribir y enviar mensajes
    - [x] Recepcion en tiempo real por WebSocket
- [x] Validacion funcional completada con dos clientes simultaneos

### Fase 6 - Monitorizacion del Sistema (Completada)

- [x] Backend:
    - [x] SystemMonitor con recolección periódica de métricas (CPU, RAM, Disco) via OSHI
    - [x] Broadcast de SYSTEM_METRICS cada intervalo configurable
    - [x] Alertas automáticas cuando métricas superan umbrales
    - [x] Persistencia de últimas métricas y alertas para nuevas sesiones
    - [x] Propiedades JVM configurables para umbrales e intervalos
- [x] Frontend:
    - [x] MonitorScreen con visualización de barras de progreso por métrica
    - [x] AuthProvider maneja SYSTEM_METRICS y SYSTEM_ALERT en tiempo real
    - [x] SnackBars automáticas al recibir alertas del sistema
    - [x] Navegación desde ChatScreen al Monitor (appbar + drawer)
- [x] Protocolo:
    - [x] MessageType.SYSTEM_METRICS agregado
    - [x] Payloads de métricas: cpuPercent, ramPercent, diskPercent, timestamp
    - [x] Payloads de alertas: message, level, metric, value, threshold
- [x] Validacion E2E completada: metrics + alerts fluyendo en WebSocket

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

Para el Asistente IA (Fase 7) con Ollama (gratis), crea el archivo:

```bash
sentinellink-backend/.env
```

Con estas variables:

```bash
USE_OLLAMA=true
OLLAMA_MODEL=llama3.1
OLLAMA_API_URL=http://localhost:11434/api/chat
```

Instala Ollama y descarga el modelo:

```bash
ollama pull llama3.1
```

Si Ollama no esta corriendo, inicia:

```bash
ollama serve
```

Los archivos de la base de datos H2 se generan automáticamente en:

```bash
sentinellink-backend/data/
```

**Nota**: La aplicación maneja automáticamente bloqueos de BD con reintentos inteligentes. No necesitas eliminar ninguna carpeta manualmente.

**Configuración del Monitor** (Fase 6):

Puedes controlar el monitor via propiedades JVM. Por defecto:
- CPU threshold: 80%
- RAM threshold: 90%
- Disk threshold: 90%
- Intervalo: 5 segundos

Para sobrescribir:

```bash
set JAVA_TOOL_OPTIONS=-Dsentinellink.monitor.cpuThreshold=75 -Dsentinellink.monitor.ramThreshold=85
mvn exec:java
```

Credenciales iniciales por defecto para desarrollo:

- usuario: admin
- contrasena: admin123

Usuario adicional para pruebas de chat simultaneo:

- usuario: user
- contrasena: user123

Endpoint WebSocket del backend:

```bash
ws://localhost:8080/ws
```

### Frontend

```bash
cd sentinellink_frontend
flutter pub get
flutter run -d windows  # o macos, linux, android, ios
```

Flujo de autenticacion en la app Flutter:

- Pantalla inicial: LoginScreen
- Credenciales de desarrollo: admin / admin123
- Si login correcto: navegacion automatica a ChatScreen

## 📅 Roadmap de Desarrollo

- **Fase 1** ✅ Estructura y configuracion
- **Fase 2** ✅ Base de datos y modelos
- **Fase 3** ✅ Servidor WebSocket y protocolo JSON
- **Fase 4** ✅ Autenticacion
- **Fase 5** ✅ Chat en tiempo real
- **Fase 6** ✅ Monitorizacion del sistema
- **Fase 7** Asistente IA
- **Fase 8** Pulido final y pruebas

## 📋 Protocolo JSON (Fase 3 - Actualizado Fase 6)

```json
{ "type": "LOGIN_REQUEST", "data": { "username": "", "password": "" } }
{ "type": "LOGIN_RESPONSE", "data": { "success": true, "role": "user" } }
{ "type": "SEND_MESSAGE", "data": { "channelId": 1, "content": "" } }
{ "type": "RECEIVE_MESSAGE", "data": { "sender": "", "content": "", "timestamp": "" } }
{ "type": "USER_LIST", "data": { "users": [] } }
{ "type": "CHANNEL_LIST", "data": { "channels": [] } }
{ "type": "MESSAGE_HISTORY", "data": { "channelId": 1, "messages": [] } }
{ "type": "SYSTEM_METRICS", "data": { "cpuPercent": 25.5, "ramPercent": 60.2, "diskPercent": 45.0, "timestamp": 1778931858090 } }
{ "type": "SYSTEM_ALERT", "data": { "message": "", "level": "warning", "metric": "cpu", "value": 85.0, "threshold": 80.0, "timestamp": 1778931858090 } }
{ "type": "AI_REQUEST", "data": { "prompt": "" } }
{ "type": "AI_RESPONSE", "data": { "response": "" } }
```

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

