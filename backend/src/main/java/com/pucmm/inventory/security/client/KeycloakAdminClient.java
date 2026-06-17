package com.pucmm.inventory.security.client;

import com.pucmm.inventory.security.api.dto.SecurityUserRequest;
import java.net.URI;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;

@Component
public class KeycloakAdminClient {
    private static final int USER_LIST_LIMIT = 1000;
    @SuppressWarnings("java:S1075")
    private static final String USER_REALM_ROLES_PATH = "/admin/realms/{realm}/users/{userId}/role-mappings/realm";

    private final RestClient restClient;
    private final String adminUrl;
    private final String realm;
    private final String clientId;
    private final String clientSecret;

    public KeycloakAdminClient(
            RestClient.Builder restClientBuilder,
            @Value("${inventory.keycloak.admin-url}") String adminUrl,
            @Value("${inventory.keycloak.admin-realm}") String realm,
            @Value("${inventory.keycloak.admin-client-id}") String clientId,
            @Value("${inventory.keycloak.admin-client-secret}") String clientSecret
    ) {
        this.restClient = restClientBuilder.build();
        this.adminUrl = trimTrailingSlash(adminUrl);
        this.realm = realm;
        this.clientId = clientId;
        this.clientSecret = clientSecret;
    }

    public List<KeycloakUser> listUsers() {
        KeycloakUser[] users = get("/admin/realms/{realm}/users?max={max}", KeycloakUser[].class, realm, USER_LIST_LIMIT);
        return users == null ? List.of() : Arrays.asList(users);
    }

    public KeycloakUser getUser(String userId) {
        return get("/admin/realms/{realm}/users/{userId}", KeycloakUser.class, realm, userId);
    }

    public KeycloakUser createUser(SecurityUserRequest request) {
        URI location = postForLocation("/admin/realms/{realm}/users", toUserPayload(request), realm);
        if (location != null) {
            String id = location.getPath().substring(location.getPath().lastIndexOf('/') + 1);
            return getUser(id);
        }

        return findUserByUsername(request.username());
    }

    public KeycloakUser updateUser(String userId, SecurityUserRequest request) {
        put("/admin/realms/{realm}/users/{userId}", toUserPayload(request), realm, userId);
        return getUser(userId);
    }

    public List<KeycloakRole> listUserRealmRoles(String userId) {
        KeycloakRole[] roles = get(USER_REALM_ROLES_PATH, KeycloakRole[].class, realm, userId);
        return roles == null ? List.of() : Arrays.asList(roles);
    }

    public KeycloakRole getRealmRole(String roleCode) {
        return get("/admin/realms/{realm}/roles/{roleCode}", KeycloakRole.class, realm, roleCode);
    }

    public void replaceUserRealmRoles(String userId, List<KeycloakRole> currentRoles, List<KeycloakRole> targetRoles) {
        if (!currentRoles.isEmpty()) {
            delete(USER_REALM_ROLES_PATH, currentRoles, realm, userId);
        }

        if (!targetRoles.isEmpty()) {
            post(USER_REALM_ROLES_PATH, targetRoles, realm, userId);
        }
    }

    private KeycloakUser findUserByUsername(String username) {
        KeycloakUser[] users = get(
                "/admin/realms/{realm}/users?username={username}&exact=true&max=1",
                KeycloakUser[].class,
                realm,
                username
        );
        if (users == null || users.length == 0) {
            throw new KeycloakAdminClientException("Keycloak user was created but could not be reloaded");
        }

        return users[0];
    }

    private Map<String, Object> toUserPayload(SecurityUserRequest request) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("username", request.username().trim());
        payload.put("firstName", request.firstName().trim());
        payload.put("lastName", request.lastName().trim());
        payload.put("enabled", request.enabled() == null || request.enabled());
        if (request.email() != null && !request.email().isBlank()) {
            payload.put("email", request.email().trim());
            payload.put("emailVerified", true);
        }
        return payload;
    }

    private <T> T get(String path, Class<T> responseType, Object... uriVariables) {
        try {
            return restClient.get()
                    .uri(adminUrl + path, uriVariables)
                    .header(HttpHeaders.AUTHORIZATION, bearer())
                    .retrieve()
                    .body(responseType);
        } catch (RestClientResponseException exception) {
            throw KeycloakAdminClientException.from(exception);
        }
    }

    private URI postForLocation(String path, Object body, Object... uriVariables) {
        try {
            return restClient.post()
                    .uri(adminUrl + path, uriVariables)
                    .header(HttpHeaders.AUTHORIZATION, bearer())
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(body)
                    .retrieve()
                    .toBodilessEntity()
                    .getHeaders()
                    .getLocation();
        } catch (RestClientResponseException exception) {
            throw KeycloakAdminClientException.from(exception);
        }
    }

    private void post(String path, Object body, Object... uriVariables) {
        try {
            restClient.post()
                    .uri(adminUrl + path, uriVariables)
                    .header(HttpHeaders.AUTHORIZATION, bearer())
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(body)
                    .retrieve()
                    .toBodilessEntity();
        } catch (RestClientResponseException exception) {
            throw KeycloakAdminClientException.from(exception);
        }
    }

    private void put(String path, Object body, Object... uriVariables) {
        try {
            restClient.put()
                    .uri(adminUrl + path, uriVariables)
                    .header(HttpHeaders.AUTHORIZATION, bearer())
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(body)
                    .retrieve()
                    .toBodilessEntity();
        } catch (RestClientResponseException exception) {
            throw KeycloakAdminClientException.from(exception);
        }
    }

    private void delete(String path, Object body, Object... uriVariables) {
        try {
            restClient.method(org.springframework.http.HttpMethod.DELETE)
                    .uri(adminUrl + path, uriVariables)
                    .header(HttpHeaders.AUTHORIZATION, bearer())
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(body)
                    .retrieve()
                    .toBodilessEntity();
        } catch (RestClientResponseException exception) {
            throw KeycloakAdminClientException.from(exception);
        }
    }

    private String bearer() {
        return "Bearer " + fetchAccessToken();
    }

    private String fetchAccessToken() {
        MultiValueMap<String, String> body = new LinkedMultiValueMap<>();
        body.add("grant_type", "client_credentials");
        body.add("client_id", clientId);
        body.add("client_secret", clientSecret);

        try {
            TokenResponse response = restClient.post()
                    .uri(adminUrl + "/realms/{realm}/protocol/openid-connect/token", realm)
                    .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                    .body(body)
                    .retrieve()
                    .body(TokenResponse.class);

            if (response == null || response.accessToken() == null || response.accessToken().isBlank()) {
                throw new KeycloakAdminClientException("Keycloak admin token response did not include an access token");
            }

            return response.accessToken();
        } catch (RestClientResponseException exception) {
            throw KeycloakAdminClientException.from(exception);
        }
    }

    private String trimTrailingSlash(String value) {
        return value.endsWith("/") ? value.substring(0, value.length() - 1) : value;
    }
}
