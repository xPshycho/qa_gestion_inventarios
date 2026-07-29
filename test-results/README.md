# Índice central de resultados de pruebas

`test-results/` es la única ruta local y de CI para consultar evidencias
exportables. Las herramientas pueden producir archivos nativos en sus carpetas
de build, pero los workflows y comandos documentados deben copiarlos aquí antes
de publicarlos.

```text
test-results/
├── backend/
│   ├── unit/
│   ├── integration/
│   └── api/
├── frontend/
│   └── unit/
├── e2e/
│   └── playwright/
├── performance/
│   └── k6/
├── security/
│   ├── headers/
│   ├── zap/
│   └── trivy/
└── staging/
    └── post-deploy/
```

Cada suite recolectada contiene:

- `summary.md`: resultado legible;
- `summary.json`: contrato exportable para automatización o Grafana;
- `metrics.prom`: métricas en formato de exposición Prometheus;
- `evidence/`: JUnit, cobertura, reportes o logs copiados desde la herramienta.

Los resultados generados están ignorados por Git. Este índice, el esquema y los
ejemplos sanitizados sí se versionan. Consulte
[`docs/testing/ci-reporting.md`](../docs/testing/ci-reporting.md) para comandos,
artifacts y excepciones de seguridad.

Para preparar dependencias y ejecutar todas las suites automatizadas desde la
raíz:

```bash
make test
```

El ejecutor genera `.env` con secretos aleatorios mediante el contrato seguro
del proyecto, usa imágenes fijadas para Playwright, k6, ZAP y Trivy, y elimina
cada stack aislado al terminar. Los gates de líneas son 90% para backend
unitario, 60% para integración y 80% para frontend.
