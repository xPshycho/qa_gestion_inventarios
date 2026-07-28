package com.pucmm.inventory.product.service;

public class ProductNotFoundException extends RuntimeException {
    public ProductNotFoundException(Long id) {
        super("Product not found with id " + id);
    }
}
