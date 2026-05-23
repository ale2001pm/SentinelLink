package com.sentinellink.service;

import java.io.InputStream;
import java.util.Properties;
import jakarta.mail.Authenticator;
import jakarta.mail.Message;
import jakarta.mail.MessagingException;
import jakarta.mail.PasswordAuthentication;
import jakarta.mail.Session;
import jakarta.mail.Transport;
import jakarta.mail.internet.InternetAddress;
import jakarta.mail.internet.MimeMessage;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class EmailService {

    private static final Logger LOGGER = LoggerFactory.getLogger(EmailService.class);

    private static final String SMTP_HOST;
    private static final String SMTP_PORT;
    private static final String FROM_ADDRESS;
    private static final String FROM_PASSWORD;
    private static final String TO_ADDRESS;

    static {
        Properties file = new Properties();
        try (InputStream in = EmailService.class.getClassLoader()
                .getResourceAsStream("email.properties")) {
            if (in != null) {
                file.load(in);
            }
        } catch (Exception e) {
            LOGGER.warn("Could not load email.properties: {}", e.getMessage());
        }
        SMTP_HOST     = resolve(file, "sentinellink.email.host",     "smtp.gmail.com");
        SMTP_PORT     = resolve(file, "sentinellink.email.port",     "587");
        FROM_ADDRESS  = resolve(file, "sentinellink.email.from",     "");
        FROM_PASSWORD = resolve(file, "sentinellink.email.password", "");
        TO_ADDRESS    = resolve(file, "sentinellink.email.to",       "");
    }

    private static String resolve(Properties file, String key, String defaultValue) {
        String sys = System.getProperty(key);
        if (sys != null && !sys.isBlank()) return sys;
        String prop = file.getProperty(key);
        if (prop != null && !prop.isBlank()) return prop;
        return defaultValue;
    }

    private EmailService() {}

    public static void sendThresholdAlert(String metric, double value, double threshold) {
        String subject = "[SentinelLink] ⚠️ Alerta crítica: " + metric + " por encima del umbral";
        String body = buildHtml(
                "⚠️ Alerta crítica del sistema",
                "El recurso <strong>" + metric + "</strong> ha superado el umbral configurado.",
                new String[][]{
                    {"Recurso",      metric},
                    {"Valor actual", String.format("%.1f%%", value)},
                    {"Umbral",       String.format("%.1f%%", threshold)},
                    {"Severidad",    "CRITICA"}
                },
                "Por favor, revise el estado del servidor lo antes posible."
        );
        sendHtml(subject, body);
    }

    public static void sendTestAlert(double cpuThreshold, double ramThreshold, double diskThreshold) {
        String subject = "[SentinelLink] ✅ Correo de prueba";
        String body = buildHtml(
                "✅ Correo de prueba",
                "Este correo confirma que las notificaciones por email están configuradas correctamente.",
                new String[][]{
                    {"CPU   umbral", String.format("%.1f%%", cpuThreshold)},
                    {"RAM   umbral", String.format("%.1f%%", ramThreshold)},
                    {"Disco umbral", String.format("%.1f%%", diskThreshold)}
                },
                "Si recibes este mensaje, el sistema de alertas funciona correctamente."
        );
        sendHtml(subject, body);
    }

    private static String buildHtml(String title, String intro, String[][] rows, String footer) {
        StringBuilder sb = new StringBuilder();
        sb.append("<!DOCTYPE html><html><head><meta charset='UTF-8'></head><body style='margin:0;padding:0;background:#f4f4f5;font-family:Arial,sans-serif;'>");
        sb.append("<table width='100%' cellpadding='0' cellspacing='0' style='background:#f4f4f5;padding:32px 0;'><tr><td align='center'>");
        sb.append("<table width='580' cellpadding='0' cellspacing='0' style='background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,.08);'>");
        // Banner
        sb.append("<tr><td style='background:#e8501a;padding:28px 32px;text-align:center;'>");
        sb.append("<span style='font-size:28px;font-weight:900;color:#ffffff;letter-spacing:-1px;'>&#128970; SentinelLink</span>");
        sb.append("<p style='color:rgba(255,255,255,.85);margin:6px 0 0;font-size:13px;'>Sistema de monitorización y comunicación empresarial</p>");
        sb.append("</td></tr>");
        // Title
        sb.append("<tr><td style='padding:28px 32px 12px;'>");
        sb.append("<h2 style='margin:0;color:#18181b;font-size:20px;'>").append(title).append("</h2>");
        sb.append("<p style='margin:10px 0 0;color:#52525b;font-size:14px;line-height:1.6;'>").append(intro).append("</p>");
        sb.append("</td></tr>");
        // Data table
        sb.append("<tr><td style='padding:8px 32px 20px;'>");
        sb.append("<table width='100%' cellpadding='0' cellspacing='0' style='border-collapse:collapse;border-radius:8px;overflow:hidden;border:1px solid #e4e4e7;'>");
        boolean alt = false;
        for (String[] row : rows) {
            String bg = alt ? "#fafafa" : "#ffffff";
            sb.append("<tr style='background:").append(bg).append(";'>");
            sb.append("<td style='padding:10px 16px;color:#71717a;font-size:13px;width:40%;border-bottom:1px solid #f4f4f5;'>").append(row[0]).append("</td>");
            sb.append("<td style='padding:10px 16px;color:#18181b;font-size:13px;font-weight:600;border-bottom:1px solid #f4f4f5;'>").append(row[1]).append("</td>");
            sb.append("</tr>");
            alt = !alt;
        }
        sb.append("</table></td></tr>");
        // Footer note
        sb.append("<tr><td style='padding:0 32px 28px;'>");
        sb.append("<p style='margin:0;color:#71717a;font-size:13px;line-height:1.6;border-left:3px solid #e8501a;padding-left:12px;'>").append(footer).append("</p>");
        sb.append("</td></tr>");
        // Bottom bar
        sb.append("<tr><td style='background:#f4f4f5;padding:16px 32px;text-align:center;border-top:1px solid #e4e4e7;'>");
        sb.append("<p style='margin:0;color:#a1a1aa;font-size:11px;'>SentinelLink &mdash; Notificación automática &mdash; No responder a este correo</p>");
        sb.append("</td></tr>");
        sb.append("</table></td></tr></table></body></html>");
        return sb.toString();
    }

    private static void sendHtml(String subject, String body) {
        if (FROM_ADDRESS.isBlank() || TO_ADDRESS.isBlank() || FROM_PASSWORD.isBlank()) {
            LOGGER.warn("Email not configured — skipping send. Set sentinellink.email.from/to/password JVM properties.");
            return;
        }

        Thread thread = new Thread(() -> {
            Properties props = new Properties();
            props.put("mail.smtp.auth",              "true");
            props.put("mail.smtp.starttls.enable",   "true");
            props.put("mail.smtp.host",              SMTP_HOST);
            props.put("mail.smtp.port",              SMTP_PORT);
            props.put("mail.smtp.connectiontimeout", "10000");
            props.put("mail.smtp.timeout",           "10000");

            Session session = Session.getInstance(props, new Authenticator() {
                @Override
                protected PasswordAuthentication getPasswordAuthentication() {
                    return new PasswordAuthentication(FROM_ADDRESS, FROM_PASSWORD);
                }
            });

            try {
                MimeMessage msg = new MimeMessage(session);
                msg.setFrom(new InternetAddress(FROM_ADDRESS));
                msg.setRecipients(Message.RecipientType.TO, InternetAddress.parse(TO_ADDRESS));
                msg.setSubject(subject, "UTF-8");
                msg.setContent(body, "text/html; charset=UTF-8");
                Transport.send(msg);
                LOGGER.info("Email sent to {} — subject: {}", TO_ADDRESS, subject);
            } catch (MessagingException e) {
                LOGGER.error("Failed to send email: {}", e.getMessage());
            }
        }, "sentinellink-email-sender");
        thread.setDaemon(true);
        thread.start();
    }
}
