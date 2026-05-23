package com.sentinellink.websocket;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import com.sentinellink.model.Channel;
import com.sentinellink.model.Message;
import com.sentinellink.service.AIService;
import com.sentinellink.service.AuthService;
import com.sentinellink.service.EmailService;
import com.sentinellink.service.MessageService;
import com.sentinellink.service.SystemMonitor;
import com.sentinellink.service.UserPresenceService;
import java.util.Collection;
import java.util.Collections;
import java.util.List;

public class MessageRouter {

    private final Gson gson;
    private final AuthService authService;
    private final MessageService messageService;
    private final UserPresenceService userPresenceService;
    private final AIService aiService;

    public MessageRouter() {
        this.gson = new Gson();
        this.authService = new AuthService();
        this.messageService = new MessageService();
        this.userPresenceService = new UserPresenceService();
        this.aiService = new AIService();
    }

    public SocketMessage parse(String rawMessage) {
        return gson.fromJson(rawMessage, SocketMessage.class);
    }

    public RouteResult route(SocketMessage incoming, String sender, Collection<String> connectedUsers) {
        if (incoming == null || incoming.getType() == null) {
            return new RouteResult(MessageType.ERROR,
                    messageService.createSystemAlert("Mensaje invalido", "warning"),
                    false);
        }

        JsonObject data = incoming.getData() == null ? new JsonObject() : incoming.getData();

        switch (incoming.getType()) {
            case LOGIN_REQUEST:
                return new RouteResult(MessageType.LOGIN_RESPONSE, authService.login(data), false);
            case REGISTER_REQUEST:
                return new RouteResult(MessageType.REGISTER_RESPONSE, authService.register(data), false);
            case CREATE_CHANNEL_REQUEST:
                return new RouteResult(MessageType.CREATE_CHANNEL_RESPONSE, messageService.createChannel(data), false);
            case RENAME_CHANNEL_REQUEST:
                return new RouteResult(MessageType.RENAME_CHANNEL_RESPONSE, messageService.renameChannel(data), false);
            case DELETE_CHANNEL_REQUEST:
                return new RouteResult(MessageType.DELETE_CHANNEL_RESPONSE, messageService.deleteChannel(data), false);
            case CREATE_DM_REQUEST:
                return new RouteResult(MessageType.CREATE_DM_RESPONSE, messageService.createDm(sender, data), false);
            case SEND_MESSAGE:
                Message savedMessage = messageService.saveChatMessage(sender, data);
                return new RouteResult(
                        MessageType.RECEIVE_MESSAGE,
                        messageService.createReceiveMessagePayload(savedMessage),
                        true,
                        savedMessage.getChannel().getId()
                );
            case UPDATE_THRESHOLDS:
                return handleUpdateThresholds(data);
            case TEST_ALERT:
                return handleTestAlert();
            case CHANGE_PASSWORD_REQUEST:
                return new RouteResult(MessageType.CHANGE_PASSWORD_RESPONSE,
                        authService.changePassword(sender, data), false);
            case SEARCH_CHANNEL_REQUEST:
                String channelName = data.has("name") ? data.get("name").getAsString() : "";
                return new RouteResult(MessageType.SEARCH_CHANNEL_RESPONSE,
                        messageService.searchChannel(channelName), false);
            case AI_REQUEST:
                return new RouteResult(MessageType.AI_RESPONSE, aiService.processPrompt(data), false);
            default:
                return new RouteResult(
                        MessageType.SYSTEM_ALERT,
                        messageService.createSystemAlert("Tipo de mensaje no soportado", "warning"),
                        false
                );
        }
    }

    private RouteResult handleUpdateThresholds(JsonObject data) {
        SystemMonitor monitor = SystemMonitor.getInstance();
        if (monitor == null) {
            return new RouteResult(MessageType.ERROR,
                    messageService.createSystemAlert("Monitor no disponible", "warning"), false);
        }
        double cpu  = getDoubleOrDefault(data, "cpuThreshold",  monitor.getCpuThreshold());
        double ram  = getDoubleOrDefault(data, "ramThreshold",  monitor.getRamThreshold());
        double disk = getDoubleOrDefault(data, "diskThreshold", monitor.getDiskThreshold());
        monitor.updateThresholds(cpu, ram, disk);
        JsonObject response = messageService.createThresholdsPayload(
                monitor.getCpuThreshold(), monitor.getRamThreshold(), monitor.getDiskThreshold());
        response.addProperty("success", true);
        return new RouteResult(MessageType.THRESHOLDS_RESPONSE, response, false);
    }

    private RouteResult handleTestAlert() {
        SystemMonitor monitor = SystemMonitor.getInstance();
        SocketMessage testAlert = monitor != null
                ? monitor.buildTestAlertMessage()
                : new SocketMessage(MessageType.SYSTEM_ALERT,
                        messageService.createSystemAlert("Notificacion de prueba", "warning"));
        WebSocketServer.broadcast(testAlert);
        if (monitor != null) {
            EmailService.sendTestAlert(
                    monitor.getCpuThreshold(), monitor.getRamThreshold(), monitor.getDiskThreshold());
        }
        JsonObject ack = new JsonObject();
        ack.addProperty("success", true);
        return new RouteResult(MessageType.THRESHOLDS_RESPONSE, ack, false);
    }

    private double getDoubleOrDefault(JsonObject json, String key, double defaultValue) {
        if (json == null || !json.has(key) || json.get(key).isJsonNull()) {
            return defaultValue;
        }
        try {
            return json.get(key).getAsDouble();
        } catch (Exception e) {
            return defaultValue;
        }
    }

    public SocketMessage createUserListMessage(Collection<String> connectedUsers) {
        Collection<String> safeUsers = connectedUsers == null ? Collections.emptyList() : connectedUsers;
        return new SocketMessage(MessageType.USER_LIST, userPresenceService.buildUserList(safeUsers));
    }

    public SocketMessage createChannelListMessage(Collection<Channel> channels) {
        return new SocketMessage(MessageType.CHANNEL_LIST, messageService.createChannelListPayload(channels));
    }

    public SocketMessage createMessageHistoryMessage(Channel channel, List<Message> messages) {
        return new SocketMessage(MessageType.MESSAGE_HISTORY, messageService.createMessageHistoryPayload(channel, messages));
    }

    public SocketMessage createThresholdsMessage() {
        SystemMonitor monitor = SystemMonitor.getInstance();
        if (monitor == null) {
            return new SocketMessage(MessageType.THRESHOLDS_RESPONSE, messageService.createThresholdsPayload(80, 90, 90));
        }
        return new SocketMessage(MessageType.THRESHOLDS_RESPONSE,
                messageService.createThresholdsPayload(
                        monitor.getCpuThreshold(), monitor.getRamThreshold(), monitor.getDiskThreshold()));
    }

    public String toJson(SocketMessage message) {
        return gson.toJson(message);
    }

    public MessageService getMessageService() {
        return messageService;
    }

    public static class RouteResult {
        private final MessageType responseType;
        private final JsonObject responseData;
        private final boolean broadcast;
        private final Long channelId;

        public RouteResult(MessageType responseType, JsonObject responseData, boolean broadcast) {
            this(responseType, responseData, broadcast, null);
        }

        public RouteResult(MessageType responseType, JsonObject responseData, boolean broadcast, Long channelId) {
            this.responseType = responseType;
            this.responseData = responseData;
            this.broadcast = broadcast;
            this.channelId = channelId;
        }

        public MessageType getResponseType() { return responseType; }
        public JsonObject getResponseData()  { return responseData; }
        public boolean isBroadcast()         { return broadcast; }
        public Long getChannelId()           { return channelId; }
    }
}
