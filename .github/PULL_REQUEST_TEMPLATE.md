## Resumen

<!-- Explica qué cambia y por qué. -->

## Issue

Closes #

## Cambios realizados

- <!-- Cambio principal. -->

## Pruebas

<!-- Separa quality gates previos al despliegue de pruebas post-deploy. -->

| Tipo | Comando o workflow | Resultado | Enlace o artifact |
| --- | --- | --- | --- |
| Pre-deploy |  |  |  |
| Post-deploy |  |  |  |

## Evidencia de staging

<!--
Completar solo cuando aplique staging. No pegar secretos.
Rutas admitidas por el workflow: PR -> develop, PR staging -> main,
push staging o workflow_dispatch.
-->

- Run de GitHub Actions:
- Trigger y ramas/ref:
- `DEPLOYED_SHA` según `deployment.json`:
- Artifact `test-results-staging-post-deploy-<DEPLOYED_SHA>-<run_attempt>`:
- Ciclo de vida y visibilidad:
- Resultado de las siete fases, incluida `evidence-safety`:
- Confirmación de safety `PASS` posterior a la última recolección:
- Captura PNG controlada o reporte JUnit principal:

## Seguridad y secretos

- [ ] No se añadieron contraseñas, tokens, archivos `.env`,
      `.staging/staging.env` ni realms renderizados.
- [ ] `Secret Scanning / Gitleaks` terminó en `PASS` para el SHA del PR.
- [ ] Si una credencial estuvo expuesta, adjunté constancia redactada de
      revocación o rotación sin mostrar su valor.
- [ ] Los pipelines afectados funcionan con credenciales externas.
- [ ] El artifact solo se publicó después del safety recursivo `PASS`.
- [ ] La evidencia E2E no contiene HTML, traces, videos ni HAR y superó el
      verificador de artifacts aplicable.
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
