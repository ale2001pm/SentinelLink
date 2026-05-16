package com.sentinellink.server;

import com.sentinellink.service.DataBootstrapService;
import com.sentinellink.service.MessageService;
import com.sentinellink.service.SystemMonitor;
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

        DataBootstrapService bootstrapService = initializeDatabaseWithRetry();
        if (bootstrapService == null) {
            System.err.println("Failed to initialize database after retries");
            System.exit(1);
            return;
        }

        if (H2ConsoleServer.isRunning()) {
            System.out.println("H2 console running at: " + H2ConsoleServer.getConsoleUrl());
        } else {
            System.out.println(H2ConsoleServer.getConsoleUrl());
        }
        System.out.println("Users in DB: " + bootstrapService.userCount());
        System.out.println("Channels in DB: " + bootstrapService.channelCount());

        webSocketServer.start();
        MessageService messageService = new MessageService();
        SystemMonitor systemMonitor = new SystemMonitor(
                messageService,
                getDoubleProperty("sentinellink.monitor.cpuThreshold", 80.0),
                getDoubleProperty("sentinellink.monitor.ramThreshold", 90.0),
                getDoubleProperty("sentinellink.monitor.diskThreshold", 90.0),
                getLongProperty("sentinellink.monitor.intervalSeconds", 5L)
        );
        systemMonitor.start();
        systemMonitor.pollOnce();
        System.out.println("Backend is ready. Phase 6 - Monitorizacion del sistema habilitada.");

        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            systemMonitor.stop();
            webSocketServer.stop();
            H2ConsoleServer.stop();
            JpaUtil.shutdown();
        }));
    }

    private static DataBootstrapService initializeDatabaseWithRetry() {
        final int maxRetries = 3;
        final long retryDelayMs = 2000;

        for (int attempt = 1; attempt <= maxRetries; attempt++) {
            try {
                // Attempt to clean up locked H2 files before connection
                if (attempt == 1) {
                    cleanupH2LockFiles();
                }
                
                DataBootstrapService bootstrapService = new DataBootstrapService();
                bootstrapService.seedDefaults();
                System.out.println("Database initialized successfully on attempt " + attempt);
                return bootstrapService;
            } catch (Exception e) {
                if (attempt < maxRetries) {
                    System.err.println("Database connection failed (attempt " + attempt + "/" + maxRetries
                            + "): " + e.getMessage() + ". Retrying in " + (retryDelayMs / 1000) + "s...");
                    try {
                        Thread.sleep(retryDelayMs);
                    } catch (InterruptedException ie) {
                        Thread.currentThread().interrupt();
                        break;
                    }
                } else {
                    System.err.println("Database connection failed after " + maxRetries + " attempts");
                    e.printStackTrace();
                }
            }
        }
        return null;
    }

    private static void cleanupH2LockFiles() {
        try {
            java.io.File dataDir = new java.io.File("data");
            if (!dataDir.exists()) {
                return;
            }

            java.io.File[] files = dataDir.listFiles();
            if (files == null) {
                return;
            }

            boolean foundLock = false;
            for (java.io.File file : files) {
                String name = file.getName();
                // Delete H2 lock files, trace files, and main DB files if lock detected
                if (name.contains(".lock.db") || name.contains(".trace.db") || 
                    (name.startsWith("sentinellink_db") && (name.endsWith(".lock") || name.endsWith(".trace")))) {
                    if (file.delete()) {
                        System.out.println("Cleaned up H2 lock file: " + name);
                        foundLock = true;
                    }
                }
                // If we find .mv.db, also delete associated files on lock detection
                if (name.equals("sentinellink_db.mv.db")) {
                    foundLock = true;
                }
            }
            
            // If lock was detected, delete the main DB file to force recreation
            if (foundLock) {
                for (java.io.File file : files) {
                    if (file.getName().equals("sentinellink_db.mv.db")) {
                        if (file.delete()) {
                            System.out.println("Removed locked H2 database file: sentinellink_db.mv.db");
                        }
                    }
                }
            }
        } catch (Exception e) {
            // Silently ignore cleanup errors
            System.out.println("Note: Could not fully clean H2 lock files: " + e.getMessage());
        }
    }

    private static double getDoubleProperty(String key, double defaultValue) {
        String raw = System.getProperty(key);
        if (raw == null || raw.isBlank()) {
            return defaultValue;
        }
        try {
            return Double.parseDouble(raw);
        } catch (NumberFormatException ignored) {
            return defaultValue;
        }
    }

    private static long getLongProperty(String key, long defaultValue) {
        String raw = System.getProperty(key);
        if (raw == null || raw.isBlank()) {
            return defaultValue;
        }
        try {
            return Long.parseLong(raw);
        } catch (NumberFormatException ignored) {
            return defaultValue;
        }
    }

}
