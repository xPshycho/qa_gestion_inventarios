package com.pucmm.inventory.audit.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import org.hibernate.envers.RevisionEntity;
import org.hibernate.envers.RevisionNumber;
import org.hibernate.envers.RevisionTimestamp;

@Entity
@RevisionEntity(InventoryRevisionListener.class)
@Table(name = "audit_revisions")
public class InventoryRevisionEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @RevisionNumber
    private Integer id;

    @RevisionTimestamp
    @Column(name = "revision_timestamp", nullable = false)
    private Long revisionTimestamp;

    @Column(nullable = false, length = 120)
    private String username;

    public Integer getId() {
        return id;
    }

    public Long getRevisionTimestamp() {
        return revisionTimestamp;
    }

    public OffsetDateTime getChangedAt() {
        return Instant.ofEpochMilli(revisionTimestamp).atOffset(ZoneOffset.UTC);
    }

    public String getUsername() {
        return username;
    }

    void setUsername(String username) {
        this.username = username;
    }
}
