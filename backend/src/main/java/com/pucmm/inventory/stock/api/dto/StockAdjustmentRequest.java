package com.pucmm.inventory.stock.api.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

@Schema(description = "Datos para ajustar el stock absoluto de un producto")
public record StockAdjustmentRequest(
        @Schema(example = "10")
        @NotNull
        @Min(0)
        Integer newQuantity,

        @Schema(example = "Ajuste por conteo fisico")
        @Size(max = 500)
        String observations
) {
}