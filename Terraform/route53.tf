pipeline {
    agent any

    environment {
        AWS_REGION   = 'us-east-1'
        ECR_REGISTRY = credentials('ecr-registry')
        ECR_REPO     = 'roboshop'
        IMAGE_TAG    = "${BUILD_NUMBER}"
        CLUSTER_NAME = 'roboshop-eks-cluster'
        NAMESPACE    = 'roboshop'
        APP_URL      = ''
        SONAR_AUTH_TOKEN = credentials('sonar-token')
        HOSTED_ZONE_ID = 'Z02341861LTO0U4VXW9AM'   // ✅ UPDATED
    }

    stages {

        // 🔹 1. CHECKOUT
        stage('Checkout') {
            steps {
                git branch: 'main',
                    credentialsId: 'github-creds',
                    url: 'https://github.com/manojkumardevops89/Microservices-ROBOSHOP.git'
            }
        }

        // 🔹 2. SONARQUBE
        stage('SonarQube Scan') {
            steps {
                withSonarQubeEnv('SonarQube-Server') {
                    sh '''
                        sonar-scanner \
                          -Dsonar.projectKey=roboshop \
                          -Dsonar.projectName=roboshop \
                          -Dsonar.sources=services \
                          -Dsonar.host.url=http://52.66.83.222:9000 \
                          -Dsonar.login=$SONAR_AUTH_TOKEN
                    '''
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        // 🔹 3. TERRAFORM
        stage('Terraform Init') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    dir('Terraform') {
                        sh 'terraform init'
                    }
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    dir('Terraform') {
                        sh 'terraform plan'
                    }
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    dir('Terraform') {
                        sh 'terraform apply -auto-approve'
                    }
                }
            }
        }

        // 🔹 4. BUILD
        stage('Build Services') {
            steps {
                sh '''
                    cd services/cart && npm install
                    cd ../catalogue && npm install
                    cd ../user && npm install
                    cd ../shipping && mvn clean package
                '''
            }
        }

        // 🔹 5. CREATE ECR
        stage('Create ECR Repositories') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    sh """
                        aws ecr describe-repositories --repository-names ${ECR_REPO}/cart --region ${AWS_REGION} || \
                        aws ecr create-repository --repository-name ${ECR_REPO}/cart --region ${AWS_REGION}

                        aws ecr describe-repositories --repository-names ${ECR_REPO}/catalogue --region ${AWS_REGION} || \
                        aws ecr create-repository --repository-name ${ECR_REPO}/catalogue --region ${AWS_REGION}

                        aws ecr describe-repositories --repository-names ${ECR_REPO}/user --region ${AWS_REGION} || \
                        aws ecr create-repository --repository-name ${ECR_REPO}/user --region ${AWS_REGION}

                        aws ecr describe-repositories --repository-names ${ECR_REPO}/shipping --region ${AWS_REGION} || \
                        aws ecr create-repository --repository-name ${ECR_REPO}/shipping --region ${AWS_REGION}

                        aws ecr describe-repositories --repository-names ${ECR_REPO}/frontend --region ${AWS_REGION} || \
                        aws ecr create-repository --repository-name ${ECR_REPO}/frontend --region ${AWS_REGION}
                    """
                }
            }
        }

        // 🔹 6. DOCKER BUILD
        stage('Docker Build') {
            steps {
                sh """
                    docker build -t ${ECR_REGISTRY}/${ECR_REPO}/cart:${IMAGE_TAG} -f docker/nodejs.Dockerfile services/cart
                    docker build -t ${ECR_REGISTRY}/${ECR_REPO}/catalogue:${IMAGE_TAG} -f docker/nodejs.Dockerfile services/catalogue
                    docker build -t ${ECR_REGISTRY}/${ECR_REPO}/user:${IMAGE_TAG} -f docker/nodejs.Dockerfile services/user
                    docker build -t ${ECR_REGISTRY}/${ECR_REPO}/shipping:${IMAGE_TAG} -f docker/java.Dockerfile services/shipping
                    docker build -t ${ECR_REGISTRY}/${ECR_REPO}/frontend:${IMAGE_TAG} -f docker/nginx.Dockerfile services/frontend
                """
            }
        }

        // 🔹 7. TRIVY
        stage('Trivy Scan') {
            steps {
                sh """
                    trivy image --severity CRITICAL,HIGH --exit-code 1 ${ECR_REGISTRY}/${ECR_REPO}/cart:${IMAGE_TAG}
                """
            }
        }

        // 🔹 8. PUSH TO ECR
        stage('Push Images') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    sh """
                        aws ecr get-login-password --region ${AWS_REGION} \
                        | docker login --username AWS --password-stdin ${ECR_REGISTRY}

                        docker push ${ECR_REGISTRY}/${ECR_REPO}/cart:${IMAGE_TAG}
                        docker push ${ECR_REGISTRY}/${ECR_REPO}/catalogue:${IMAGE_TAG}
                        docker push ${ECR_REGISTRY}/${ECR_REPO}/user:${IMAGE_TAG}
                        docker push ${ECR_REGISTRY}/${ECR_REPO}/shipping:${IMAGE_TAG}
                        docker push ${ECR_REGISTRY}/${ECR_REPO}/frontend:${IMAGE_TAG}
                    """
                }
            }
        }

        // 🔹 9. DEPLOY TO EKS
        stage('Deploy to EKS') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    sh """
                        aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}

                        helm upgrade --install frontend helm/frontend \
                            --namespace ${NAMESPACE} --create-namespace \
                            --set image.repository=${ECR_REGISTRY}/${ECR_REPO}/frontend \
                            --set image.tag=${IMAGE_TAG}
                    """

                    script {
                        echo "Fetching ALB DNS..."
                        def appUrl = sh(
                            script: "kubectl get ingress -n ${NAMESPACE} -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'",
                            returnStdout: true
                        ).trim()

                        env.APP_URL = "http://${appUrl}"
                        echo "APP URL: ${env.APP_URL}"
                    }
                }
            }
        }

        // 🔥 10. ROUTE53
        stage('Create Route53 Record') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    sh """
                        ALB_DNS=\$(echo ${APP_URL} | sed 's|http://||')

                        aws route53 change-resource-record-sets \
                          --hosted-zone-id ${HOSTED_ZONE_ID} \
                          --change-batch '{
                            "Changes": [{
                              "Action": "UPSERT",
                              "ResourceRecordSet": {
                                "Name": "roboshop.manojdevops897.shop",
                                "Type": "CNAME",
                                "TTL": 60,
                                "ResourceRecords": [{"Value": "'"\$ALB_DNS"'"}]
                              }
                            }]
                          }'
                    """
                }
            }
        }

        // 🔹 11. PROWLER
        stage('Prowler Scan') {
            steps {
                sh """
                    prowler aws --region ${AWS_REGION} --severity high critical
                """
            }
        }
    }

    post {
        success {
            echo "Pipeline SUCCESS"
        }
        failure {
            echo "Pipeline FAILED"
        }
    }
}
