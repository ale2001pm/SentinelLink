package com.sentinellink.service;

import com.google.gson.Gson;
import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import java.io.BufferedReader;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.HashMap;
import java.util.Map;

public class AIService {

    private static final Gson GSON = new Gson();
    private static final String DEFAULT_OPENAI_MODEL = "gpt-4o-mini";
    private static final String DEFAULT_OPENAI_URL = "https://api.openai.com/v1/chat/completions";
    private static final String DEFAULT_OLLAMA_MODEL = "llama3.1";
    private static final String DEFAULT_OLLAMA_URL = "http://localhost:11434/api/chat";
    private static final int REQUEST_TIMEOUT_SECONDS = 30;

    private static final Map<String, String> CONFIG = loadEnvFile();

    public JsonObject processPrompt(JsonObject requestData) {
        String prompt = "";
        if (requestData != null && requestData.has("prompt") && !requestData.get("prompt").isJsonNull()) {
            prompt = requestData.get("prompt").getAsString().trim();
        }

        if (prompt.isEmpty()) {
            return errorResponse("Prompt vacio. Escribe una pregunta para la IA.");
        }

        JsonArray messages = buildMessages(requestData, prompt);

        if (isOllamaEnabled()) {
            return callOllama(messages);
        }

        String apiKey = getConfig("OPENAI_API_KEY");
        if (apiKey == null || apiKey.isBlank()) {
            return errorResponse("Falta OPENAI_API_KEY en el archivo .env (o activa Ollama)");
        }

        String apiUrl = getConfig("OPENAI_API_URL");
        if (apiUrl == null || apiUrl.isBlank()) {
            apiUrl = DEFAULT_OPENAI_URL;
        }

        String model = getConfig("OPENAI_MODEL");
        if (model == null || model.isBlank()) {
            model = DEFAULT_OPENAI_MODEL;
        }

        JsonObject payload = new JsonObject();
        payload.addProperty("model", model);
        payload.add("messages", messages);
        payload.addProperty("temperature", 0.7);

        HttpClient client = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(10))
                .build();

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(apiUrl))
                .timeout(Duration.ofSeconds(REQUEST_TIMEOUT_SECONDS))
                .header("Authorization", "Bearer " + apiKey)
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(GSON.toJson(payload)))
                .build();

        try {
            HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                return errorResponse("Error API (" + response.statusCode() + "): " + extractErrorMessage(response.body()));
            }

            JsonObject parsed = GSON.fromJson(response.body(), JsonObject.class);
            String content = extractOpenAiContent(parsed);
            if (content == null || content.isBlank()) {
                return errorResponse("Respuesta vacia de la IA");
            }

            JsonObject result = new JsonObject();
            result.addProperty("response", content.trim());
            return result;
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return errorResponse("Error llamando a la IA: " + e.getMessage());
        } catch (IOException e) {
            return errorResponse("Error llamando a la IA: " + e.getMessage());
        } catch (Exception e) {
            return errorResponse("Error inesperado: " + e.getMessage());
        }
    }

    private JsonArray buildMessages(JsonObject requestData, String prompt) {
        JsonArray messages = new JsonArray();

        if (requestData != null && requestData.has("history") && requestData.get("history").isJsonArray()) {
            JsonArray history = requestData.getAsJsonArray("history");
            for (JsonElement element : history) {
                if (!element.isJsonObject()) {
                    continue;
                }
                JsonObject item = element.getAsJsonObject();
                String role = item.has("role") ? item.get("role").getAsString() : "";
                String content = item.has("content") ? item.get("content").getAsString() : "";
                if (role.isBlank() || content.isBlank()) {
                    continue;
                }
                JsonObject message = new JsonObject();
                message.addProperty("role", role);
                message.addProperty("content", content);
                messages.add(message);
            }
        }

        JsonObject userMessage = new JsonObject();
        userMessage.addProperty("role", "user");
        userMessage.addProperty("content", prompt);
        messages.add(userMessage);

        return messages;
    }

    private static Map<String, String> loadEnvFile() {
        Map<String, String> env = new HashMap<>();
        Path envPath = Path.of(".env");
        if (!Files.exists(envPath)) {
            return env;
        }

        try (BufferedReader reader = Files.newBufferedReader(envPath, StandardCharsets.UTF_8)) {
            String line;
            while ((line = reader.readLine()) != null) {
                String trimmed = line.trim();
                if (trimmed.isEmpty() || trimmed.startsWith("#")) {
                    continue;
                }
                int idx = trimmed.indexOf('=');
                if (idx <= 0) {
                    continue;
                }
                String key = trimmed.substring(0, idx).trim();
                String value = trimmed.substring(idx + 1).trim();
                if (!key.isEmpty()) {
                    env.put(key, value);
                }
            }
        } catch (IOException ignored) {
        }

        return env;
    }

    private static String getConfig(String key) {
        String envValue = System.getenv(key);
        if (envValue != null && !envValue.isBlank()) {
            return envValue;
        }
        return CONFIG.getOrDefault(key, "");
    }

    private static boolean isOllamaEnabled() {
        String useOllama = getConfig("USE_OLLAMA");
        if ("true".equalsIgnoreCase(useOllama)) {
            return true;
        }
        String apiUrl = getConfig("OLLAMA_API_URL");
        String model = getConfig("OLLAMA_MODEL");
        return (apiUrl != null && !apiUrl.isBlank()) || (model != null && !model.isBlank());
    }

    private JsonObject callOllama(JsonArray messages) {
        String apiUrl = getConfig("OLLAMA_API_URL");
        if (apiUrl == null || apiUrl.isBlank()) {
            apiUrl = DEFAULT_OLLAMA_URL;
        }

        String model = getConfig("OLLAMA_MODEL");
        if (model == null || model.isBlank()) {
            model = DEFAULT_OLLAMA_MODEL;
        }

        JsonObject payload = new JsonObject();
        payload.addProperty("model", model);
        payload.add("messages", messages);
        payload.addProperty("stream", false);

        HttpClient client = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(10))
                .build();

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(apiUrl))
                .timeout(Duration.ofSeconds(REQUEST_TIMEOUT_SECONDS))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(GSON.toJson(payload)))
                .build();

        try {
            HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                return errorResponse("Error Ollama (" + response.statusCode() + "): " + response.body());
            }

            JsonObject parsed = GSON.fromJson(response.body(), JsonObject.class);
            String content = extractOllamaContent(parsed);
            if (content == null || content.isBlank()) {
                return errorResponse("Respuesta vacia de la IA");
            }

            JsonObject result = new JsonObject();
            result.addProperty("response", content.trim());
            return result;
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return errorResponse("Error llamando a Ollama: " + e.getMessage());
        } catch (IOException e) {
            return errorResponse("Error llamando a Ollama: " + e.getMessage());
        } catch (Exception e) {
            return errorResponse("Error inesperado: " + e.getMessage());
        }
    }

    private static String extractOpenAiContent(JsonObject parsed) {
        if (parsed == null || !parsed.has("choices") || !parsed.get("choices").isJsonArray()) {
            return null;
        }
        JsonArray choices = parsed.getAsJsonArray("choices");
        if (choices.size() == 0 || !choices.get(0).isJsonObject()) {
            return null;
        }
        JsonObject choice = choices.get(0).getAsJsonObject();
        if (!choice.has("message") || !choice.get("message").isJsonObject()) {
            return null;
        }
        JsonObject message = choice.getAsJsonObject("message");
        if (!message.has("content")) {
            return null;
        }
        return message.get("content").getAsString();
    }

    private static String extractOllamaContent(JsonObject parsed) {
        if (parsed == null) {
            return null;
        }
        if (parsed.has("message") && parsed.get("message").isJsonObject()) {
            JsonObject message = parsed.getAsJsonObject("message");
            if (message.has("content")) {
                return message.get("content").getAsString();
            }
        }
        if (parsed.has("response")) {
            return parsed.get("response").getAsString();
        }
        return null;
    }

    private static String extractErrorMessage(String body) {
        try {
            JsonObject parsed = GSON.fromJson(body, JsonObject.class);
            if (parsed != null && parsed.has("error") && parsed.get("error").isJsonObject()) {
                JsonObject error = parsed.getAsJsonObject("error");
                if (error.has("message")) {
                    return error.get("message").getAsString();
                }
            }
        } catch (Exception ignored) {
        }
        return body == null ? "" : body.trim();
    }

    private static JsonObject errorResponse(String message) {
        JsonObject response = new JsonObject();
        response.addProperty("response", message);
        response.addProperty("error", true);
        return response;
    }
}
