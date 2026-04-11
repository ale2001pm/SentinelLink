package com.sentinellink.websocket;

import jakarta.websocket.OnClose;
import jakarta.websocket.OnError;
import jakarta.websocket.OnMessage;
import jakarta.websocket.OnOpen;
import jakarta.websocket.Session;
import jakarta.websocket.server.ServerEndpoint;

@ServerEndpoint(value = "/ws")
public class ChatWebSocketEndpoint {

    @OnOpen
    public void onOpen(Session session) {
        WebSocketServer.onOpen(session);
    }

    @OnMessage
    public void onMessage(String message, Session session) {
        WebSocketServer.onMessage(session, message);
    }

    @OnClose
    public void onClose(Session session) {
        WebSocketServer.onClose(session);
    }

    @OnError
    public void onError(Session session, Throwable throwable) {
        WebSocketServer.onError(session, throwable);
    }
}
