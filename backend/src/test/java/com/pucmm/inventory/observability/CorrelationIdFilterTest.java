package com.pucmm.inventory.observability;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

class CorrelationIdFilterTest {
    private final CorrelationIdFilter filter = new CorrelationIdFilter();

    @Test
    void preservesValidClientCorrelationId() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/products");
        request.addHeader(CorrelationIdFilter.CORRELATION_ID_HEADER, "request-123");
        MockHttpServletResponse response = new MockHttpServletResponse();

        filter.doFilter(request, response, (servletRequest, servletResponse) -> { });

        assertThat(response.getHeader(CorrelationIdFilter.CORRELATION_ID_HEADER)).isEqualTo("request-123");
    }

    @Test
    void replacesUnsafeCorrelationId() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/products");
        request.addHeader(CorrelationIdFilter.CORRELATION_ID_HEADER, "unsafe\nvalue");
        MockHttpServletResponse response = new MockHttpServletResponse();

        filter.doFilter(request, response, (servletRequest, servletResponse) -> { });

        assertThat(response.getHeader(CorrelationIdFilter.CORRELATION_ID_HEADER)).matches("[0-9a-f-]{36}");
    }

    @Test
    void addsAuthenticatedUserAndEndpointToTheRequestContext() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/products");
        MockHttpServletResponse response = new MockHttpServletResponse();
        SecurityContextHolder.getContext().setAuthentication(
                UsernamePasswordAuthenticationToken.authenticated("edwin", "n/a", java.util.List.of())
        );

        try {
            filter.doFilter(request, response, (servletRequest, servletResponse) -> {
                assertThat(org.slf4j.MDC.get("user")).isEqualTo("edwin");
                assertThat(org.slf4j.MDC.get("endpoint")).isEqualTo("POST /products");
            });
        } finally {
            SecurityContextHolder.clearContext();
        }
    }
}
