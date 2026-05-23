package com.sentinellink.service;

import com.google.gson.JsonObject;
import com.sentinellink.websocket.MessageType;
import com.sentinellink.websocket.SocketMessage;
import com.sentinellink.websocket.WebSocketServer;
import java.io.File;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import oshi.SystemInfo;
import oshi.hardware.CentralProcessor;
import oshi.hardware.GlobalMemory;
import oshi.hardware.HardwareAbstractionLayer;

public class SystemMonitor {

    private static final Logger LOGGER = LoggerFactory.getLogger(SystemMonitor.class);
    private static volatile SocketMessage latestMetricsMessage;
    private static volatile SocketMessage latestAlertMessage;
    private static volatile SystemMonitor INSTANCE;

    private final MessageService messageService;
    private volatile double cpuThreshold;
    private volatile double ramThreshold;
    private volatile double diskThreshold;
    private final long intervalSeconds;

    private final SystemInfo systemInfo;
    private final HardwareAbstractionLayer hardware;
    private final CentralProcessor processor;
    private final GlobalMemory memory;
    private final ScheduledExecutorService scheduler;

    private long[] previousCpuTicks;
    private boolean cpuAlertActive;
    private boolean ramAlertActive;
    private boolean diskAlertActive;
    private boolean cpuWarningActive;
    private boolean ramWarningActive;
    private boolean diskWarningActive;

    public SystemMonitor(MessageService messageService,
                         double cpuThreshold,
                         double ramThreshold,
                         double diskThreshold,
                         long intervalSeconds) {
        this.messageService = messageService;
        this.cpuThreshold = cpuThreshold;
        this.ramThreshold = ramThreshold;
        this.diskThreshold = diskThreshold;
        this.intervalSeconds = intervalSeconds;
        this.systemInfo = new SystemInfo();
        this.hardware = systemInfo.getHardware();
        this.processor = hardware.getProcessor();
        this.memory = hardware.getMemory();
        this.scheduler = Executors.newSingleThreadScheduledExecutor(runnable -> {
            Thread thread = new Thread(runnable, "sentinellink-system-monitor");
            thread.setDaemon(true);
            return thread;
        });
        this.previousCpuTicks = processor.getSystemCpuLoadTicks();
        INSTANCE = this;
    }

    public static SystemMonitor getInstance() {
        return INSTANCE;
    }

    public void start() {
        scheduler.scheduleAtFixedRate(this::pollAndBroadcast, 0, intervalSeconds, TimeUnit.SECONDS);
        LOGGER.info("System monitor started: cpu>{} ram>{} disk>{} interval={}s",
                cpuThreshold, ramThreshold, diskThreshold, intervalSeconds);
    }

    public void stop() {
        scheduler.shutdownNow();
    }

    public void pollOnce() {
        pollAndBroadcast();
    }

    public synchronized void updateThresholds(double cpu, double ram, double disk) {
        this.cpuThreshold = Math.max(0, Math.min(100, cpu));
        this.ramThreshold = Math.max(0, Math.min(100, ram));
        this.diskThreshold = Math.max(0, Math.min(100, disk));
        cpuAlertActive = false;
        ramAlertActive = false;
        diskAlertActive = false;
        cpuWarningActive = false;
        ramWarningActive = false;
        diskWarningActive = false;
        LOGGER.info("Thresholds updated: cpu>{} ram>{} disk>{}", cpuThreshold, ramThreshold, diskThreshold);
    }

    public double getCpuThreshold() { return cpuThreshold; }
    public double getRamThreshold() { return ramThreshold; }
    public double getDiskThreshold() { return diskThreshold; }

    public static SocketMessage getLatestMetricsMessage() {
        return latestMetricsMessage;
    }

    public static SocketMessage getLatestAlertMessage() {
        return latestAlertMessage;
    }

    public SocketMessage buildTestAlertMessage() {
        JsonObject payload = messageService.createSystemAlert(
                "Notificacion de prueba — umbrales activos: CPU>" + cpuThreshold + "% RAM>" + ramThreshold + "% Disco>" + diskThreshold + "%",
                "warning",
                "test",
                0.0,
                0.0);
        payload.addProperty("isTest", true);
        return new SocketMessage(MessageType.SYSTEM_ALERT, payload);
    }

    private void pollAndBroadcast() {
        try {
            SystemMetricsSnapshot snapshot = collectSnapshot();
            SocketMessage metricsMessage = new SocketMessage(
                    MessageType.SYSTEM_METRICS,
                    messageService.createSystemMetricsPayload(
                            snapshot.cpuPercent,
                            snapshot.ramPercent,
                            snapshot.diskPercent,
                            snapshot.timestamp));
            latestMetricsMessage = metricsMessage;
            WebSocketServer.broadcast(metricsMessage);
            evaluateAndBroadcastAlerts(snapshot);
        } catch (Exception exception) {
            LOGGER.warn("System monitor tick failed: {}", exception.getMessage());
        }
    }

    private SystemMetricsSnapshot collectSnapshot() {
        double cpuLoad = processor.getSystemCpuLoadBetweenTicks(previousCpuTicks);
        previousCpuTicks = processor.getSystemCpuLoadTicks();
        double cpuPercent = Math.max(0.0, cpuLoad * 100.0);

        long totalMemory = memory.getTotal();
        long availableMemory = memory.getAvailable();
        double ramPercent = totalMemory <= 0 ? 0.0 : ((double) (totalMemory - availableMemory) / totalMemory) * 100.0;

        double diskPercent = collectDiskUsagePercent();
        return new SystemMetricsSnapshot(cpuPercent, ramPercent, diskPercent, System.currentTimeMillis());
    }

    private double collectDiskUsagePercent() {
        File[] roots = File.listRoots();
        if (roots == null || roots.length == 0) {
            return 0.0;
        }

        long totalBytes = 0L;
        long usedBytes = 0L;
        for (File root : roots) {
            long total = Math.max(0L, root.getTotalSpace());
            long free = Math.max(0L, root.getFreeSpace());
            totalBytes += total;
            usedBytes += Math.max(0L, total - free);
        }

        return totalBytes <= 0L ? 0.0 : ((double) usedBytes / (double) totalBytes) * 100.0;
    }

    private void evaluateAndBroadcastAlerts(SystemMetricsSnapshot snapshot) {
        checkThreshold("CPU",   snapshot.cpuPercent,  cpuThreshold,
                cpuAlertActive,   a -> cpuAlertActive = a,
                cpuWarningActive, w -> cpuWarningActive = w);
        checkThreshold("RAM",   snapshot.ramPercent,  ramThreshold,
                ramAlertActive,   a -> ramAlertActive = a,
                ramWarningActive, w -> ramWarningActive = w);
        checkThreshold("DISCO", snapshot.diskPercent, diskThreshold,
                diskAlertActive,  a -> diskAlertActive = a,
                diskWarningActive,w -> diskWarningActive = w);
    }

    private void checkThreshold(String metricName,
                                double currentValue,
                                double threshold,
                                boolean alertActive,
                                ThresholdFlagSetter alertSetter,
                                boolean warningActive,
                                ThresholdFlagSetter warningSetter) {
        double warnLevel = threshold * 0.80;

        if (currentValue >= threshold) {
            // Critical — send once when first crossed
            if (!alertActive) {
                alertSetter.set(true);
                warningSetter.set(true); // warning subsumed by critical
                SocketMessage msg = new SocketMessage(
                        MessageType.SYSTEM_ALERT,
                        messageService.createSystemAlert(
                                metricName + " por encima del umbral: " + String.format("%.1f", currentValue) + "%",
                                "critical",
                                metricName.toLowerCase(),
                                currentValue,
                                threshold));
                latestAlertMessage = msg;
                WebSocketServer.broadcast(msg);
                EmailService.sendThresholdAlert(metricName, currentValue, threshold);
            }
        } else if (currentValue >= warnLevel) {
            // Approaching — clear critical, send warning once
            if (alertActive) alertSetter.set(false);
            if (!warningActive) {
                warningSetter.set(true);
                SocketMessage msg = new SocketMessage(
                        MessageType.SYSTEM_ALERT,
                        messageService.createSystemAlert(
                                metricName + " aproximándose al umbral: " + String.format("%.1f", currentValue) + "%",
                                "warning",
                                metricName.toLowerCase(),
                                currentValue,
                                threshold));
                WebSocketServer.broadcast(msg);
            }
        } else {
            // Safe — send resolved once if any alert was active
            if (alertActive || warningActive) {
                alertSetter.set(false);
                warningSetter.set(false);
                SocketMessage msg = new SocketMessage(
                        MessageType.SYSTEM_ALERT,
                        messageService.createSystemAlert(
                                metricName + " volvió a niveles normales: " + String.format("%.1f", currentValue) + "%",
                                "resolved",
                                metricName.toLowerCase(),
                                currentValue,
                                threshold));
                WebSocketServer.broadcast(msg);
            }
        }
    }

    private static class SystemMetricsSnapshot {
        private final double cpuPercent;
        private final double ramPercent;
        private final double diskPercent;
        private final long timestamp;

        private SystemMetricsSnapshot(double cpuPercent, double ramPercent, double diskPercent, long timestamp) {
            this.cpuPercent = cpuPercent;
            this.ramPercent = ramPercent;
            this.diskPercent = diskPercent;
            this.timestamp = timestamp;
        }
    }

    private interface ThresholdFlagSetter {
        void set(boolean active);
    }
}
