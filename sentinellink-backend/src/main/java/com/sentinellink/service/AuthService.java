package com.sentinellink.service;

import com.google.gson.JsonObject;
import com.sentinellink.model.User;
import com.sentinellink.repository.UserRepository;
import java.util.Optional;

public class AuthService {

    private final UserRepository userRepository;

    public AuthService() {
        this.userRepository = new UserRepository();
    }

    public JsonObject login(JsonObject loginData) {
        String username = getStringOrEmpty(loginData, "username");
        String password = getStringOrEmpty(loginData, "password");

        JsonObject response = new JsonObject();
        Optional<User> user = userRepository.findByUsername(username);

        if (user.isPresent() && user.get().getPassword().equals(password)) {
            response.addProperty("success", true);
            response.addProperty("role", user.get().getRole().name().toLowerCase());
            response.addProperty("username", user.get().getUsername());
            return response;
        }

        response.addProperty("success", false);
        response.addProperty("error", "Credenciales invalidas");
        return response;
    }

    private String getStringOrEmpty(JsonObject json, String key) {
        if (json == null || !json.has(key) || json.get(key).isJsonNull()) {
            return "";
        }
        return json.get(key).getAsString();
    }
}
