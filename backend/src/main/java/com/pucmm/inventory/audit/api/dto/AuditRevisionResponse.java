package com.pucmm.inventory.audit.api.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.OffsetDateTime;
import java.util.Map;

@Schema(description = "Revision de auditoria de una entidad")
public record AuditRevisionResponse(
        String entityName,
        Long entityId,
        Integer revision,
        String revisionType,
        OffsetDateTime changedAt,
        String username,
        Map<String, Object> previousValues,
        Map<String, Object> currentValues
) {
}
