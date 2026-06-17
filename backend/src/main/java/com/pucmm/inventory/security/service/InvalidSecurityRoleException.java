package com.pucmm.inventory.security.service;

public class InvalidSecurityRoleException extends RuntimeException {
    public InvalidSecurityRoleException(String roleCode) {
        super("Role funcional no permitido: " + roleCode);
    }
}
