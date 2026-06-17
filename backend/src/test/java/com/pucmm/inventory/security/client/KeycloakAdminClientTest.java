package com.pucmm.inventory.security.client;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.method;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withStatus;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

import com.pucmm.inventory.security.api.dto.SecurityUserRequest;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;

class KeycloakAdminClientTest {
    private static final String BASE_URL = "http://keycloak:8080";
    private static final String TOKEN_URL = BASE_URL + "/realms/inventory/protocol/openid-connect/token";
    private static final String TOKEN_JSON = "{\"access_token\":\"test-token\"}";
    private static final String USER_JSON =
            "{\"id\":\"u1\",\"username\":\"carlos\",\"firstName\":\"Carlos\",\"lastName\":\"Hernandez\",\"email\":\"carlos@test.local\",\"enabled\":true}";
    private static final String ROLE_JSON =
            "{\"id\":\"r1\",\"name\":\"INVENTORY_ADMIN\",\"description\":\"Admin\",\"composite\":false,\"clientRole\":false,\"containerId\":\"inventory\"}";

    private MockRestServiceServer mockServer;
    private KeycloakAdminClient client;

    @BeforeEach
    void setUp() {
        RestClient.Builder builder = RestClient.builder();
        mockServer = MockRestServiceServer.bindTo(builder).build();
        client = new KeycloakAdminClient(builder, BASE_URL, "inventory", "admin-service", "secret");
    }

    @Test
    void listUsersReturnsAllUsers() {
        expectToken();
        mockServer.expect(requestTo(BASE_URL + "/admin/realms/inventory/users?max=1000"))
                .andExpect(method(HttpMethod.GET))
                .andRespond(withSuccess("[" + USER_JSON + "]", MediaType.APPLICATION_JSON));

        List<KeycloakUser> users = client.listUsers();

        assertThat(users).hasSize(1);
        assertThat(users.get(0).username()).isEqualTo("carlos");
        mockServer.verify();
    }

    @Test
    void getUserReturnsSingleUser() {
        expectToken();
        mockServer.expect(requestTo(BASE_URL + "/admin/realms/inventory/users/u1"))
                .andExpect(method(HttpMethod.GET))
                .andRespond(withSuccess(USER_JSON, MediaType.APPLICATION_JSON));

        KeycloakUser user = client.getUser("u1");

        assertThat(user.id()).isEqualTo("u1");
        assertThat(user.displayName()).isEqualTo("Carlos Hernandez");
        mockServer.verify();
    }

    @Test
    void listUserRealmRolesReturnsRoles() {
        expectToken();
        mockServer.expect(requestTo(BASE_URL + "/admin/realms/inventory/users/u1/role-mappings/realm"))
                .andExpect(method(HttpMethod.GET))
                .andRespond(withSuccess("[" + ROLE_JSON + "]", MediaType.APPLICATION_JSON));

        List<KeycloakRole> roles = client.listUserRealmRoles("u1");

        assertThat(roles).hasSize(1);
        assertThat(roles.get(0).name()).isEqualTo("INVENTORY_ADMIN");
        mockServer.verify();
    }

    @Test
    void getRealmRoleReturnsSingleRole() {
        expectToken();
        mockServer.expect(requestTo(BASE_URL + "/admin/realms/inventory/roles/INVENTORY_ADMIN"))
                .andExpect(method(HttpMethod.GET))
                .andRespond(withSuccess(ROLE_JSON, MediaType.APPLICATION_JSON));

        KeycloakRole role = client.getRealmRole("INVENTORY_ADMIN");

        assertThat(role.name()).isEqualTo("INVENTORY_ADMIN");
        mockServer.verify();
    }

    @Test
    void createUserPostsAndReturnsCreatedUser() {
        SecurityUserRequest request = new SecurityUserRequest(
                "carlos", "Carlos", "Hernandez", "carlos@test.local", true, Set.of()
        );
        expectToken();
        mockServer.expect(requestTo(BASE_URL + "/admin/realms/inventory/users"))
                .andExpect(method(HttpMethod.POST))
                .andRespond(withStatus(HttpStatus.CREATED)
                        .header("Location", BASE_URL + "/admin/realms/inventory/users/u1"));
        expectToken();
        mockServer.expect(requestTo(BASE_URL + "/admin/realms/inventory/users/u1"))
                .andExpect(method(HttpMethod.GET))
                .andRespond(withSuccess(USER_JSON, MediaType.APPLICATION_JSON));

        KeycloakUser user = client.createUser(request);

        assertThat(user.id()).isEqualTo("u1");
        mockServer.verify();
    }

    @Test
    void updateUserPutsAndReturnsUpdatedUser() {
        SecurityUserRequest request = new SecurityUserRequest(
                "carlos", "Carlos", "Hernandez", "carlos@test.local", true, Set.of()
        );
        expectToken();
        mockServer.expect(requestTo(BASE_URL + "/admin/realms/inventory/users/u1"))
                .andExpect(method(HttpMethod.PUT))
                .andRespond(withSuccess());
        expectToken();
        mockServer.expect(requestTo(BASE_URL + "/admin/realms/inventory/users/u1"))
                .andExpect(method(HttpMethod.GET))
                .andRespond(withSuccess(USER_JSON, MediaType.APPLICATION_JSON));

        KeycloakUser user = client.updateUser("u1", request);

        assertThat(user.id()).isEqualTo("u1");
        mockServer.verify();
    }

    @Test
    void replaceUserRealmRolesDeletesThenPosts() {
        KeycloakRole existing = new KeycloakRole("r0", "OLD_ROLE", "old", false, false, "inventory");
        KeycloakRole target = new KeycloakRole("r1", "INVENTORY_ADMIN", "admin", false, false, "inventory");

        expectToken();
        mockServer.expect(requestTo(BASE_URL + "/admin/realms/inventory/users/u1/role-mappings/realm"))
                .andExpect(method(HttpMethod.DELETE))
                .andRespond(withSuccess());
        expectToken();
        mockServer.expect(requestTo(BASE_URL + "/admin/realms/inventory/users/u1/role-mappings/realm"))
                .andExpect(method(HttpMethod.POST))
                .andRespond(withSuccess());

        client.replaceUserRealmRoles("u1", List.of(existing), List.of(target));

        mockServer.verify();
    }

    @Test
    void replaceUserRealmRolesSkipsDeleteWhenCurrentRolesEmpty() {
        KeycloakRole target = new KeycloakRole("r1", "INVENTORY_ADMIN", "admin", false, false, "inventory");

        expectToken();
        mockServer.expect(requestTo(BASE_URL + "/admin/realms/inventory/users/u1/role-mappings/realm"))
                .andExpect(method(HttpMethod.POST))
                .andRespond(withSuccess());

        client.replaceUserRealmRoles("u1", List.of(), List.of(target));

        mockServer.verify();
    }

    @Test
    void adminRequestFailureWrapsAsKeycloakAdminClientException() {
        expectToken();
        mockServer.expect(requestTo(BASE_URL + "/admin/realms/inventory/users?max=1000"))
                .andRespond(withStatus(HttpStatus.UNAUTHORIZED));

        assertThatThrownBy(() -> client.listUsers())
                .isInstanceOf(KeycloakAdminClientException.class)
                .hasMessageContaining("401");

        mockServer.verify();
    }

    @Test
    void constructorTrimsTrailingSlashFromAdminUrl() {
        RestClient.Builder builder = RestClient.builder();
        MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();
        KeycloakAdminClient clientWithSlash = new KeycloakAdminClient(
                builder, BASE_URL + "/", "inventory", "admin-service", "secret"
        );

        server.expect(requestTo(TOKEN_URL))
                .andExpect(method(HttpMethod.POST))
                .andRespond(withSuccess(TOKEN_JSON, MediaType.APPLICATION_JSON));
        server.expect(requestTo(BASE_URL + "/admin/realms/inventory/users?max=1000"))
                .andExpect(method(HttpMethod.GET))
                .andRespond(withSuccess("[]", MediaType.APPLICATION_JSON));

        List<KeycloakUser> users = clientWithSlash.listUsers();

        assertThat(users).isEmpty();
        server.verify();
    }

    @Test
    void listUsersReturnsEmptyListWhenBodyIsNull() {
        expectToken();
        mockServer.expect(requestTo(BASE_URL + "/admin/realms/inventory/users?max=1000"))
                .andExpect(method(HttpMethod.GET))
                .andRespond(withSuccess("null", MediaType.APPLICATION_JSON));

        List<KeycloakUser> users = client.listUsers();

        assertThat(users).isEmpty();
        mockServer.verify();
    }

    @Test
    void listUserRealmRolesReturnsEmptyListWhenBodyIsNull() {
        expectToken();
        mockServer.expect(requestTo(BASE_URL + "/admin/realms/inventory/users/u1/role-mappings/realm"))
                .andExpect(method(HttpMethod.GET))
                .andRespond(withSuccess("null", MediaType.APPLICATION_JSON));

        List<KeycloakRole> roles = client.listUserRealmRoles("u1");

        assertThat(roles).isEmpty();
        mockServer.verify();
    }

    @Test
    void createUserFallsBackToUsernameSearchWhenNoLocationHeader() {
        SecurityUserRequest request = new SecurityUserRequest(
                "carlos", "Carlos", "Hernandez", null, null, Set.of()
        );
        String usersByUsernameUrl = BASE_URL + "/admin/realms/inventory/users?username=carlos&exact=true&max=1";

        expectToken();
        mockServer.expect(requestTo(BASE_URL + "/admin/realms/inventory/users"))
                .andExpect(method(HttpMethod.POST))
                .andRespond(withStatus(HttpStatus.CREATED));
        expectToken();
        mockServer.expect(requestTo(usersByUsernameUrl))
                .andExpect(method(HttpMethod.GET))
                .andRespond(withSuccess("[" + USER_JSON + "]", MediaType.APPLICATION_JSON));

        KeycloakUser user = client.createUser(request);

        assertThat(user.username()).isEqualTo("carlos");
        mockServer.verify();
    }

    @Test
    void createUserWithBlankEmailOmitsEmailFromPayload() {
        SecurityUserRequest request = new SecurityUserRequest(
                "carlos", "Carlos", "Hernandez", "  ", true, Set.of()
        );
        expectToken();
        mockServer.expect(requestTo(BASE_URL + "/admin/realms/inventory/users"))
                .andExpect(method(HttpMethod.POST))
                .andRespond(withStatus(HttpStatus.CREATED)
                        .header("Location", BASE_URL + "/admin/realms/inventory/users/u1"));
        expectToken();
        mockServer.expect(requestTo(BASE_URL + "/admin/realms/inventory/users/u1"))
                .andExpect(method(HttpMethod.GET))
                .andRespond(withSuccess(USER_JSON, MediaType.APPLICATION_JSON));

        KeycloakUser user = client.createUser(request);

        assertThat(user.id()).isEqualTo("u1");
        mockServer.verify();
    }

    @Test
    void replaceUserRealmRolesSkipsPostWhenTargetRolesEmpty() {
        KeycloakRole existing = new KeycloakRole("r0", "OLD_ROLE", "old", false, false, "inventory");

        expectToken();
        mockServer.expect(requestTo(BASE_URL + "/admin/realms/inventory/users/u1/role-mappings/realm"))
                .andExpect(method(HttpMethod.DELETE))
                .andRespond(withSuccess());

        client.replaceUserRealmRoles("u1", List.of(existing), List.of());

        mockServer.verify();
    }

    @Test
    void fetchAccessTokenThrowsWhenTokenIsBlank() {
        mockServer.expect(requestTo(TOKEN_URL))
                .andExpect(method(HttpMethod.POST))
                .andRespond(withSuccess("{\"access_token\":\"\"}", MediaType.APPLICATION_JSON));

        assertThatThrownBy(() -> client.listUsers())
                .isInstanceOf(KeycloakAdminClientException.class)
                .hasMessageContaining("access token");

        mockServer.verify();
    }

    private void expectToken() {
        mockServer.expect(requestTo(TOKEN_URL))
                .andExpect(method(HttpMethod.POST))
                .andRespond(withSuccess(TOKEN_JSON, MediaType.APPLICATION_JSON));
    }
}
