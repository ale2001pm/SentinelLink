package com.sentinellink.service;

import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import com.sentinellink.model.Channel;
import com.sentinellink.model.Message;
import com.sentinellink.model.User;
import com.sentinellink.repository.ChannelRepository;
import com.sentinellink.repository.MessageRepository;
import com.sentinellink.repository.UserRepository;
import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

public class MessageService {

    private final MessageRepository messageRepository;
    private final UserRepository userRepository;
    private final ChannelRepository channelRepository;

    public MessageService() {
        this.messageRepository = new MessageRepository();
        this.userRepository = new UserRepository();
        this.channelRepository = new ChannelRepository();
    }

    public Message saveChatMessage(String senderUsername, JsonObject sendData) {
        User sender = userRepository.findByUsername(senderUsername)
                .orElseThrow(() -> new IllegalStateException("Usuario emisor no encontrado"));

        String content = getStringOrEmpty(sendData, "content").trim();
        String imageData = getStringOrEmpty(sendData, "imageBase64").trim();
        boolean isImage = !imageData.isEmpty();
        if (!isImage && content.isEmpty()) {
            throw new IllegalArgumentException("El mensaje no puede estar vacio");
        }

        Channel channel = resolveChannel(sendData);
        String messageType = isImage ? "IMAGE" : "TEXT";
        if (isImage && content.isEmpty()) {
            content = "";
        }
        Message message = new Message(
                content,
                messageType,
                isImage ? imageData : null,
                LocalDateTime.now(),
                sender,
                channel
        );
        return messageRepository.save(message);
    }

    public JsonObject createReceiveMessagePayload(Message message) {
        JsonObject response = new JsonObject();
        response.addProperty("messageId", message.getId());
        response.addProperty("sender", message.getSender().getUsername());
        response.addProperty("content", message.getContent());
        response.addProperty("messageType", message.getMessageType());
        if (message.getImageData() != null && !message.getImageData().isEmpty()) {
            response.addProperty("imageBase64", message.getImageData());
        }
        response.addProperty("timestamp", message.getTimestamp().toString());
        response.addProperty("channelId", message.getChannel().getId());
        response.addProperty("channelName", message.getChannel().getName());
        return response;
    }

    public JsonObject createChannelListPayload(Collection<Channel> channels) {
        JsonArray channelArray = new JsonArray();
        if (channels != null) {
            for (Channel channel : channels) {
                JsonObject channelJson = new JsonObject();
                channelJson.addProperty("id", channel.getId());
                channelJson.addProperty("name", channel.getName());
                channelJson.addProperty("private", channel.isPrivate());
                channelJson.addProperty("channelType", channel.isDm() ? "DM" : "GROUP");
                if (channel.isDm()) {
                    channelJson.addProperty("dmParticipant1", channel.getDmParticipant1());
                    channelJson.addProperty("dmParticipant2", channel.getDmParticipant2());
                }
                channelArray.add(channelJson);
            }
        }

        JsonObject response = new JsonObject();
        response.add("channels", channelArray);
        return response;
    }

    public JsonObject createMessageHistoryPayload(Channel channel, List<Message> messages) {
        JsonArray historyArray = new JsonArray();
        if (messages != null) {
            for (Message message : messages) {
                historyArray.add(createReceiveMessagePayload(message));
            }
        }

        JsonObject response = new JsonObject();
        response.addProperty("channelId", channel.getId());
        response.addProperty("channelName", channel.getName());
        response.add("messages", historyArray);
        return response;
    }

    public List<Channel> findAllChannels() {
        return channelRepository.findAll();
    }

    public Optional<Channel> findChannelById(Long channelId) {
        return channelRepository.findById(channelId);
    }

    public List<Channel> findAllGroupChannels() {
        return channelRepository.findAllGroupChannels();
    }

    public List<Channel> findChannelsForUser(String username) {
        return channelRepository.findChannelsForUser(username);
    }

    public Optional<Channel> getDefaultChannel() {
        return channelRepository.findByName("general");
    }

    public List<Message> findMessagesByChannelId(Long channelId) {
        return messageRepository.findByChannelId(channelId);
    }

    public JsonObject createChannel(JsonObject data) {
        String name = getStringOrEmpty(data, "name").trim();
        boolean isPrivate = getBooleanOrDefault(data, "private", false);

        JsonObject response = new JsonObject();
        if (name.length() < 3) {
            response.addProperty("success", false);
            response.addProperty("error", "El nombre del canal debe tener al menos 3 caracteres");
            return response;
        }
        if (name.length() > 40) {
            response.addProperty("success", false);
            response.addProperty("error", "El nombre del canal es demasiado largo");
            return response;
        }
        if (channelRepository.findByName(name).isPresent()) {
            response.addProperty("success", false);
            response.addProperty("error", "El canal ya existe");
            return response;
        }

        Channel channel = new Channel(name, isPrivate);
        Channel saved = channelRepository.save(channel);

        response.addProperty("success", true);
        response.addProperty("channelId", saved.getId());
        response.addProperty("name", saved.getName());
        response.addProperty("private", saved.isPrivate());
        return response;
    }

    public JsonObject renameChannel(JsonObject data) {
        JsonObject response = new JsonObject();
        Long channelId = getLongOrNull(data, "channelId");
        String newName = getStringOrEmpty(data, "newName").trim();

        if (channelId == null) {
            response.addProperty("success", false);
            response.addProperty("error", "ID de canal no especificado");
            return response;
        }
        if (newName.length() < 3) {
            response.addProperty("success", false);
            response.addProperty("error", "El nombre debe tener al menos 3 caracteres");
            return response;
        }
        if (newName.length() > 40) {
            response.addProperty("success", false);
            response.addProperty("error", "El nombre es demasiado largo");
            return response;
        }

        Optional<Channel> opt = channelRepository.findById(channelId);
        if (!opt.isPresent()) {
            response.addProperty("success", false);
            response.addProperty("error", "Canal no encontrado");
            return response;
        }
        Channel channel = opt.get();
        if (channel.isDm()) {
            response.addProperty("success", false);
            response.addProperty("error", "No se puede renombrar un canal DM");
            return response;
        }
        if (channelRepository.findByName(newName).filter(c -> !c.getId().equals(channelId)).isPresent()) {
            response.addProperty("success", false);
            response.addProperty("error", "Ya existe un canal con ese nombre");
            return response;
        }

        channel.setName(newName);
        channelRepository.save(channel);

        response.addProperty("success", true);
        response.addProperty("channelId", channelId);
        response.addProperty("newName", newName);
        return response;
    }

    public JsonObject deleteChannel(JsonObject data) {
        JsonObject response = new JsonObject();
        Long channelId = getLongOrNull(data, "channelId");

        if (channelId == null) {
            response.addProperty("success", false);
            response.addProperty("error", "ID de canal no especificado");
            return response;
        }

        Optional<Channel> opt = channelRepository.findById(channelId);
        if (!opt.isPresent()) {
            response.addProperty("success", false);
            response.addProperty("error", "Canal no encontrado");
            return response;
        }
        Channel channel = opt.get();
        if (channel.isDm()) {
            response.addProperty("success", false);
            response.addProperty("error", "No se puede eliminar un canal DM");
            return response;
        }
        if ("general".equalsIgnoreCase(channel.getName())) {
            response.addProperty("success", false);
            response.addProperty("error", "No se puede eliminar el canal general");
            return response;
        }

        messageRepository.deleteByChannelId(channelId);
        channelRepository.deleteById(channelId);

        response.addProperty("success", true);
        response.addProperty("channelId", channelId);
        return response;
    }

    public JsonObject createDm(String senderUsername, JsonObject data) {
        String targetUsername = getStringOrEmpty(data, "targetUser").trim();

        JsonObject response = new JsonObject();
        if (targetUsername.isEmpty()) {
            response.addProperty("success", false);
            response.addProperty("error", "Usuario destino no especificado");
            return response;
        }
        if (targetUsername.equalsIgnoreCase(senderUsername)) {
            response.addProperty("success", false);
            response.addProperty("error", "No puedes iniciar un DM contigo mismo");
            return response;
        }
        if (!userRepository.findByUsername(targetUsername).isPresent()) {
            response.addProperty("success", false);
            response.addProperty("error", "El usuario no existe");
            return response;
        }

        Optional<Channel> existing = channelRepository.findDmBetween(senderUsername, targetUsername);
        if (existing.isPresent()) {
            Channel dm = existing.get();
            response.addProperty("success", true);
            response.addProperty("channelId", dm.getId());
            response.addProperty("name", dm.getName());
            response.addProperty("channelType", "DM");
            response.addProperty("dmParticipant1", dm.getDmParticipant1());
            response.addProperty("dmParticipant2", dm.getDmParticipant2());
            response.addProperty("alreadyExisted", true);
            return response;
        }

        String p1 = senderUsername.compareToIgnoreCase(targetUsername) <= 0 ? senderUsername : targetUsername;
        String p2 = senderUsername.compareToIgnoreCase(targetUsername) <= 0 ? targetUsername : senderUsername;
        String dmName = "dm:" + p1 + ":" + p2;

        Channel dm = new Channel(dmName, p1, p2);
        Channel saved = channelRepository.save(dm);

        response.addProperty("success", true);
        response.addProperty("channelId", saved.getId());
        response.addProperty("name", saved.getName());
        response.addProperty("channelType", "DM");
        response.addProperty("dmParticipant1", saved.getDmParticipant1());
        response.addProperty("dmParticipant2", saved.getDmParticipant2());
        response.addProperty("alreadyExisted", false);
        return response;
    }

    public JsonObject createSystemAlert(String message, String level) {
        JsonObject alert = new JsonObject();
        alert.addProperty("message", message);
        alert.addProperty("level", level);
        return alert;
    }

    public JsonObject createSystemMetricsPayload(double cpuPercent,
                                                 double ramPercent,
                                                 double diskPercent,
                                                 long timestamp) {
        JsonObject payload = new JsonObject();
        payload.addProperty("cpuPercent", cpuPercent);
        payload.addProperty("ramPercent", ramPercent);
        payload.addProperty("diskPercent", diskPercent);
        payload.addProperty("timestamp", timestamp);
        return payload;
    }

    public JsonObject createSystemAlert(String message,
                                        String level,
                                        String metric,
                                        double value,
                                        double threshold) {
        JsonObject alert = createSystemAlert(message, level);
        alert.addProperty("metric", metric);
        alert.addProperty("value", value);
        alert.addProperty("threshold", threshold);
        alert.addProperty("timestamp", System.currentTimeMillis());
        return alert;
    }

    public JsonObject createThresholdsPayload(double cpu, double ram, double disk) {
        JsonObject payload = new JsonObject();
        payload.addProperty("cpuThreshold", cpu);
        payload.addProperty("ramThreshold", ram);
        payload.addProperty("diskThreshold", disk);
        return payload;
    }

    private Channel resolveChannel(JsonObject sendData) {
        Long channelId = getLongOrNull(sendData, "channelId");
        if (channelId != null) {
            return channelRepository.findById(channelId)
                    .orElseGet(() -> getDefaultChannel().orElseThrow(
                            () -> new IllegalStateException("Canal por defecto no disponible")));
        }
        return getDefaultChannel().orElseThrow(() -> new IllegalStateException("Canal por defecto no disponible"));
    }

    private String getStringOrEmpty(JsonObject json, String key) {
        if (json == null || !json.has(key) || json.get(key).isJsonNull()) {
            return "";
        }
        return json.get(key).getAsString();
    }

    private Long getLongOrNull(JsonObject json, String key) {
        if (json == null || !json.has(key) || json.get(key).isJsonNull()) {
            return null;
        }
        return json.get(key).getAsLong();
    }

    private boolean getBooleanOrDefault(JsonObject json, String key, boolean defaultValue) {
        if (json == null || !json.has(key) || json.get(key).isJsonNull()) {
            return defaultValue;
        }
        return json.get(key).getAsBoolean();
    }
}
