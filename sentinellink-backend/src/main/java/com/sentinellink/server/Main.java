package com.sentinellink.server;

import com.sentinellink.service.DataBootstrapService;
import com.sentinellink.util.H2ConsoleServer;
import com.sentinellink.util.JpaUtil;

/**
 * Main entry point for SentinelLink Backend Server
 */
public class Main {

    public static void main(String[] args) {
        System.out.println("SentinelLink Backend - Starting...");

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
        System.out.println("Backend is ready. Phase 2 - Database and models initialized.");

        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            H2ConsoleServer.stop();
            JpaUtil.shutdown();
        }));
    }

}
