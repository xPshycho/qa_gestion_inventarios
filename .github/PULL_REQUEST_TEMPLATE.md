## Resumen

<!-- Explica qué cambia y por qué. -->

## Issue

Closes #

## Cambios realizados

- <!-- Cambio principal. -->

## Pruebas

<!-- Separa quality gates previos al despliegue de pruebas post-deploy. -->

| Tipo | Comando o workflow | Resultado |
| --- | --- | --- |
| Pre-deploy |  |  |
| Post-deploy |  |  |

## Evidencia de staging

<!--
Completar solo cuando aplique staging. No pegar secretos.
Rutas admitidas por el workflow: PR -> develop, PR staging -> main,
push staging o workflow_dispatch.
-->

- Run de GitHub Actions:
- Trigger y ramas/ref:
- `DEPLOYED_SHA` según `deployment.json`:
- Artifact `staging-evidence-<DEPLOYED_SHA>-<run_attempt>`:
- Ciclo de vida y visibilidad:
- Resultado de las siete fases, incluida `evidence-safety`:
- Confirmación de safety `PASS` posterior a la última recolección:
- Captura PNG controlada o reporte JUnit principal:

## Seguridad y secretos

- [ ] No se añadieron contraseñas, tokens, `.staging/staging.env` ni realms
      renderizados.
- [ ] El artifact solo se publicó después del safety recursivo `PASS`.
- [ ] La evidencia no contiene HTML, traces, videos ni HAR de Playwright
      staging.
- [ ] Los cambios de permisos, puertos o exposición de red están explicados.

## Checklist

- [ ] El issue está enlazado con `Closes #...`.
- [ ] Los commits siguen Conventional Commits.
- [ ] Ejecuté las pruebas aplicables y documenté sus resultados.
- [ ] Actualicé la documentación afectada.
- [ ] La evidencia corresponde al SHA que se propone promover.
- [ ] Si el destino es `main`, la rama origen es exactamente `staging`.
- [ ] Las afirmaciones sobre staging distinguen runner privado, host local y URL
      pública.
- [ ] Solicité revisión cruzada a otro integrante.
