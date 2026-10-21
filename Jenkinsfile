pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                echo 'GitHub checkout completed.'
            }
        }

        stage('Verify Project') {
            steps {
                bat 'sf --version'
                echo 'Salesforce CLI check completed.'
            }
        }
    }
}
