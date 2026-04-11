package com.sentinellink.repository;

import com.sentinellink.model.Channel;
import com.sentinellink.util.JpaUtil;
import java.util.List;
import java.util.Optional;
import javax.persistence.EntityManager;

public class ChannelRepository {

    public Channel save(Channel channel) {
        EntityManager em = JpaUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            Channel managed;
            if (channel.getId() == null) {
                em.persist(channel);
                managed = channel;
            } else {
                managed = em.merge(channel);
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

    public Optional<Channel> findById(Long id) {
        EntityManager em = JpaUtil.getEntityManager();
        try {
            return Optional.ofNullable(em.find(Channel.class, id));
        } finally {
            em.close();
        }
    }

    public Optional<Channel> findByName(String name) {
        EntityManager em = JpaUtil.getEntityManager();
        try {
            List<Channel> channels = em.createQuery(
                            "SELECT c FROM Channel c WHERE c.name = :name", Channel.class)
                    .setParameter("name", name)
                    .setMaxResults(1)
                    .getResultList();
            if (channels.isEmpty()) {
                return Optional.empty();
            }
            return Optional.of(channels.get(0));
        } finally {
            em.close();
        }
    }

    public List<Channel> findAll() {
        EntityManager em = JpaUtil.getEntityManager();
        try {
            return em.createQuery("SELECT c FROM Channel c ORDER BY c.id", Channel.class).getResultList();
        } finally {
            em.close();
        }
    }

    public void deleteById(Long id) {
        EntityManager em = JpaUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            Channel channel = em.find(Channel.class, id);
            if (channel != null) {
                em.remove(channel);
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
