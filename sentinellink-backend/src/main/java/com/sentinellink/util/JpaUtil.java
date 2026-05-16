package com.sentinellink.util;

import javax.persistence.EntityManager;
import javax.persistence.EntityManagerFactory;
import javax.persistence.Persistence;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public final class JpaUtil {

    private static final Logger LOGGER = LoggerFactory.getLogger(JpaUtil.class);
    private static EntityManagerFactory ENTITY_MANAGER_FACTORY;

    static {
        try {
            ENTITY_MANAGER_FACTORY = Persistence.createEntityManagerFactory("SentinelLinkPU");
        } catch (Exception e) {
            LOGGER.error("Failed to initialize EntityManagerFactory", e);
            throw new ExceptionInInitializerError(e);
        }
    }

    private JpaUtil() {
    }

    public static EntityManager getEntityManager() {
        if (ENTITY_MANAGER_FACTORY == null || !ENTITY_MANAGER_FACTORY.isOpen()) {
            ENTITY_MANAGER_FACTORY = Persistence.createEntityManagerFactory("SentinelLinkPU");
        }
        return ENTITY_MANAGER_FACTORY.createEntityManager();
    }

    public static void shutdown() {
        if (ENTITY_MANAGER_FACTORY != null && ENTITY_MANAGER_FACTORY.isOpen()) {
            try {
                ENTITY_MANAGER_FACTORY.close();
                LOGGER.info("JPA EntityManagerFactory closed successfully");
            } catch (Exception e) {
                LOGGER.warn("Error closing EntityManagerFactory", e);
            }
        }
    }
}
