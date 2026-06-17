package com.pucmm.inventory.stock.api.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

@Schema(description = "Datos para registrar una entrada o salida de stock")
public record StockMovementRequest(
        @Schema(example = "3")
        @NotNull
        @Positive
        Integer quantity,

        @Schema(example = "Recepcion de mercancia")
        @Size(max = 500)
        String observations
) {
}
