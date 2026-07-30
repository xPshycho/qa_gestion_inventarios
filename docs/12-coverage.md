# Coverage

## Herramientas y gates

| Suite | Herramienta | Gate real |
|---|---|---:|
| Backend unit | JaCoCo 0.8.12 | líneas >= 90 % |
| Backend integración | JaCoCo 0.8.12 | líneas >= 60 % |
| Frontend unit | Karma Coverage | statements 80 %, branches 70 %, functions 80 %, lines 80 % |

Ruta: `backend/build.gradle`\
Líneas aproximadas: 143-207\
Componente: reportes y verification rules JaCoCo\
Responsabilidad: genera XML/HTML y hace fallar Gradle bajo los límites. Sonar
consume ambos XML en líneas 210-217.

Ruta: `frontend/karma.conf.js`\
Líneas aproximadas: 21-36\
Componente: `coverageReporter`\
Responsabilidad: gate global y salidas HTML/JSON summary/text.

## Resultados generados

Fecha UTC: 30 de julio de 2026.

| Suite | Statements/instructions | Branches | Functions/methods | Lines | Gate |
|---|---:|---:|---:|---:|---|
| Backend unit | 92.13 % instructions | 81.25 % | 91.36 % methods | 90.97 % (735/808) | PASS |
| Backend integración | 56.24 % instructions | 33.12 % | 56.79 % methods | 60.52 % (489/808) | PASS |
| Frontend unit | 83.94 % (622/741) | 70.46 % (167/237) | 84.93 % (186/219) | 83.63 % (598/715) | PASS |

No sumar unit e integración manualmente: Sonar ingiere ambos execution
reports y aplica su propio modelo.

## Comandos

`Verificado · backend`

```bash
cd backend
GRADLE_USER_HOME="$PWD/.gradle" \
  ../scripts/testing/run_with_java_21.sh \
  ./gradlew test jacocoTestReport \
  jacocoTestCoverageVerification --no-daemon
```

`Verificado · backend integración · requiere Docker`

```bash
cd backend
GRADLE_USER_HOME="$PWD/.gradle" \
  ../scripts/testing/run_with_java_21.sh \
  ./gradlew integrationTest jacocoIntegrationTestReport \
  jacocoIntegrationTestCoverageVerification --no-daemon
```

`Verificado · frontend · desde raíz`

```bash
./frontend/scripts/test-local.sh
```

## Reportes

| Resultado | Ruta local |
|---|---|
| Unit backend HTML | `backend/build/reports/jacoco/test/html/index.html` |
| Unit backend XML | `backend/build/reports/jacoco/test/jacocoTestReport.xml` |
| Integración HTML | `backend/build/reports/jacoco/integrationTest/html/index.html` |
| Integración XML | `backend/build/reports/jacoco/integrationTest/jacocoIntegrationTestReport.xml` |
| Frontend HTML | `frontend/coverage/qa-gestion-inventarios-frontend/index.html` |

`Verificado localmente`

```bash
python3 -m http.server 8765 --directory backend/build/reports/jacoco/test/html
# Abrir http://127.0.0.1:8765/
```

Detener con Ctrl-C. No publicar HTML autenticado; coverage es código, no datos
de usuario.

## Brechas relevantes

- Branch coverage de integración (33.12 %) es baja aunque el gate de líneas
  aprueba.
- La cercanía del backend unit line gate (90.97 % frente a 90 %) deja poco
  margen ante código nuevo sin pruebas.
- Revisar módulos con rojo en HTML antes de aumentar thresholds.
- El README histórico indicaba 60 % para backend unit; la fuente actual exige
  90 %. Este documento y `build.gradle` son la referencia vigente.

## Pipeline

GitHub Actions publica resultados bajo el artifact
`test-results-backend-unit-*`/integración y SonarCloud consume XML. La
disponibilidad/retención de un run remoto específico no se verificó en esta
auditoría: consultar el run de GitHub correspondiente. Jenkins actual no
publica frontend coverage y su cobertura integral se describe como brecha.
