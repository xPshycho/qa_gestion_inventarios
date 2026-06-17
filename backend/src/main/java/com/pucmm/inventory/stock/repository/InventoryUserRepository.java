package com.pucmm.inventory.stock.repository;

import com.pucmm.inventory.stock.domain.InventoryUser;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface InventoryUserRepository extends JpaRepository<InventoryUser, Long> {
    Optional<InventoryUser> findByUsernameIgnoreCase(String username);
}
