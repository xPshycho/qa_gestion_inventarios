package com.pucmm.inventory.observability;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.UUID;
import org.slf4j.MDC;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import org.springframework.web.filter.OncePerRequestFilter;

/** Adds request context to logs without trusting unbounded values from clients. */
@Component
@Order(Ordered.LOWEST_PRECEDENCE)
public class CorrelationIdFilter extends OncePerRequestFilter {
    public static final String CORRELATION_ID_HEADER = "X-Correlation-ID";
    private static final int MAX_CORRELATION_ID_LENGTH = 128;

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {
        String correlationId = resolveCorrelationId(request.getHeader(CORRELATION_ID_HEADER));
        MDC.put("correlationId", correlationId);
        MDC.put("endpoint", request.getMethod() + " " + request.getRequestURI());
        MDC.put("user", currentUsername());
        response.setHeader(CORRELATION_ID_HEADER, correlationId);

        try {
            filterChain.doFilter(request, response);
        } finally {
            MDC.remove("correlationId");
            MDC.remove("endpoint");
            MDC.remove("user");
        }
    }

    private String resolveCorrelationId(String requestedId) {
        if (StringUtils.hasText(requestedId)
                && requestedId.length() <= MAX_CORRELATION_ID_LENGTH
                && requestedId.chars().allMatch(character -> character >= 0x21 && character <= 0x7e)) {
            return requestedId;
        }
        return UUID.randomUUID().toString();
    }

    private String currentUsername() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        return authentication != null && authentication.isAuthenticated() ? authentication.getName() : "anonymous";
    }
}
