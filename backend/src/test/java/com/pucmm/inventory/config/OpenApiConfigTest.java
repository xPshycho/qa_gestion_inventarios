package com.pucmm.inventory.config;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class OpenApiConfigTest {
    @Test
    void canInstantiateOpenApiConfig() {
        assertThat(new OpenApiConfig()).isNotNull();
    }
}
