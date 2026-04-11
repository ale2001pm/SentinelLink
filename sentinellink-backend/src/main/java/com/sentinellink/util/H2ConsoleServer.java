package com.sentinellink.util;

import java.sql.SQLException;
import org.h2.tools.Server;

public final class H2ConsoleServer {

    private static Server webServer;
    private static boolean running;
    private static String statusMessage = "H2 console not started";

    private H2ConsoleServer() {
    }

    public static void start() {
        try {
            if (webServer == null || !webServer.isRunning(false)) {
                webServer = Server.createWebServer("-web", "-webAllowOthers", "-webPort", "8082").start();
            }
            running = true;
            statusMessage = webServer.getURL();
        } catch (SQLException e) {
            try {
                webServer = Server.createWebServer("-web", "-webAllowOthers", "-webPort", "0").start();
                running = true;
                statusMessage = webServer.getURL() + " (fallback dynamic port)";
            } catch (SQLException fallbackException) {
                running = false;
                statusMessage = "H2 console unavailable (port 8082 in use): " + e.getMessage();
            }
        }
    }

    public static void stop() {
        if (webServer != null) {
            webServer.stop();
        }
        running = false;
    }

    public static String getConsoleUrl() {
        return statusMessage;
    }

    public static boolean isRunning() {
        return running;
    }
}
