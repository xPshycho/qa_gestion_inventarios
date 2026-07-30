# Evidencia de seguridad

- Nombre: headers, OWASP ZAP baseline y Trivy.
- Fecha: 30 de julio de 2026 UTC.
- Entorno: Compose local aislado, frontend `http://localhost:5173`.
- Comando: `./tests/security/run-local.sh`.
- Resultado: headers PASS; ZAP PASS con 0 High y cinco categorías Warning;
  Trivy PASS con 0 HIGH/CRITICAL corregible en los tres targets.
- Evidencia: `test-results/security/{headers,zap,trivy}/`.
- Interpretación: configuración básica y vulnerabilidades conocidas del
  snapshot pasan los gates.
- Requisito: security testing/DevSecOps.
- Limitaciones: ZAP pasivo/no autenticado; Trivy usa `--ignore-unfixed`; repetir
  al actualizar bases/dependencias.
