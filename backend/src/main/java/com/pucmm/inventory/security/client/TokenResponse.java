package com.pucmm.inventory.security.client;

import com.fasterxml.jackson.annotation.JsonProperty;

record TokenResponse(
        @JsonProperty("access_token")
        String accessToken
) {
}
