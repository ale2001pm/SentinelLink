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
            return channels.isEmpty() ? Optional.empty() : Optional.of(channels.get(0));
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

    /** Returns only public (non-private) group channels. */
    public List<Channel> findAllPublicGroupChannels() {
        EntityManager em = JpaUtil.getEntityManager();
        try {
            return em.createQuery(
                    "SELECT c FROM Channel c WHERE (c.channelType IS NULL OR c.channelType = 'GROUP') AND c.isPrivate = false ORDER BY c.id",
                    Channel.class).getResultList();
        } finally {
            em.close();
        }
    }

    /** Returns public group channels + DM channels where username is a participant (excludes private groups). */
    public List<Channel> findPublicChannelsForUser(String username) {
        EntityManager em = JpaUtil.getEntityManager();
        try {
            return em.createQuery(
                    "SELECT c FROM Channel c WHERE " +
                    "((c.channelType IS NULL OR c.channelType = 'GROUP') AND c.isPrivate = false) OR " +
                    "(c.channelType = 'DM' AND (c.dmParticipant1 = :username OR c.dmParticipant2 = :username)) " +
                    "ORDER BY c.id",
                    Channel.class)
                    .setParameter("username", username)
                    .getResultList();
        } finally {
            em.close();
        }
    }

    /** Finds a channel by exact name (used for private channel search). */
    public Optional<Channel> findByNameIgnoreCase(String name) {
        EntityManager em = JpaUtil.getEntityManager();
        try {
            List<Channel> results = em.createQuery(
                    "SELECT c FROM Channel c WHERE LOWER(c.name) = LOWER(:name)", Channel.class)
                    .setParameter("name", name)
                    .setMaxResults(1)
                    .getResultList();
            return results.isEmpty() ? Optional.empty() : Optional.of(results.get(0));
        } finally {
            em.close();
        }
    }

    /** Returns only group channels (excludes DMs). */
    public List<Channel> findAllGroupChannels() {
        EntityManager em = JpaUtil.getEntityManager();
        try {
            return em.createQuery(
                    "SELECT c FROM Channel c WHERE c.channelType IS NULL OR c.channelType = 'GROUP' ORDER BY c.id",
                    Channel.class).getResultList();
        } finally {
            em.close();
        }
    }

    /** Returns group channels + DM channels where username is a participant. */
    public List<Channel> findChannelsForUser(String username) {
        EntityManager em = JpaUtil.getEntityManager();
        try {
            return em.createQuery(
                    "SELECT c FROM Channel c WHERE " +
                    "(c.channelType IS NULL OR c.channelType = 'GROUP') OR " +
                    "(c.channelType = 'DM' AND (c.dmParticipant1 = :username OR c.dmParticipant2 = :username)) " +
                    "ORDER BY c.id",
                    Channel.class)
                    .setParameter("username", username)
                    .getResultList();
        } finally {
            em.close();
        }
    }

    /** Finds an existing DM channel between two users (order-independent). */
    public Optional<Channel> findDmBetween(String user1, String user2) {
        EntityManager em = JpaUtil.getEntityManager();
        try {
            List<Channel> results = em.createQuery(
                    "SELECT c FROM Channel c WHERE c.channelType = 'DM' AND " +
                    "((c.dmParticipant1 = :u1 AND c.dmParticipant2 = :u2) OR " +
                    " (c.dmParticipant1 = :u2 AND c.dmParticipant2 = :u1))",
                    Channel.class)
                    .setParameter("u1", user1)
                    .setParameter("u2", user2)
                    .setMaxResults(1)
                    .getResultList();
            return results.isEmpty() ? Optional.empty() : Optional.of(results.get(0));
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
