# Índice general

Esta es la documentación canónica de cierre técnico del Sistema de Gestión de
Inventarios Empresarial. La auditoría se realizó el 29 de julio de 2026
(`America/Santo_Domingo`); los artefactos automatizados registran la fecha UTC
30 de julio de 2026.

## Estado y límites

- Repositorio, configuración, pruebas locales e infraestructura GCP: revisados.
- GCP: consultas de solo lectura sobre
  `project-e70349a8-c787-4733-9a0`.
- VM de producción: superficie HTTPS verificada; inspección interna por IAP
  pendiente porque la identidad auditora no obtuvo acceso OS Login.
- GitHub issue #91: no se modificó, comentó ni cerró por instrucción expresa.
- Secretos: solo se documentan nombres, consumidores y procedimientos; nunca
  valores.
- Las fuentes originales `proyecto_final*` fueron auditadas como insumos, pero
  no forman parte de este commit documental por la exclusión expresa de
  reportes preexistentes. Su disponibilidad posterior al clonado es
  **Pendiente de verificación**.

## Documentos

| Nº | Documento | Pregunta que responde |
|---:|---|---|
| 01 | [Descripción](01-descripcion-del-proyecto.md) | ¿Qué resuelve y cuál es su alcance? |
| 02 | [Arquitectura](02-arquitectura.md) | ¿Cómo se conectan los componentes? |
| 03 | [Infraestructura GCP](03-infraestructura-gcp.md) | ¿Qué existe realmente en GCP? |
| 04 | [Instalación local](04-instalacion-local.md) | ¿Cómo se instala desde cero? |
| 05 | [Configuración](05-configuracion.md) | ¿Qué variables y puertos existen? |
| 06 | [Base de datos](06-base-de-datos.md) | ¿Cómo se migra, consulta y respalda PostgreSQL? |
| 07 | [API](07-api.md) | ¿Cómo consumir el servicio sin GUI? |
| 08 | [Autenticación y autorización](08-autenticacion-autorizacion.md) | ¿Cómo funcionan Keycloak, OAuth2 y JWT? |
| 09 | [Matriz de permisos](09-matriz-de-permisos.md) | ¿Qué permite cada rol? |
| 10 | [Usuarios y accesos](10-usuarios-y-accesos.md) | ¿Qué identidades existen y dónde se administran? |
| 11 | [Guía de pruebas](11-guia-de-pruebas.md) | ¿Cómo se ejecuta cada suite? |
| 12 | [Coverage](12-coverage.md) | ¿Qué cobertura fue medida? |
| 13 | [Playwright](13-pruebas-e2e-playwright.md) | ¿Cómo ejecutar y depurar E2E? |
| 14 | [OWASP ZAP](14-seguridad-zap.md) | ¿Qué seguridad dinámica se validó? |
| 15 | [k6](15-rendimiento-k6.md) | ¿Qué rendimiento se midió? |
| 16 | [CI/CD y Jenkins](16-ci-cd-jenkins.md) | ¿Qué automatiza cada pipeline? |
| 17 | [Observabilidad](17-observabilidad.md) | ¿Cómo consultar métricas, logs y trazas? |
| 18 | [Operación y mantenimiento](18-operacion-y-mantenimiento.md) | ¿Cómo operar el sistema? |
| 19 | [Staging y producción](19-staging-produccion.md) | ¿Qué diferencia a los ambientes? |
| 20 | [Backup y rollback](20-backup-y-rollback.md) | ¿Cómo recuperar una versión? |
| 21 | [Troubleshooting](21-troubleshooting.md) | ¿Cómo diagnosticar fallos? |
| 22 | [Evidencias](22-evidencias.md) | ¿Dónde consultar cada resultado? |
| 23 | [Presentación](23-presentacion.md) | ¿Cómo exponer el proyecto? |
| 24 | [Script de demostración](24-script-demostracion.md) | ¿Cómo hacer una demo reproducible? |
| 25 | [Trazabilidad](25-trazabilidad-entregables.md) | ¿Dónde se cubre cada entregable? |
| 26 | [Estado documental del issue #91](26-cierre-issue-91.md) | ¿Qué está completo o pendiente sin tocar GitHub? |
| 27 | [Guía operativa GCP/OpenTofu](27-guia-operativa-gcp-opentofu.md) | ¿Cómo operar ambientes, approvals, state, secretos e incidentes sin confundir lo vigente con lo declarado? |

## Diagramas

- [Arquitectura general](diagrams/arquitectura-general.md)
- [Despliegue](diagrams/despliegue.md)
- [Red GCP](diagrams/red-gcp.md)
- [Flujo de autenticación](diagrams/flujo-autenticacion.md)
- [Flujo de API](diagrams/flujo-api.md)
- [CI/CD](diagrams/ci-cd.md)
- [Observabilidad](diagrams/observabilidad.md)
- [Modelo de datos](diagrams/modelo-datos.md)

## Convención de comandos

Cada bloque operativo usa una o más etiquetas:

| Etiqueta | Significado |
|---|---|
| `Verificado` | Ejecutado satisfactoriamente durante esta auditoría. |
| `No verificado` | Derivado de código/configuración, no ejecutado en la auditoría. |
| `Requiere privilegios` | Necesita Docker, IAM, OS Login, `sudo` o credenciales. |
| `Solo staging` / `Solo producción` | No debe ejecutarse fuera de ese entorno. |
| `Destructivo` | Cambia o elimina estado; exige respaldo y aprobación. |

Los resultados actuales y limitaciones están centralizados en
[Dónde consultar los resultados](22-evidencias.md#dónde-consultar-los-resultados).

## Índices de evidencia

- [Coverage](evidence/coverage/README.md)
- [Datos](evidence/data/README.md)
- [E2E](evidence/e2e/README.md)
- [Exploratoria](evidence/exploratory/README.md)
- [ZAP/seguridad](evidence/zap/README.md)
- [k6](evidence/k6/README.md)
- [Pipeline](evidence/pipeline/README.md)
- [Observabilidad](evidence/observability/README.md)
- [Deployment, Swagger y Keycloak](evidence/deployment/README.md)
- [Rollback](evidence/rollback/README.md)
