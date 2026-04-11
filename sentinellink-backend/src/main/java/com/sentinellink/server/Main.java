package com.sentinellink.server;

import com.sentinellink.service.DataBootstrapService;
import com.sentinellink.util.H2ConsoleServer;
import com.sentinellink.util.JpaUtil;
import com.sentinellink.websocket.WebSocketServer;

/**
 * Main entry point for SentinelLink Backend Server
 */
public class Main {

    public static void main(String[] args) {
        System.out.println("SentinelLink Backend - Starting...");

        WebSocketServer webSocketServer = new WebSocketServer();

        H2ConsoleServer.start();

        DataBootstrapService bootstrapService = new DataBootstrapService();
        bootstrapService.seedDefaults();

        if (H2ConsoleServer.isRunning()) {
            System.out.println("H2 console running at: " + H2ConsoleServer.getConsoleUrl());
        } else {
            System.out.println(H2ConsoleServer.getConsoleUrl());
        }
        System.out.println("Users in DB: " + bootstrapService.userCount());
        System.out.println("Channels in DB: " + bootstrapService.channelCount());

        webSocketServer.start();
        System.out.println("Backend is ready. Phase 3 - WebSocket and JSON protocol initialized.");

        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            webSocketServer.stop();
            H2ConsoleServer.stop();
            JpaUtil.shutdown();
        }));
    }

}
