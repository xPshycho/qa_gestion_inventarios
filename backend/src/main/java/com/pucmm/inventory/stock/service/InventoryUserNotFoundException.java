package com.pucmm.inventory.stock.service;

public class InventoryUserNotFoundException extends RuntimeException {
    public InventoryUserNotFoundException(Long id) {
        super("Inventory user not found: " + id);
    }
}
