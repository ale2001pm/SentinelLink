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
        if (content.isEmpty()) {
            throw new IllegalArgumentException("El mensaje no puede estar vacio");
        }

        Channel channel = resolveChannel(sendData);
        Message message = new Message(content, LocalDateTime.now(), sender, channel);
        return messageRepository.save(message);
    }

    public JsonObject createReceiveMessagePayload(Message message) {
        JsonObject response = new JsonObject();
        response.addProperty("messageId", message.getId());
        response.addProperty("sender", message.getSender().getUsername());
        response.addProperty("content", message.getContent());
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

    public Optional<Channel> getDefaultChannel() {
        return channelRepository.findByName("general");
    }

    public List<Message> findMessagesByChannelId(Long channelId) {
        return messageRepository.findByChannelId(channelId);
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
}
