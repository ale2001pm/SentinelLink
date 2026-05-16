package com.sentinellink.websocket;

public enum MessageType {
    LOGIN_REQUEST,
    LOGIN_RESPONSE,
    CHANNEL_LIST,
    MESSAGE_HISTORY,
    JOIN_CHANNEL,
    SEND_MESSAGE,
    RECEIVE_MESSAGE,
    USER_LIST,
    SYSTEM_METRICS,
    SYSTEM_ALERT,
    AI_REQUEST,
    AI_RESPONSE,
    ERROR
}
