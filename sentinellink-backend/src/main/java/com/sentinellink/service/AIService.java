package com.sentinellink.service;

import com.google.gson.JsonObject;

public class AIService {

    public JsonObject processPrompt(JsonObject requestData) {
        String prompt = "";
        if (requestData != null && requestData.has("prompt") && !requestData.get("prompt").isJsonNull()) {
            prompt = requestData.get("prompt").getAsString();
        }

        JsonObject response = new JsonObject();
        response.addProperty("response", "Respuesta simulada de IA para: " + prompt);
        return response;
    }
}
