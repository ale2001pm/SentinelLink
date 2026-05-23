package com.sentinellink.service;

import com.sentinellink.model.Channel;
import com.sentinellink.model.User;
import com.sentinellink.model.UserRole;
import com.sentinellink.repository.ChannelRepository;
import com.sentinellink.repository.UserRepository;
import org.mindrot.jbcrypt.BCrypt;

public class DataBootstrapService {

    private final UserRepository userRepository;
    private final ChannelRepository channelRepository;

    public DataBootstrapService() {
        this.userRepository = new UserRepository();
        this.channelRepository = new ChannelRepository();
    }

    public void seedDefaults() {
        ensureDefaultChannel();
        ensureDefaultAdmin();
        ensureDefaultUser();
    }

    private void ensureDefaultChannel() {
        channelRepository.findByName("general").orElseGet(() -> {
            Channel general = new Channel("general", false);
            return channelRepository.save(general);
        });
    }

    private void ensureDefaultAdmin() {
        userRepository.findByUsername("admin").orElseGet(() -> {
            User admin = new User("admin", BCrypt.hashpw("admin123", BCrypt.gensalt()), UserRole.ADMIN, false);
            return userRepository.save(admin);
        });
    }

    private void ensureDefaultUser() {
        userRepository.findByUsername("user").orElseGet(() -> {
            User user = new User("user", BCrypt.hashpw("user123", BCrypt.gensalt()), UserRole.USER, false);
            return userRepository.save(user);
        });
    }

    public long userCount() {
        return userRepository.findAll().size();
    }

    public long channelCount() {
        return channelRepository.findAll().size();
    }
}
