package com.pucmm.inventory.product.api;

import com.pucmm.inventory.product.api.dto.ProductPageResponse;
import com.pucmm.inventory.product.api.dto.ProductRequest;
import com.pucmm.inventory.product.api.dto.ProductResponse;
import com.pucmm.inventory.product.domain.ProductStatus;
import com.pucmm.inventory.product.service.ProductService;
import com.pucmm.inventory.stock.api.dto.StockAdjustmentRequest;
import com.pucmm.inventory.stock.api.dto.StockMovementRequest;
import com.pucmm.inventory.stock.api.dto.StockMovementResponse;
import com.pucmm.inventory.stock.service.AuthenticatedInventoryUserResolver;
import com.pucmm.inventory.stock.service.StockService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Pattern;
import java.net.URI;
import java.util.List;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Validated
@RestController
@RequestMapping("/products")
@Tag(name = "Products", description = "CRUD de productos del inventario")
public class ProductController {
    private final ProductService productService;
    private final StockService stockService;
    private final AuthenticatedInventoryUserResolver authenticatedInventoryUserResolver;

    public ProductController(
            ProductService productService,
            StockService stockService,
            AuthenticatedInventoryUserResolver authenticatedInventoryUserResolver
    ) {
        this.productService = productService;
        this.stockService = stockService;
        this.authenticatedInventoryUserResolver = authenticatedInventoryUserResolver;
    }

    @GetMapping
    @Operation(summary = "Listar productos con paginacion, busqueda y filtros")
    public ProductPageResponse listProducts(
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size,
            @RequestParam(required = false) String search,
            @RequestParam(required = false) String category,
            @RequestParam(required = false) ProductStatus status,
            @RequestParam(defaultValue = "id")
            @Pattern(regexp = "id|sku|name|category|price|currentStock|minimumStock|status|updatedAt")
            String sort,
            @RequestParam(defaultValue = "asc") @Pattern(regexp = "(?i)asc|desc") String direction
    ) {
        return productService.findProducts(page, size, search, category, status, sort, direction);
    }

    @GetMapping("/{id}")
    @Operation(summary = "Obtener producto por id")
    public ProductResponse getProduct(@PathVariable Long id) {
        return productService.getProduct(id);
    }

    @PostMapping
    @Operation(summary = "Crear producto")
    public ResponseEntity<ProductResponse> createProduct(
            @Valid @RequestBody ProductRequest request,
            Authentication authentication
    ) {
        ProductResponse response = productService.createProduct(
                request,
                authenticatedInventoryUserResolver.resolveUsername(authentication)
        );
        return ResponseEntity
                .created(URI.create("/products/" + response.id()))
                .body(response);
    }

    @PutMapping("/{id}")
    @Operation(summary = "Actualizar producto")
    public ProductResponse updateProduct(
            @PathVariable Long id,
            @Valid @RequestBody ProductRequest request
    ) {
        return productService.updateProduct(id, request);
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "Eliminar producto")
    public ResponseEntity<Void> deleteProduct(@PathVariable Long id) {
        productService.deleteProduct(id);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{id}/stock/entries")
    @Operation(summary = "Registrar entrada de stock")
    public StockMovementResponse registerStockEntry(
            @PathVariable Long id,
            @Valid @RequestBody StockMovementRequest request,
            Authentication authentication
    ) {
        return stockService.registerEntry(id, request, authenticatedInventoryUserResolver.resolveUsername(authentication));
    }

    @PostMapping("/{id}/stock/exits")
    @Operation(summary = "Registrar salida de stock")
    public StockMovementResponse registerStockExit(
            @PathVariable Long id,
            @Valid @RequestBody StockMovementRequest request,
            Authentication authentication
    ) {
        return stockService.registerExit(id, request, authenticatedInventoryUserResolver.resolveUsername(authentication));
    }

    @PostMapping("/{id}/stock/adjustments")
    @Operation(summary = "Registrar ajuste de inventario")
    public StockMovementResponse adjustStock(
            @PathVariable Long id,
            @Valid @RequestBody StockAdjustmentRequest request,
            Authentication authentication
    ) {
        return stockService.adjustStock(id, request, authenticatedInventoryUserResolver.resolveUsername(authentication));
    }

    @GetMapping("/{id}/stock-movements")
    @Operation(summary = "Consultar historial de movimientos de stock")
    public List<StockMovementResponse> listStockMovements(@PathVariable Long id) {
        return stockService.findMovements(id);
    }
}
