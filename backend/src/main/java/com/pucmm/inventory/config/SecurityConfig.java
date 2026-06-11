package com.pucmm.inventory.config;

import java.util.Collection;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
public class SecurityConfig {
    public static final String PRODUCT_VIEW = "product:view";
    public static final String PRODUCT_MANAGE = "product:manage";
    public static final String STOCK_VIEW = "stock:view";
    public static final String STOCK_MANAGE = "stock:manage";
    public static final String REPORT_VIEW = "report:view";
    public static final String AUDIT_VIEW = "audit:view";

    @Bean
    @SuppressWarnings("java:S4502")
    SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        return http
                .csrf(AbstractHttpConfigurer::disable)
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(authorize -> authorize
                        .requestMatchers(HttpMethod.GET, "/actuator/health").permitAll()
                        .requestMatchers(HttpMethod.GET, "/products/*/stock-movements").hasAuthority(STOCK_VIEW)
                        .requestMatchers(HttpMethod.GET, "/products", "/products/*").hasAuthority(PRODUCT_VIEW)
                        .requestMatchers(HttpMethod.POST, "/products/*/stock/**").hasAuthority(STOCK_MANAGE)
                        .requestMatchers(HttpMethod.POST, "/products").hasAuthority(PRODUCT_MANAGE)
                        .requestMatchers(HttpMethod.PUT, "/products/*").hasAuthority(PRODUCT_MANAGE)
                        .requestMatchers(HttpMethod.DELETE, "/products/*").hasAuthority(PRODUCT_MANAGE)
                        .requestMatchers(HttpMethod.GET, "/reports/**").hasAuthority(REPORT_VIEW)
                        .requestMatchers(HttpMethod.GET, "/audit/**").hasAuthority(AUDIT_VIEW)
                        .anyRequest().authenticated())
                .oauth2ResourceServer(oauth2 -> oauth2.jwt(jwt -> jwt.jwtAuthenticationConverter(jwtAuthenticationConverter())))
                .build();
    }

    @Bean
    JwtAuthenticationConverter jwtAuthenticationConverter() {
        JwtAuthenticationConverter converter = new JwtAuthenticationConverter();
        converter.setJwtGrantedAuthoritiesConverter(this::extractAuthorities);
        return converter;
    }

    private Collection<GrantedAuthority> extractAuthorities(Jwt jwt) {
        Set<GrantedAuthority> authorities = new HashSet<>();
        addAuthorities(authorities, jwt.getClaimAsStringList("permissions"));
        addAuthorities(authorities, jwt.getClaimAsStringList("scp"));
        addAuthorities(authorities, splitScope(jwt.getClaimAsString("scope")));
        return authorities;
    }

    private void addAuthorities(Set<GrantedAuthority> authorities, List<String> permissions) {
        if (permissions == null) {
            return;
        }

        permissions.stream()
                .filter(permission -> permission != null && !permission.isBlank())
                .map(SimpleGrantedAuthority::new)
                .forEach(authorities::add);
    }

    private List<String> splitScope(String scope) {
        if (scope == null || scope.isBlank()) {
            return List.of();
        }

        return List.of(scope.split("\\s+"));
    }
}
