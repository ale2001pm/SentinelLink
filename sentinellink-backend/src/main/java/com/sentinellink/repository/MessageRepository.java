package com.sentinellink.repository;

import com.sentinellink.model.Message;
import com.sentinellink.util.JpaUtil;
import java.util.List;
import java.util.Optional;
import javax.persistence.EntityManager;

public class MessageRepository {

    public Message save(Message message) {
        EntityManager em = JpaUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            Message managed;
            if (message.getId() == null) {
                em.persist(message);
                managed = message;
            } else {
                managed = em.merge(message);
            }
            em.getTransaction().commit();
            return managed;
        } catch (Exception e) {
            if (em.getTransaction().isActive()) {
                em.getTransaction().rollback();
            }
            throw e;
        } finally {
            em.close();
        }
    }

    public Optional<Message> findById(Long id) {
        EntityManager em = JpaUtil.getEntityManager();
        try {
            return Optional.ofNullable(em.find(Message.class, id));
        } finally {
            em.close();
        }
    }

    public List<Message> findAll() {
        EntityManager em = JpaUtil.getEntityManager();
        try {
            return em.createQuery("SELECT m FROM Message m ORDER BY m.timestamp", Message.class)
                    .getResultList();
        } finally {
            em.close();
        }
    }

    public List<Message> findByChannelId(Long channelId) {
        EntityManager em = JpaUtil.getEntityManager();
        try {
            return em.createQuery(
                            "SELECT m FROM Message m WHERE m.channel.id = :channelId ORDER BY m.timestamp",
                            Message.class)
                    .setParameter("channelId", channelId)
                    .getResultList();
        } finally {
            em.close();
        }
    }

    public void deleteById(Long id) {
        EntityManager em = JpaUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            Message message = em.find(Message.class, id);
            if (message != null) {
                em.remove(message);
            }
            em.getTransaction().commit();
        } catch (Exception e) {
            if (em.getTransaction().isActive()) {
                em.getTransaction().rollback();
            }
            throw e;
        } finally {
            em.close();
        }
    }
}
