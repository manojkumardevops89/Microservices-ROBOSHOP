pipeline {
<<<<<<< HEAD
    agent any
    environment {
        AWS_REGION   = 'us-east-1'
        ECR_REGISTRY = credentials('ecr-registry')
        ECR_REPO     = 'roboshop'
        IMAGE_TAG    = "${BUILD_NUMBER}"
        CLUSTER_NAME = 'roboshop-eks-cluster'
        NAMESPACE    = 'roboshop'
        // APP_URL is fetched dynamically after K8s deploy — no credential needed
        APP_URL      = ''
    }
    stages {
        // 1. CHECKOUT
        stage('Checkout') {
            steps {
                git branch: 'main',
                    credentialsId: 'github-creds',
                    url: 'https://github.com/manojkumardevops89/Microservices-ROBOSHOP.git'
            }
        }

        // 2. BUILD
        stage('Build') {
            steps {
                sh '''
                    for svc in frontend cart user payment; do
                        (cd services/$svc && npm install)
                    done
                    (cd services/shipping && mvn clean package -q)
                    for svc in catalogue dispatch; do
                        (cd services/$svc && go build ./...)
                    done
                '''
            }
        }

        // 3. SONARQUBE
        stage('SonarQube Scanner') {
            steps {
                withSonarQubeEnv('SonarQube-Server') {
                    sh '''
                        sonar-scanner \
                          -Dsonar.projectKey=roboshop \
                          -Dsonar.sources=services \
                          -Dsonar.java.binaries=services/shipping/target/classes
                    '''
                }
                timeout(time: 2, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        // 4. DOCKER BUILD
        stage('Docker Image Build') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    sh """
                        aws ecr get-login-password --region ${AWS_REGION} \
                          | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                        for svc in frontend cart user payment; do
                            docker build -t ${ECR_REGISTRY}/${ECR_REPO}/\$svc:${IMAGE_TAG} \
                                -f docker/nodejs.Dockerfile services/\$svc
                        done
                        docker build -t ${ECR_REGISTRY}/${ECR_REPO}/shipping:${IMAGE_TAG} \
                            -f docker/java.Dockerfile services/shipping
                        for svc in catalogue dispatch; do
                            docker build -t ${ECR_REGISTRY}/${ECR_REPO}/\$svc:${IMAGE_TAG} \
                                -f docker/golang.Dockerfile services/\$svc
                        done
                    """
                }
            }
        }

        // 5. TRIVY
        stage('Trivy Scanner') {
            steps {
                sh """
                    for svc in frontend cart user payment shipping catalogue dispatch; do
                        trivy image --severity CRITICAL,HIGH --exit-code 1 \
                        ${ECR_REGISTRY}/${ECR_REPO}/\$svc:${IMAGE_TAG}
                    done
                """
            }
        }

        // 6. PUSH TO ECR
        stage('ECR Push') {
            steps {
                sh """
                    for svc in frontend cart user payment shipping catalogue dispatch; do
                        docker push ${ECR_REGISTRY}/${ECR_REPO}/\$svc:${IMAGE_TAG}
                    done
                """
            }
        }

        // 7. TERRAFORM
        stage('Terraform') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    dir('Terraform') {
                        sh '''
                            terraform init
                            terraform plan
                            terraform apply -auto-approve
                        '''
                    }
                }
            }
        }

        // 8. K8S DEPLOY
        stage('K8s Deploy') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    sh """
                        aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}
                        for svc in frontend cart user payment shipping catalogue dispatch; do
                            helm upgrade --install \$svc helm/\$svc \
                                --namespace ${NAMESPACE} --create-namespace \
                                --set image.repository=${ECR_REGISTRY}/${ECR_REPO}/\$svc \
                                --set image.tag=${IMAGE_TAG} \
                                --atomic --timeout 5m
                        done
                        kubectl apply -f kubernetes/ingress.yaml -n ${NAMESPACE}
                    """

                    // Dynamically fetch LoadBalancer URL after deployment
                    script {
                        echo "Waiting for Ingress LoadBalancer URL to be assigned..."
                        def appUrl = ''
                        for (int i = 1; i <= 20; i++) {
                            appUrl = sh(
                                script: """
                                    kubectl get ingress -n ${NAMESPACE} \
                                        -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true
                                """,
                                returnStdout: true
                            ).trim()

                            if (appUrl) {
                                echo "LoadBalancer URL found: http://${appUrl}"
                                env.APP_URL = "http://${appUrl}"
                                break
                            }

                            if (i == 20) {
                                echo "WARNING: LoadBalancer URL not assigned after 5 minutes. Skipping OWASP scan."
                            } else {
                                echo "Attempt ${i}/20 — URL not ready yet. Retrying in 15 seconds..."
                                sleep(15)
                            }
                        }
                    }
                }
            }
        }

        // 9. OWASP ZAP — skipped automatically if APP_URL not available
        stage('OWASP Scanner') {
            steps {
                script {
                    if (!env.APP_URL || env.APP_URL.trim() == '') {
                        echo "APP_URL is not set. Skipping OWASP ZAP scan."
                    } else {
                        echo "Running OWASP ZAP scan against: ${env.APP_URL}"
                        sh """
                            docker run --rm \
                                -v \$(pwd)/zap-reports:/zap/wrk/:rw \
                                ghcr.io/zaproxy/zaproxy:stable \
                                zap-baseline.py -t ${env.APP_URL} -r zap-report.html -I
                        """
                    }
                }
            }
        }

        // 10. PROWLER
        stage('Prowler') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    sh """
                        prowler aws --region ${AWS_REGION} \
                            --services iam s3 eks ec2 \
                            --severity high critical
                    """
                }
            }
        }

        // 11. MONITORING (PROMETHEUS + GRAFANA)
        stage('Monitoring - Prometheus & Grafana') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    sh """
                        aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}
                        helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
                        helm repo update
                        helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
                            --namespace monitoring \
                            --create-namespace \
                            --wait --timeout 10m
                        kubectl patch svc monitoring-grafana \
                            -n monitoring \
                            -p '{"spec": {"type": "LoadBalancer"}}'
                    """
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline SUCCESS — Build #${BUILD_NUMBER}"
        }
        failure {
            echo "Pipeline FAILED — Build #${BUILD_NUMBER}"
        }
        always {
            script {
                cleanWs()
            }
        }
    }
}
=======
    agent { label 'AGENT-1' }
    environment { 
        PROJECT = 'expense'
        COMPONENT = 'frontend'
        appVersion = ''
        ACC_ID = '315069654700'
    }
    options {
        disableConcurrentBuilds()
        timeout(time: 30, unit: 'MINUTES')
    }
    parameters{
        booleanParam(name: 'deploy', defaultValue: false, description: 'Toggle this value')
    }
    stages {
        stage('Read Version') {
            steps {
               script{
                 def packageJson = readJSON file: 'package.json'
                 appVersion = packageJson.version
                 echo "Version is: $appVersion"
               }
            }
        }
        
        stage('Docker Build') {
            steps {
               script{
                withAWS(region: 'us-east-1', credentials: 'aws-creds') {
                    sh """
                    aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${ACC_ID}.dkr.ecr.us-east-1.amazonaws.com

                    docker build -t  ${ACC_ID}.dkr.ecr.us-east-1.amazonaws.com/${project}/${component}:${appVersion} .

                    docker push ${ACC_ID}.dkr.ecr.us-east-1.amazonaws.com/${project}/${component}:${appVersion}
                    """
                }
                 
               }
            }
        }
        stage('Trigger Deploy'){
            when { 
                expression { params.deploy }
            }
            steps{
                build job: 'frontend-cd', parameters: [string(name: 'version', value: "${appVersion}")], wait: true
            }
        }
    }
    post { 
        always { 
            echo 'I will always say Hello again!'
            deleteDir()
        }
        failure { 
            echo 'I will run when pipeline is failed'
        }
        success { 
            echo 'I will run when pipeline is success'
        }
    }
}
