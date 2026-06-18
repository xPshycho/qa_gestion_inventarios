package com.pucmm.inventory.product.api.dto;

import com.pucmm.inventory.product.domain.ProductStatus;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;

@Schema(description = "Datos requeridos para crear o actualizar un producto")
public record ProductRequest(
        @Schema(example = "DELL-LAT-5440")
        @NotBlank
        @Size(max = 64)
        String sku,

        @Schema(example = "Dell Latitude 5440")
        @NotBlank
        @Size(max = 160)
        String name,

        @Schema(example = "Laptop empresarial Dell Latitude 5440 con pantalla de 14 pulgadas")
        @Size(max = 500)
        String description,

        @Schema(example = "Laptops")
        @NotBlank
        @Size(max = 100)
        String category,

        @Schema(example = "68500.00")
        @NotNull
        @DecimalMin("0.00")
        @Digits(integer = 10, fraction = 2)
        BigDecimal price,

        @Schema(example = "18")
        @NotNull
        @Min(0)
        Integer currentStock,

        @Schema(example = "5")
        @NotNull
        @Min(0)
        Integer minimumStock,

        @Schema(example = "ACTIVE")
        @NotNull
        ProductStatus status
) {
}
