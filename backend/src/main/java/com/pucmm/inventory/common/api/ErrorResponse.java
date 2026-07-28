package com.pucmm.inventory.common.api;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;

public record ErrorResponse(
        int status,
        String message,
        OffsetDateTime timestamp
) {
    public static ErrorResponse of(int status, String message) {
        return new ErrorResponse(status, message, OffsetDateTime.now(ZoneOffset.UTC));
    }
}
