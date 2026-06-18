pipelineJob('inventory-avance-ci') {
    description('Pipeline CI reproducible para qa_gestion_inventarios. Gestionado automaticamente; no editar manualmente.')

    parameters {
        booleanParam('RUN_SONAR', false, 'Ejecutar SonarCloud. Requiere la credencial sonarcloud-token.')
    }

    definition {
        cpsScm {
            scm {
                git {
                    remote {
                        url('https://github.com/xPshycho/qa_gestion_inventarios.git')
                    }
                    branch('*/develop')
                }
            }
            scriptPath('Jenkinsfile')
            lightweight(true)
        }
    }

    disabled(false)
}
