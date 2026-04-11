package com.sentinellink.websocket;

import com.google.gson.JsonObject;

public class SocketMessage {

    private MessageType type;
    private JsonObject data;

    public SocketMessage() {
    }

    public SocketMessage(MessageType type, JsonObject data) {
        this.type = type;
        this.data = data;
    }

    public MessageType getType() {
        return type;
    }

    public JsonObject getData() {
        return data;
    }
}
