package com.pucmm.inventory.security.api;

import static com.pucmm.inventory.config.SecurityConfig.PRODUCT_VIEW;
import static com.pucmm.inventory.config.SecurityConfig.USER_MANAGE;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.pucmm.inventory.common.api.GlobalExceptionHandler;
import com.pucmm.inventory.config.SecurityConfig;
import com.pucmm.inventory.security.api.dto.SecurityPermissionResponse;
import com.pucmm.inventory.security.api.dto.SecurityRoleResponse;
import com.pucmm.inventory.security.api.dto.SecurityUserRequest;
import com.pucmm.inventory.security.api.dto.SecurityUserResponse;
import com.pucmm.inventory.security.service.SecurityAdminService;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.RequestPostProcessor;

@WebMvcTest(SecurityAdminController.class)
@Import({GlobalExceptionHandler.class, SecurityConfig.class})
class SecurityAdminControllerTest {
    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockitoBean
    private SecurityAdminService securityAdminService;

    @Test
    void securityEndpointsRequireAuthentication() throws Exception {
        mockMvc.perform(get("/security/users"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void securityEndpointsRequireUserManagePermission() throws Exception {
        mockMvc.perform(get("/security/users")
                        .with(jwtWith(PRODUCT_VIEW)))
                .andExpect(status().isForbidden());
    }

    @Test
    void listUsersReturnsConfiguredAssignments() throws Exception {
        when(securityAdminService.listUsers()).thenReturn(List.of(user()));

        mockMvc.perform(get("/security/users")
                        .with(jwtWith(USER_MANAGE)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].username").value("carlos"))
                .andExpect(jsonPath("$[0].roleCodes[0]").value("INVENTORY_ADMIN"));
    }

    @Test
    void createUserReturnsCreatedLocation() throws Exception {
        SecurityUserRequest request = request();
        when(securityAdminService.createUser(request)).thenReturn(user());

        mockMvc.perform(post("/security/users")
                        .with(jwtWith(USER_MANAGE))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andExpect(header().string("Location", "/security/users/user-1"))
                .andExpect(jsonPath("$.username").value("carlos"));
    }

    @Test
    void listRolesReturnsPermissionMatrix() throws Exception {
        when(securityAdminService.listRoles()).thenReturn(List.of(new SecurityRoleResponse(
                "INVENTORY_ADMIN",
                "Administrador de inventario",
                "Acceso completo",
                List.of(new SecurityPermissionResponse("user:manage", "Seguridad", "Gestionar usuarios"))
        )));

        mockMvc.perform(get("/security/roles")
                        .with(jwtWith(USER_MANAGE)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].code").value("INVENTORY_ADMIN"))
                .andExpect(jsonPath("$[0].permissions[0].code").value("user:manage"));
    }

    private SecurityUserRequest request() {
        return new SecurityUserRequest(
                "carlos",
                "Carlos",
                "Hernandez",
                "carlos@example.local",
                true,
                Set.of("INVENTORY_ADMIN")
        );
    }

    private SecurityUserResponse user() {
        return new SecurityUserResponse(
                "user-1",
                "carlos",
                "Carlos Hernandez",
                "Carlos",
                "Hernandez",
                "carlos@example.local",
                true,
                List.of("INVENTORY_ADMIN")
        );
    }

    private static RequestPostProcessor jwtWith(String permission) {
        return jwt().authorities(new SimpleGrantedAuthority(permission));
    }
}
