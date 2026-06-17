package com.pucmm.inventory.stock.service;

public class AuthenticatedInventoryUserException extends RuntimeException {
    public AuthenticatedInventoryUserException() {
        super("Authenticated inventory user is required");
    }

    public AuthenticatedInventoryUserException(String username) {
        super("Authenticated inventory user is not registered: " + username);
    }
}
