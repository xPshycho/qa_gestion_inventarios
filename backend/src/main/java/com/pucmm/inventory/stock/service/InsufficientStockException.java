package com.pucmm.inventory.stock.service;

public class InsufficientStockException extends RuntimeException {
    public InsufficientStockException(Long productId, int currentStock, int requestedQuantity) {
        super("Stock insuficiente para producto " + productId
                + ". Stock actual: " + currentStock
                + ", salida solicitada: " + requestedQuantity);
    }
}
