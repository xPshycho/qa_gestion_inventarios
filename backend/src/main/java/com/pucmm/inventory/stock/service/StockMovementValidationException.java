package com.pucmm.inventory.stock.service;

public class StockMovementValidationException extends RuntimeException {
    public StockMovementValidationException(String message) {
        super(message);
    }
}
