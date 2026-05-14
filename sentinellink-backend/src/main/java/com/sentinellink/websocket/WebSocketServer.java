package com.sentinellink.websocket;

import com.sentinellink.model.Channel;
import jakarta.websocket.Session;
import java.io.IOException;
import java.util.List;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import org.glassfish.tyrus.server.Server;

public class WebSocketServer {

    private static final int DEFAULT_PORT = 8080;

    private static final MessageRouter ROUTER = new MessageRouter();
    private static final Set<Session> CONNECTED_CLIENTS = ConcurrentHashMap.newKeySet();
    private static final ConcurrentHashMap<String, String> SESSION_USERNAMES = new ConcurrentHashMap<>();
    private static final ConcurrentHashMap<String, Long> SESSION_CHANNELS = new ConcurrentHashMap<>();

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
        sendChannelListToAll();
        sendUserListToAll();
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

            if (incoming != null && incoming.getType() == MessageType.LOGIN_REQUEST && incoming.getData() != null
                    && incoming.getData().has("username") && incoming.getData().has("password")) {
                SocketMessage loginResponse = new SocketMessage(result.getResponseType(), result.getResponseData());
                sendToSession(session, loginResponse);

                if (result.getResponseData().has("success") && result.getResponseData().get("success").getAsBoolean()) {
                    SESSION_USERNAMES.put(session.getId(), result.getResponseData().get("username").getAsString());
                    Channel defaultChannel = getDefaultChannel();
                    SESSION_CHANNELS.put(session.getId(), defaultChannel.getId());
                    sendToSession(session, ROUTER.createChannelListMessage(ROUTER.getMessageService().findAllChannels()));
                    sendToSession(session, ROUTER.createMessageHistoryMessage(
                            defaultChannel,
                            ROUTER.getMessageService().findMessagesByChannelId(defaultChannel.getId())));
                    sendUserListToAll();
                }
                return;
            }

            SocketMessage response = new SocketMessage(result.getResponseType(), result.getResponseData());
            if (result.isBroadcast()) {
                Long channelId = result.getChannelId();
                if (channelId == null) {
                    channelId = SESSION_CHANNELS.get(session.getId());
                }
                sendToChannel(channelId, response);
            } else {
                sendToSession(session, response);
            }
        } catch (Exception e) {
            SocketMessage error = new SocketMessage(
                    MessageType.ERROR,
                    ROUTER.route(null, "", List.of()).getResponseData()
            );
            sendToSession(session, error);
        }
    }

    public static void onClose(Session session) {
        CONNECTED_CLIENTS.remove(session);
        SESSION_USERNAMES.remove(session.getId());
        SESSION_CHANNELS.remove(session.getId());
        sendUserListToAll();
    }

    public static void onError(Session session, Throwable throwable) {
        if (session != null && session.isOpen()) {
            MessageRouter.RouteResult result = ROUTER.route(
                    new SocketMessage(MessageType.SYSTEM_ALERT, null),
                    "",
                    List.of());
            SocketMessage alert = new SocketMessage(
                    MessageType.SYSTEM_ALERT,
                    result.getResponseData()
            );
            sendToSession(session, alert);
        }
        if (throwable != null) {
            System.err.println("WebSocket error: " + throwable.getMessage());
        }
    }

    private static void sendUserListToAll() {
        SocketMessage userList = ROUTER.createUserListMessage(SESSION_USERNAMES.values());
        sendToAll(userList);
    }

    private static void sendChannelListToAll() {
        SocketMessage channelList = ROUTER.createChannelListMessage(ROUTER.getMessageService().findAllChannels());
        sendToAll(channelList);
    }

    private static void handleJoinChannel(Session session, SocketMessage incoming) {
        if (incoming.getData() == null || !incoming.getData().has("channelId")) {
            sendToSession(session, new SocketMessage(
                    MessageType.ERROR,
                    ROUTER.getMessageService().createSystemAlert("Canal invalido", "warning")
            ));
            return;
        }

        long channelId = incoming.getData().get("channelId").getAsLong();
        Channel channel = ROUTER.getMessageService().findAllChannels().stream()
                .filter(candidate -> candidate.getId().equals(channelId))
                .findFirst()
                .orElse(null);

        if (channel == null) {
            sendToSession(session, new SocketMessage(
                    MessageType.ERROR,
                    ROUTER.getMessageService().createSystemAlert("Canal no encontrado", "warning")
            ));
            return;
        }

        SESSION_CHANNELS.put(session.getId(), channel.getId());
        sendToSession(session, ROUTER.createMessageHistoryMessage(
                channel,
                ROUTER.getMessageService().findMessagesByChannelId(channel.getId())));
    }

    private static Channel getDefaultChannel() {
        return ROUTER.getMessageService().getDefaultChannel()
                .orElseGet(() -> ROUTER.getMessageService().findAllChannels().stream()
                        .findFirst()
                        .orElseThrow(() -> new IllegalStateException("No hay canales disponibles")));
    }

    private static void sendToAll(SocketMessage message) {
        String payload = ROUTER.toJson(message);
        for (Session client : CONNECTED_CLIENTS) {
            if (client.isOpen()) {
                try {
                    client.getBasicRemote().sendText(payload);
                } catch (IOException ignored) {
                }
            }
        }
    }

    private static void sendToChannel(Long channelId, SocketMessage message) {
        if (channelId == null) {
            sendToAll(message);
            return;
        }

        String payload = ROUTER.toJson(message);
        for (Session client : CONNECTED_CLIENTS) {
            if (client.isOpen() && channelId.equals(SESSION_CHANNELS.get(client.getId()))) {
                try {
                    client.getBasicRemote().sendText(payload);
                } catch (IOException ignored) {
                }
            }
        }
    }

    private static void sendToSession(Session session, SocketMessage message) {
        if (session == null || !session.isOpen()) {
            return;
        }
        try {
            session.getBasicRemote().sendText(ROUTER.toJson(message));
        } catch (IOException ignored) {
        }
    }
}
