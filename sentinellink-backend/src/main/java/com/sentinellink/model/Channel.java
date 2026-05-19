package com.sentinellink.model;

import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.GeneratedValue;
import javax.persistence.GenerationType;
import javax.persistence.Id;
import javax.persistence.Table;

@Entity
@Table(name = "app_channel")
public class Channel {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 100)
    private String name;

    @Column(nullable = false)
    private boolean isPrivate;

    /** "GROUP" or null = group channel; "DM" = direct message */
    @Column(name = "channel_type", nullable = true, length = 20)
    private String channelType;

    @Column(name = "dm_participant1", nullable = true, length = 100)
    private String dmParticipant1;

    @Column(name = "dm_participant2", nullable = true, length = 100)
    private String dmParticipant2;

    public Channel() {
    }

    public Channel(String name, boolean isPrivate) {
        this.name = name;
        this.isPrivate = isPrivate;
        this.channelType = "GROUP";
    }

    public Channel(String name, String participant1, String participant2) {
        this.name = name;
        this.isPrivate = true;
        this.channelType = "DM";
        this.dmParticipant1 = participant1;
        this.dmParticipant2 = participant2;
    }

    public Long getId() {
        return id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public boolean isPrivate() {
        return isPrivate;
    }

    public void setPrivate(boolean aPrivate) {
        isPrivate = aPrivate;
    }

    public String getChannelType() {
        return channelType;
    }

    public void setChannelType(String channelType) {
        this.channelType = channelType;
    }

    public String getDmParticipant1() {
        return dmParticipant1;
    }

    public void setDmParticipant1(String dmParticipant1) {
        this.dmParticipant1 = dmParticipant1;
    }

    public String getDmParticipant2() {
        return dmParticipant2;
    }

    public void setDmParticipant2(String dmParticipant2) {
        this.dmParticipant2 = dmParticipant2;
    }

    public boolean isDm() {
        return "DM".equals(channelType);
    }

    public boolean isGroup() {
        return !isDm();
    }
}
