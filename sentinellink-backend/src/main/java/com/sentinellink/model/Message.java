package com.sentinellink.model;

import java.time.LocalDateTime;
import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.FetchType;
import javax.persistence.GeneratedValue;
import javax.persistence.GenerationType;
import javax.persistence.Id;
import javax.persistence.JoinColumn;
import javax.persistence.ManyToOne;
import javax.persistence.Table;

@Entity
@Table(name = "app_message")
public class Message {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 2000)
    private String content;

    @Column(nullable = false, length = 20)
    private String messageType;

    @Column(length = 100000)
    private String imageData;

    @Column(nullable = false)
    private LocalDateTime timestamp;

    @ManyToOne(fetch = FetchType.EAGER, optional = false)
    @JoinColumn(name = "sender_id", nullable = false)
    private User sender;

    @ManyToOne(fetch = FetchType.EAGER, optional = false)
    @JoinColumn(name = "channel_id", nullable = false)
    private Channel channel;

    public Message() {
    }

    public Message(String content, LocalDateTime timestamp, User sender, Channel channel) {
        this.content = content;
        this.messageType = "TEXT";
        this.imageData = null;
        this.timestamp = timestamp;
        this.sender = sender;
        this.channel = channel;
    }

    public Message(String content,
                   String messageType,
                   String imageData,
                   LocalDateTime timestamp,
                   User sender,
                   Channel channel) {
        this.content = content;
        this.messageType = messageType;
        this.imageData = imageData;
        this.timestamp = timestamp;
        this.sender = sender;
        this.channel = channel;
    }

    public Long getId() {
        return id;
    }

    public String getContent() {
        return content;
    }

    public void setContent(String content) {
        this.content = content;
    }

    public String getMessageType() {
        return messageType;
    }

    public void setMessageType(String messageType) {
        this.messageType = messageType;
    }

    public String getImageData() {
        return imageData;
    }

    public void setImageData(String imageData) {
        this.imageData = imageData;
    }

    public LocalDateTime getTimestamp() {
        return timestamp;
    }

    public void setTimestamp(LocalDateTime timestamp) {
        this.timestamp = timestamp;
    }

    public User getSender() {
        return sender;
    }

    public void setSender(User sender) {
        this.sender = sender;
    }

    public Channel getChannel() {
        return channel;
    }

    public void setChannel(Channel channel) {
        this.channel = channel;
    }
}
