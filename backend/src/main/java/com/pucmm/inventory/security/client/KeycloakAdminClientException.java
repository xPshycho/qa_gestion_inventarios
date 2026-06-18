package com.pucmm.inventory.security.client;

import org.springframework.web.client.RestClientResponseException;

public class KeycloakAdminClientException extends RuntimeException {
    public KeycloakAdminClientException(String message) {
        super(message);
    }

    static KeycloakAdminClientException from(RestClientResponseException exception) {
        return new KeycloakAdminClientException(
                "Keycloak admin request failed with status " + exception.getStatusCode().value()
        );
    }
}
