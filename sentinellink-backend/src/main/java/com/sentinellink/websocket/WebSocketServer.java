package com.sentinellink.websocket;

import com.google.gson.JsonObject;
import com.sentinellink.model.Channel;
import com.sentinellink.service.SystemMonitor;
import jakarta.websocket.Session;
import java.util.List;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import org.glassfish.tyrus.server.Server;

public class WebSocketServer {

    private static final int DEFAULT_PORT = 8080;

    private static final MessageRouter ROUTER = new MessageRouter();
    private static final Set<Session> CONNECTED_CLIENTS = ConcurrentHashMap.newKeySet();
    private static final ConcurrentHashMap<String, String> SESSION_USERNAMES = new ConcurrentHashMap<>();
    private static final ConcurrentHashMap<String, String> SESSION_ROLES = new ConcurrentHashMap<>();
    private static final ConcurrentHashMap<String, Long> SESSION_CHANNELS = new ConcurrentHashMap<>();
    /** Members of private group channels — persists across reconnects within one server run. */
    private static final ConcurrentHashMap<Long, Set<String>> PRIVATE_CHANNEL_MEMBERS = new ConcurrentHashMap<>();

    private static Server server;

    public void start() {
        if (server != null) {
            return;
        }
        try {
            server = new Server("localhost", DEFAULT_PORT, "/", null, ChatWebSocketEndpoint.class);
            server.start();
            System.out.println("WebSocket server listening on ws://localhost:" + DEFAULT_PORT + "/ws");
        } catch (Exception e) {
            throw new IllegalStateException("No se pudo iniciar el servidor WebSocket", e);
        }
    }

    public void stop() {
        if (server != null) {
            server.stop();
            server = null;
        }
    }

    public static void onOpen(Session session) {
        CONNECTED_CLIENTS.add(session);
        sendGroupChannelListToSession(session);
        sendLatestMetricsToSession(session);
        sendLatestAlertToSession(session);
    }

    public static void onMessage(Session session, String rawMessage) {
        try {
            SocketMessage incoming = ROUTER.parse(rawMessage);

            if (incoming != null && incoming.getType() == MessageType.JOIN_CHANNEL) {
                handleJoinChannel(session, incoming);
                return;
            }

            String sender = SESSION_USERNAMES.getOrDefault(session.getId(), "");
            MessageRouter.RouteResult result = ROUTER.route(incoming, sender, SESSION_USERNAMES.values());

            if (incoming != null && incoming.getType() == MessageType.LOGIN_REQUEST) {
                handleLoginResponse(session, incoming, result);
                return;
            }

            if (incoming != null && incoming.getType() == MessageType.CREATE_CHANNEL_REQUEST) {
                JsonObject responseData = result.getResponseData();
                sendToSession(session, new SocketMessage(result.getResponseType(), responseData));
                if (responseData.has("success") && responseData.get("success").getAsBoolean()) {
                    // Track creator as first member of a private channel
                    boolean isPrivate = responseData.has("private") && responseData.get("private").getAsBoolean();
                    if (isPrivate) {
                        long newChannelId = responseData.get("channelId").getAsLong();
                        String creator = SESSION_USERNAMES.getOrDefault(session.getId(), "");
                        if (!creator.isBlank()) {
                            PRIVATE_CHANNEL_MEMBERS
                                    .computeIfAbsent(newChannelId, k -> ConcurrentHashMap.newKeySet())
                                    .add(creator);
                        }
                    }
                    sendChannelListToConnectedUsers();
                }
                return;
            }

            if (incoming != null && incoming.getType() == MessageType.CREATE_DM_REQUEST) {
                JsonObject responseData = result.getResponseData();
                sendToSession(session, new SocketMessage(result.getResponseType(), responseData));
                if (responseData.has("success") && responseData.get("success").getAsBoolean()) {
                    sendChannelListToConnectedUsers();
                }
                return;
            }

            if (incoming != null && incoming.getType() == MessageType.RENAME_CHANNEL_REQUEST) {
                JsonObject responseData = result.getResponseData();
                sendToSession(session, new SocketMessage(result.getResponseType(), responseData));
                if (responseData.has("success") && responseData.get("success").getAsBoolean()) {
                    sendChannelListToConnectedUsers();
                }
                return;
            }

            if (incoming != null && incoming.getType() == MessageType.DELETE_CHANNEL_REQUEST) {
                JsonObject responseData = result.getResponseData();
                sendToSession(session, new SocketMessage(result.getResponseType(), responseData));
                if (responseData.has("success") && responseData.get("success").getAsBoolean()) {
                    sendChannelListToConnectedUsers();
                }
                return;
            }

            if (incoming != null && incoming.getType() == MessageType.TEST_ALERT) {
                sendToSession(session, new SocketMessage(result.getResponseType(), result.getResponseData()));
                return;
            }

            if (incoming != null && incoming.getType() == MessageType.UPDATE_THRESHOLDS) {
                // Broadcast new thresholds to ALL connected users so every panel stays in sync
                broadcast(new SocketMessage(result.getResponseType(), result.getResponseData()));
                return;
            }

            if (incoming != null && incoming.getType() == MessageType.SEARCH_CHANNEL_REQUEST) {
                sendToSession(session, new SocketMessage(result.getResponseType(), result.getResponseData()));
                return;
            }

            SocketMessage response = new SocketMessage(result.getResponseType(), result.getResponseData());
            if (result.isBroadcast()) {
                Long channelId = result.getChannelId() != null
                        ? result.getChannelId()
                        : SESSION_CHANNELS.get(session.getId());
                sendToChannel(channelId, response);
            } else {
                sendToSession(session, response);
            }
        } catch (Exception e) {
            SocketMessage error = new SocketMessage(
                    MessageType.ERROR,
                    ROUTER.route(null, "", List.of()).getResponseData());
            sendToSession(session, error);
        }
    }

    private static void handleLoginResponse(Session session, SocketMessage incoming, MessageRouter.RouteResult result) {
        JsonObject responseData = result.getResponseData();
        String requestedUsername = responseData.has("username")
                ? responseData.get("username").getAsString() : "";
        boolean isAlreadyConnected = false;
        if (!requestedUsername.isBlank()) {
            for (String existing : SESSION_USERNAMES.values()) {
                if (requestedUsername.equalsIgnoreCase(existing)) {
                    isAlreadyConnected = true;
                    break;
                }
            }
        }
        if (isAlreadyConnected) {
            JsonObject denied = new JsonObject();
            denied.addProperty("success", false);
            denied.addProperty("error", "El usuario ya tiene una sesion activa");
            sendToSession(session, new SocketMessage(MessageType.LOGIN_RESPONSE, denied));
            return;
        }

        sendToSession(session, new SocketMessage(result.getResponseType(), responseData));

        if (responseData.has("success") && responseData.get("success").getAsBoolean()) {
            SESSION_USERNAMES.put(session.getId(), responseData.get("username").getAsString());
            if (responseData.has("role")) {
                SESSION_ROLES.put(session.getId(), responseData.get("role").getAsString());
            }
            Channel defaultChannel = getDefaultChannel();
            SESSION_CHANNELS.put(session.getId(), defaultChannel.getId());

            // Send USER_LIST immediately after registering the new user so other clients
            // and the new session itself see the updated online list before any large payloads arrive.
            sendUserListToAll();

            List<Channel> userChannels = ROUTER.getMessageService()
                    .findChannelsForUser(responseData.get("username").getAsString());
            sendToSession(session, ROUTER.createChannelListMessage(userChannels));
            sendToSession(session, ROUTER.createMessageHistoryMessage(
                    defaultChannel,
                    ROUTER.getMessageService().findMessagesByChannelId(defaultChannel.getId())));
            sendToSession(session, ROUTER.createThresholdsMessage());
        }
    }

    public static void onClose(Session session) {
        CONNECTED_CLIENTS.remove(session);
        SESSION_USERNAMES.remove(session.getId());
        SESSION_ROLES.remove(session.getId());
        SESSION_CHANNELS.remove(session.getId());
        sendUserListToAll();
    }

    public static void onError(Session session, Throwable throwable) {
        if (session != null && session.isOpen()) {
            SocketMessage alert = new SocketMessage(
                    MessageType.SYSTEM_ALERT,
                    ROUTER.getMessageService().createSystemAlert("Error de conexion", "warning"));
            sendToSession(session, alert);
        }
        if (throwable != null) {
            System.err.println("WebSocket error: " + throwable.getMessage());
        }
    }

    public static void broadcast(SocketMessage message) {
        sendToAll(message);
    }

    private static void sendUserListToAll() {
        SocketMessage userList = ROUTER.createUserListMessage(SESSION_USERNAMES.values());
        sendToAll(userList);
    }

    /** Broadcasts a message only to sessions whose user has the ADMIN role. */
    public static void broadcastToAdmins(SocketMessage message) {
        String payload = ROUTER.toJson(message);
        for (Session client : CONNECTED_CLIENTS) {
            if (client.isOpen() && "ADMIN".equalsIgnoreCase(SESSION_ROLES.get(client.getId()))) {
                try {
                    client.getBasicRemote().sendText(payload);
                } catch (Exception ignored) {
                }
            }
        }
    }

    /** Sends each logged-in user their personalized channel list (public groups + their DMs). */
    private static void sendChannelListToConnectedUsers() {
        for (Session client : CONNECTED_CLIENTS) {
            if (!client.isOpen()) {
                continue;
            }
            String clientUsername = SESSION_USERNAMES.get(client.getId());
            List<Channel> channels = (clientUsername != null && !clientUsername.isBlank())
                    ? ROUTER.getMessageService().findPublicChannelsForUser(clientUsername)
                    : ROUTER.getMessageService().findAllPublicGroupChannels();
            sendToSession(client, ROUTER.createChannelListMessage(channels));
        }
    }

    /** Sends only public group channels to a single (unauthenticated) session. */
    private static void sendGroupChannelListToSession(Session session) {
        List<Channel> groupChannels = ROUTER.getMessageService().findAllPublicGroupChannels();
        sendToSession(session, ROUTER.createChannelListMessage(groupChannels));
    }

    private static void sendLatestMetricsToSession(Session session) {
        SocketMessage latestMetrics = SystemMonitor.getLatestMetricsMessage();
        if (latestMetrics != null) {
            sendToSession(session, latestMetrics);
        }
    }

    private static void sendLatestAlertToSession(Session session) {
        SocketMessage latestAlert = SystemMonitor.getLatestAlertMessage();
        if (latestAlert != null) {
            sendToSession(session, latestAlert);
        }
    }

    private static void handleJoinChannel(Session session, SocketMessage incoming) {
        if (incoming.getData() == null || !incoming.getData().has("channelId")) {
            sendToSession(session, new SocketMessage(
                    MessageType.ERROR,
                    ROUTER.getMessageService().createSystemAlert("Canal invalido", "warning")));
            return;
        }

        long channelId = incoming.getData().get("channelId").getAsLong();
        Channel channel = ROUTER.getMessageService().findAllChannels().stream()
                .filter(c -> c.getId().equals(channelId))
                .findFirst()
                .orElse(null);

        if (channel == null) {
            sendToSession(session, new SocketMessage(
                    MessageType.ERROR,
                    ROUTER.getMessageService().createSystemAlert("Canal no encontrado", "warning")));
            return;
        }

        String username = SESSION_USERNAMES.get(session.getId());
        if (channel.isDm() && username != null) {
            boolean isParticipant = username.equalsIgnoreCase(channel.getDmParticipant1())
                    || username.equalsIgnoreCase(channel.getDmParticipant2());
            if (!isParticipant) {
                sendToSession(session, new SocketMessage(
                        MessageType.ERROR,
                        ROUTER.getMessageService().createSystemAlert("Acceso denegado a este canal", "warning")));
                return;
            }
        }

        SESSION_CHANNELS.put(session.getId(), channel.getId());

        // Track membership for private group channels
        if (channel.isPrivate() && !channel.isDm() && username != null) {
            PRIVATE_CHANNEL_MEMBERS
                    .computeIfAbsent(channel.getId(), k -> ConcurrentHashMap.newKeySet())
                    .add(username);
        }

        sendToSession(session, ROUTER.createMessageHistoryMessage(
                channel,
                ROUTER.getMessageService().findMessagesByChannelId(channel.getId())));
    }

    private static Channel getDefaultChannel() {
        return ROUTER.getMessageService().getDefaultChannel()
                .orElseGet(() -> ROUTER.getMessageService().findAllGroupChannels().stream()
                        .findFirst()
                        .orElseThrow(() -> new IllegalStateException("No hay canales disponibles")));
    }

    private static void sendToAll(SocketMessage message) {
        String payload = ROUTER.toJson(message);
        for (Session client : CONNECTED_CLIENTS) {
            if (client.isOpen()) {
                try {
                    client.getBasicRemote().sendText(payload);
                } catch (Exception ignored) {
                }
            }
        }
    }

    private static void sendToChannel(Long channelId, SocketMessage message) {
        if (channelId == null) {
            sendToAll(message);
            return;
        }

        // Resolve channel to determine membership (DM vs group).
        Channel channel = ROUTER.getMessageService().findChannelById(channelId).orElse(null);

        String payload = ROUTER.toJson(message);
        for (Session client : CONNECTED_CLIENTS) {
            if (!client.isOpen()) continue;
            String clientUsername = SESSION_USERNAMES.get(client.getId());
            if (clientUsername == null || clientUsername.isBlank()) continue;

            if (channel != null && channel.isDm()) {
                boolean isParticipant = clientUsername.equalsIgnoreCase(channel.getDmParticipant1())
                        || clientUsername.equalsIgnoreCase(channel.getDmParticipant2());
                if (!isParticipant) continue;
            } else if (channel != null && channel.isPrivate()) {
                // Private group channel: only deliver to known members
                Set<String> members = PRIVATE_CHANNEL_MEMBERS.get(channel.getId());
                if (members == null || members.stream().noneMatch(m -> m.equalsIgnoreCase(clientUsername))) continue;
            }
            // Public group channel: deliver to every logged-in user.

            try {
                client.getBasicRemote().sendText(payload);
            } catch (Exception ignored) {
            }
        }
    }

    private static void sendToSession(Session session, SocketMessage message) {
        if (session == null || !session.isOpen()) {
            return;
        }
        try {
            session.getBasicRemote().sendText(ROUTER.toJson(message));
        } catch (Exception ignored) {
        }
    }
}
