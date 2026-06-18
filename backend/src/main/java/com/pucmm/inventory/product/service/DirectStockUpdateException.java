package com.pucmm.inventory.product.service;

public class DirectStockUpdateException extends RuntimeException {
    public DirectStockUpdateException() {
        super("currentStock must be changed through auditable stock movements");
    }
}