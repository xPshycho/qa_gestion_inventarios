package com.pucmm.inventory.common.api;

import com.pucmm.inventory.product.service.DuplicateSkuException;
import com.pucmm.inventory.product.service.DirectStockUpdateException;
import com.pucmm.inventory.product.service.ProductNotFoundException;
import com.pucmm.inventory.security.client.KeycloakAdminClientException;
import com.pucmm.inventory.security.service.InvalidSecurityRoleException;
import com.pucmm.inventory.stock.service.AuthenticatedInventoryUserException;
import com.pucmm.inventory.stock.service.InsufficientStockException;
import com.pucmm.inventory.stock.service.InventoryUserNotFoundException;
import com.pucmm.inventory.stock.service.StockMovementValidationException;
import jakarta.validation.ConstraintViolationException;
import java.util.stream.Collectors;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class GlobalExceptionHandler {
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> handleValidation(MethodArgumentNotValidException exception) {
        String message = exception.getBindingResult().getFieldErrors().stream()
                .map(error -> error.getField() + " " + error.getDefaultMessage())
                .collect(Collectors.joining("; "));

        return buildResponse(HttpStatus.BAD_REQUEST, message);
    }

    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<ErrorResponse> handleConstraintViolation(ConstraintViolationException exception) {
        return buildResponse(HttpStatus.BAD_REQUEST, exception.getMessage());
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ErrorResponse> handleNotReadable(HttpMessageNotReadableException exception) {
        return buildResponse(HttpStatus.BAD_REQUEST, "Invalid request body");
    }

    @ExceptionHandler(ProductNotFoundException.class)
    public ResponseEntity<ErrorResponse> handleProductNotFound(ProductNotFoundException exception) {
        return buildResponse(HttpStatus.NOT_FOUND, exception.getMessage());
    }

    @ExceptionHandler(DuplicateSkuException.class)
    public ResponseEntity<ErrorResponse> handleDuplicateSku(DuplicateSkuException exception) {
        return buildResponse(HttpStatus.CONFLICT, exception.getMessage());
    }

    @ExceptionHandler(InventoryUserNotFoundException.class)
    public ResponseEntity<ErrorResponse> handleInventoryUserNotFound(InventoryUserNotFoundException exception) {
        return buildResponse(HttpStatus.NOT_FOUND, exception.getMessage());
    }

    @ExceptionHandler(AuthenticatedInventoryUserException.class)
    public ResponseEntity<ErrorResponse> handleAuthenticatedInventoryUser(AuthenticatedInventoryUserException exception) {
        return buildResponse(HttpStatus.FORBIDDEN, exception.getMessage());
    }

    @ExceptionHandler({InsufficientStockException.class, StockMovementValidationException.class,
            DirectStockUpdateException.class})
    public ResponseEntity<ErrorResponse> handleStockBusinessRule(RuntimeException exception) {
        return buildResponse(HttpStatus.BAD_REQUEST, exception.getMessage());
    }

    @ExceptionHandler(InvalidSecurityRoleException.class)
    public ResponseEntity<ErrorResponse> handleInvalidSecurityRole(InvalidSecurityRoleException exception) {
        return buildResponse(HttpStatus.BAD_REQUEST, exception.getMessage());
    }

    @ExceptionHandler(KeycloakAdminClientException.class)
    public ResponseEntity<ErrorResponse> handleKeycloakAdminClient(KeycloakAdminClientException exception) {
        return buildResponse(HttpStatus.BAD_GATEWAY, exception.getMessage());
    }

    private ResponseEntity<ErrorResponse> buildResponse(HttpStatus status, String message) {
        return ResponseEntity
                .status(status)
                .body(ErrorResponse.of(status.value(), message));
    }
}