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
                    bat '''
                    sf org login jwt --client-id "%SF_CLIENT_ID%" --jwt-key-file "%JWT_KEY_FILE%" --username "%SF_USERNAME%" --instance-url https://login.salesforce.com --alias JenkinsDevOrg --set-default
                    sf org display --target-org JenkinsDevOrg
                    '''
                }
            }
        }
    }
}
