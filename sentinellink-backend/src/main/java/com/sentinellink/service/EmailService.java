package com.sentinellink.service;

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

    private static final String SMTP_HOST     = System.getProperty("sentinellink.email.host",     "smtp.gmail.com");
    private static final String SMTP_PORT     = System.getProperty("sentinellink.email.port",     "587");
    private static final String FROM_ADDRESS  = System.getProperty("sentinellink.email.from",     "");
    private static final String FROM_PASSWORD = System.getProperty("sentinellink.email.password", "");
    private static final String TO_ADDRESS    = System.getProperty("sentinellink.email.to",       "");

    private EmailService() {}

    public static void sendThresholdAlert(String metric, double value, double threshold) {
        String subject = "[SentinelLink] Alerta: " + metric + " por encima del umbral";
        String body = String.format(
                "SentinelLink ha detectado que el recurso %s ha superado el umbral configurado.\n\n" +
                "Valor actual : %.1f%%\n" +
                "Umbral       : %.1f%%\n\n" +
                "Por favor, revise el estado del servidor.",
                metric, value, threshold);
        send(subject, body);
    }

    public static void sendTestAlert(double cpuThreshold, double ramThreshold, double diskThreshold) {
        String subject = "[SentinelLink] Correo de prueba";
        String body = String.format(
                "Este es un correo de prueba de SentinelLink.\n\n" +
                "Los umbrales configurados actualmente son:\n" +
                "  CPU   : %.1f%%\n" +
                "  RAM   : %.1f%%\n" +
                "  Disco : %.1f%%\n\n" +
                "Si recibes este mensaje, la configuracion de correo es correcta.",
                cpuThreshold, ramThreshold, diskThreshold);
        send(subject, body);
    }

    private static void send(String subject, String body) {
        if (FROM_ADDRESS.isBlank() || TO_ADDRESS.isBlank() || FROM_PASSWORD.isBlank()) {
            LOGGER.warn("Email not configured — skipping send. Set sentinellink.email.from/to/password JVM properties.");
            return;
        }

        Properties props = new Properties();
        props.put("mail.smtp.auth",            "true");
        props.put("mail.smtp.starttls.enable", "true");
        props.put("mail.smtp.host",            SMTP_HOST);
        props.put("mail.smtp.port",            SMTP_PORT);

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
            msg.setText(body, "UTF-8");
            Transport.send(msg);
            LOGGER.info("Email sent to {} — subject: {}", TO_ADDRESS, subject);
        } catch (MessagingException e) {
            LOGGER.error("Failed to send email: {}", e.getMessage());
        }
    }
}
