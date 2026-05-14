package com.sentinellink.websocket;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import com.sentinellink.model.Channel;
import com.sentinellink.model.Message;
import com.sentinellink.service.AIService;
import com.sentinellink.service.AuthService;
import com.sentinellink.service.MessageService;
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
            case SEND_MESSAGE:
                Message savedMessage = messageService.saveChatMessage(sender, data);
                return new RouteResult(
                        MessageType.RECEIVE_MESSAGE,
                        messageService.createReceiveMessagePayload(savedMessage),
                        true,
                        savedMessage.getChannel().getId()
                );
            case AI_REQUEST:
                return new RouteResult(MessageType.AI_RESPONSE, aiService.processPrompt(data), false);
            default:
                return new RouteResult(
                        MessageType.SYSTEM_ALERT,
                        messageService.createSystemAlert("Tipo de mensaje no soportado en esta fase", "warning"),
                        false
                );
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

        public MessageType getResponseType() {
            return responseType;
        }

        public JsonObject getResponseData() {
            return responseData;
        }

        public boolean isBroadcast() {
            return broadcast;
        }

        public Long getChannelId() {
            return channelId;
        }
    }
}
