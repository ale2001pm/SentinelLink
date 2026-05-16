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

    private final MessageService messageService;
    private final double cpuThreshold;
    private final double ramThreshold;
    private final double diskThreshold;
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

    public static SocketMessage getLatestMetricsMessage() {
        return latestMetricsMessage;
    }

    public static SocketMessage getLatestAlertMessage() {
        return latestAlertMessage;
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

        if (totalBytes <= 0L) {
            return 0.0;
        }
        return ((double) usedBytes / (double) totalBytes) * 100.0;
    }

    private void evaluateAndBroadcastAlerts(SystemMetricsSnapshot snapshot) {
        checkThreshold("CPU", snapshot.cpuPercent, cpuThreshold, cpuAlertActive, active -> cpuAlertActive = active);
        checkThreshold("RAM", snapshot.ramPercent, ramThreshold, ramAlertActive, active -> ramAlertActive = active);
        checkThreshold("DISCO", snapshot.diskPercent, diskThreshold, diskAlertActive, active -> diskAlertActive = active);
    }

    private void checkThreshold(String metricName,
                                double currentValue,
                                double threshold,
                                boolean active,
                                ThresholdFlagSetter setter) {
        if (currentValue >= threshold) {
            if (!active) {
                setter.set(true);
                SocketMessage alertMessage = new SocketMessage(
                        MessageType.SYSTEM_ALERT,
                        messageService.createSystemAlert(
                                metricName + " por encima del umbral: " + String.format("%.1f", currentValue) + "%",
                                "warning",
                                metricName.toLowerCase(),
                                currentValue,
                                threshold));
                latestAlertMessage = alertMessage;
                WebSocketServer.broadcast(alertMessage);
            }
        } else if (active) {
            setter.set(false);
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
