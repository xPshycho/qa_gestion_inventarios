package com.pucmm.inventory.product.service;

import com.pucmm.inventory.product.api.dto.ProductPageResponse;
import com.pucmm.inventory.product.api.dto.ProductRequest;
import com.pucmm.inventory.product.api.dto.ProductResponse;
import com.pucmm.inventory.product.domain.Product;
import com.pucmm.inventory.product.domain.ProductData;
import com.pucmm.inventory.product.domain.ProductStatus;
import com.pucmm.inventory.product.repository.ProductRepository;
import com.pucmm.inventory.stock.domain.InventoryUser;
import com.pucmm.inventory.stock.domain.StockMovement;
import com.pucmm.inventory.stock.domain.StockMovementType;
import com.pucmm.inventory.stock.repository.InventoryUserRepository;
import com.pucmm.inventory.stock.repository.StockMovementRepository;
import com.pucmm.inventory.stock.service.AuthenticatedInventoryUserException;
import jakarta.persistence.criteria.Predicate;
import java.util.ArrayList;
import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

@Service
@Transactional(readOnly = true)
public class ProductService {
    private final ProductRepository productRepository;
    private final InventoryUserRepository inventoryUserRepository;
    private final StockMovementRepository stockMovementRepository;

    public ProductService(
            ProductRepository productRepository,
            InventoryUserRepository inventoryUserRepository,
            StockMovementRepository stockMovementRepository
    ) {
        this.productRepository = productRepository;
        this.inventoryUserRepository = inventoryUserRepository;
        this.stockMovementRepository = stockMovementRepository;
    }

    public ProductPageResponse findProducts(
            int page,
            int size,
            String search,
            String category,
            ProductStatus status,
            String sort,
            String direction
    ) {
        PageRequest pageRequest = PageRequest.of(page, size, Sort.by(Sort.Direction.fromString(direction), sort));
        Page<ProductResponse> products = productRepository
                .findAll(buildSpecification(search, category, status), pageRequest)
                .map(ProductResponse::from);

        return ProductPageResponse.from(products);
    }

    public ProductResponse getProduct(Long id) {
        return ProductResponse.from(findProductById(id));
    }

    @Transactional
    public ProductResponse createProduct(ProductRequest request, String actorUsername) {
        if (productRepository.existsBySkuIgnoreCase(request.sku())) {
            throw new DuplicateSkuException(request.sku());
        }

        Product product = new Product(toProductData(request));
        Product savedProduct = productRepository.save(product);
        InventoryUser actor = findAuthenticatedUser(actorUsername);
        stockMovementRepository.save(new StockMovement(
                savedProduct,
                actor,
                StockMovementType.INITIAL,
                0,
                savedProduct.getCurrentStock(),
                savedProduct.getCurrentStock(),
                "Cantidad inicial registrada al crear el producto"
        ));

        return ProductResponse.from(savedProduct);
    }

    @Transactional
    public ProductResponse updateProduct(Long id, ProductRequest request) {
        Product product = findProductById(id);
        if (productRepository.existsBySkuIgnoreCaseAndIdNot(request.sku(), id)) {
            throw new DuplicateSkuException(request.sku());
        }
        if (!product.getCurrentStock().equals(request.currentStock())) {
            throw new DirectStockUpdateException();
        }

        product.update(toProductData(request));

        return ProductResponse.from(productRepository.save(product));
    }

    @Transactional
    public void deleteProduct(Long id) {
        Product product = findProductById(id);
        product.archive();
        productRepository.save(product);
    }

    private InventoryUser findAuthenticatedUser(String username) {
        if (!StringUtils.hasText(username)) {
            throw new AuthenticatedInventoryUserException();
        }

        String normalizedUsername = username.trim();
        return inventoryUserRepository.findByUsernameIgnoreCase(normalizedUsername)
                .orElseThrow(() -> new AuthenticatedInventoryUserException(normalizedUsername));
    }

    private ProductData toProductData(ProductRequest request) {
        return new ProductData(
                request.sku(),
                request.name(),
                request.description(),
                request.category(),
                request.price(),
                request.currentStock(),
                request.minimumStock(),
                request.status()
        );
    }

    private Product findProductById(Long id) {
        return productRepository.findByIdAndArchivedFalse(id)
                .orElseThrow(() -> new ProductNotFoundException(id));
    }

    private Specification<Product> buildSpecification(String search, String category, ProductStatus status) {
        return (root, query, criteriaBuilder) -> {
            List<Predicate> predicates = new ArrayList<>();
            predicates.add(criteriaBuilder.isFalse(root.get("archived")));

            if (StringUtils.hasText(search)) {
                String pattern = "%" + search.trim().toLowerCase() + "%";
                predicates.add(criteriaBuilder.or(
                        criteriaBuilder.like(criteriaBuilder.lower(root.get("name")), pattern),
                        criteriaBuilder.like(criteriaBuilder.lower(root.get("sku")), pattern),
                        criteriaBuilder.like(criteriaBuilder.lower(root.get("description")), pattern)
                ));
            }

            if (StringUtils.hasText(category)) {
                predicates.add(criteriaBuilder.equal(
                        criteriaBuilder.lower(root.get("category")),
                        category.trim().toLowerCase()
                ));
            }

            if (status != null) {
                predicates.add(criteriaBuilder.equal(root.get("status"), status));
            }

            return criteriaBuilder.and(predicates.toArray(Predicate[]::new));
        };
    }
}
