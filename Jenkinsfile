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

        stage('Authenticate to Salesforce') {
            steps {
                withCredentials([
                    file(credentialsId: 'salesforce-jwt-private-key', variable: 'JWT_KEY_FILE'),
                    string(credentialsId: 'salesforce-consumer-key', variable: 'SF_CLIENT_ID'),
                    string(credentialsId: 'salesforce-username', variable: 'SF_USERNAME')
                ]) {
                   bat 'sf project deploy validate --source-dir force-app --target-org JenkinsDevOrg --test-level RunLocalTests --wait 10'
                }
            }
        }

        stage('Validate Salesforce Project') {
            steps {
                bat 'sf project deploy validate --source-dir force-app --target-org JenkinsDevOrg --test-level NoTestRun --wait 10'
            }
        }
    }
}
