package com.sentinellink.service;

import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import java.util.Collection;

public class UserPresenceService {

    public JsonObject buildUserList(Collection<String> usernames) {
        JsonArray usersArray = new JsonArray();
        for (String username : usernames) {
            usersArray.add(username);
        }

        JsonObject response = new JsonObject();
        response.add("users", usersArray);
        return response;
    }
}
