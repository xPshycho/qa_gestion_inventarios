package com.pucmm.inventory.stock.domain;

import com.pucmm.inventory.product.domain.Product;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import org.hibernate.envers.Audited;
import org.hibernate.envers.RelationTargetAuditMode;

@Entity
@Audited
@Table(name = "stock_movements")
public class StockMovement {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "product_id", nullable = false)
    private Product product;

    @ManyToOne(fetch = FetchType.LAZY)
    @Audited(targetAuditMode = RelationTargetAuditMode.NOT_AUDITED)
    @JoinColumn(name = "user_id")
    private InventoryUser user;

    @Enumerated(EnumType.STRING)
    @Column(name = "movement_type", nullable = false, length = 20)
    private StockMovementType movementType;

    @Column(name = "previous_quantity", nullable = false)
    private Integer previousQuantity;

    @Column(name = "new_quantity", nullable = false)
    private Integer newQuantity;

    @Column(name = "delta_quantity", nullable = false)
    private Integer deltaQuantity;

    @Column(length = 500)
    private String observations;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    protected StockMovement() {
    }

    public StockMovement(
            Product product,
            InventoryUser user,
            StockMovementType movementType,
            Integer previousQuantity,
            Integer newQuantity,
            Integer deltaQuantity,
            String observations
    ) {
        this.product = product;
        this.user = user;
        this.movementType = movementType;
        this.previousQuantity = previousQuantity;
        this.newQuantity = newQuantity;
        this.deltaQuantity = deltaQuantity;
        this.observations = observations;
    }

    @PrePersist
    void prePersist() {
        createdAt = OffsetDateTime.now(ZoneOffset.UTC);
    }

    public Long getId() {
        return id;
    }

    public Product getProduct() {
        return product;
    }

    public InventoryUser getUser() {
        return user;
    }

    public StockMovementType getMovementType() {
        return movementType;
    }

    public Integer getPreviousQuantity() {
        return previousQuantity;
    }

    public Integer getNewQuantity() {
        return newQuantity;
    }

    public Integer getDeltaQuantity() {
        return deltaQuantity;
    }

    public String getObservations() {
        return observations;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }
}
