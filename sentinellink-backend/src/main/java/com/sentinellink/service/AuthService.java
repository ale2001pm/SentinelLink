package com.sentinellink.service;

import com.google.gson.JsonObject;
import com.sentinellink.model.User;
import com.sentinellink.model.UserRole;
import com.sentinellink.repository.UserRepository;
import java.util.Optional;
import org.mindrot.jbcrypt.BCrypt;

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

        if (user.isPresent() && BCrypt.checkpw(password, user.get().getPassword())) {
            response.addProperty("success", true);
            response.addProperty("role", user.get().getRole().name());
            response.addProperty("username", user.get().getUsername());
            return response;
        }

        response.addProperty("success", false);
        response.addProperty("error", "Credenciales invalidas");
        return response;
    }

    public JsonObject register(JsonObject registerData) {
        String username = getStringOrEmpty(registerData, "username").trim();
        String password = getStringOrEmpty(registerData, "password").trim();

        JsonObject response = new JsonObject();
        if (username.length() < 3) {
            response.addProperty("success", false);
            response.addProperty("error", "El usuario debe tener al menos 3 caracteres");
            return response;
        }
        if (password.length() < 4) {
            response.addProperty("success", false);
            response.addProperty("error", "La contrasena debe tener al menos 4 caracteres");
            return response;
        }
        if (userRepository.findByUsername(username).isPresent()) {
            response.addProperty("success", false);
            response.addProperty("error", "El usuario ya existe");
            return response;
        }

        User user = new User(username, BCrypt.hashpw(password, BCrypt.gensalt()), UserRole.USER, false);
        userRepository.save(user);

        response.addProperty("success", true);
        response.addProperty("username", user.getUsername());
        response.addProperty("role", user.getRole().name().toLowerCase());
        return response;
    }

    public JsonObject changePassword(String username, JsonObject data) {
        String currentPassword = getStringOrEmpty(data, "currentPassword");
        String newPassword     = getStringOrEmpty(data, "newPassword");

        JsonObject response = new JsonObject();
        if (newPassword.length() < 4) {
            response.addProperty("success", false);
            response.addProperty("error", "La nueva contrasena debe tener al menos 4 caracteres");
            return response;
        }

        Optional<User> userOpt = userRepository.findByUsername(username);
        if (userOpt.isEmpty()) {
            response.addProperty("success", false);
            response.addProperty("error", "Usuario no encontrado");
            return response;
        }

        User user = userOpt.get();
        if (!BCrypt.checkpw(currentPassword, user.getPassword())) {
            response.addProperty("success", false);
            response.addProperty("error", "Contrasena actual incorrecta");
            return response;
        }

        user.setPassword(BCrypt.hashpw(newPassword, BCrypt.gensalt()));
        userRepository.save(user);
        response.addProperty("success", true);
        return response;
    }

    private String getStringOrEmpty(JsonObject json, String key) {
        if (json == null || !json.has(key) || json.get(key).isJsonNull()) {
            return "";
        }
        return json.get(key).getAsString();
    }
}
