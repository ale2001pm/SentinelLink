package com.sentinellink.service;

import com.google.gson.JsonObject;
import java.time.LocalDateTime;

public class MessageService {

    public JsonObject createReceiveMessagePayload(String sender, JsonObject sendData) {
        String content = "";
        if (sendData != null && sendData.has("content") && !sendData.get("content").isJsonNull()) {
            content = sendData.get("content").getAsString();
        }

        JsonObject response = new JsonObject();
        response.addProperty("sender", sender == null || sender.isEmpty() ? "system" : sender);
        response.addProperty("content", content);
        response.addProperty("timestamp", LocalDateTime.now().toString());
        return response;
    }

    public JsonObject createSystemAlert(String message, String level) {
        JsonObject alert = new JsonObject();
        alert.addProperty("message", message);
        alert.addProperty("level", level);
        return alert;
    }
}
