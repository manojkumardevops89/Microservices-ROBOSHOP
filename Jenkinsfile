pipeline {
    agent any
    environment {
        PATH             = "/opt/sonar-scanner/bin:${env.PATH}"
        AWS_REGION       = 'us-east-1'
        ECR_REGISTRY     = credentials('ecr-registry')
        ECR_REPO         = 'roboshop'
        IMAGE_TAG        = "${BUILD_NUMBER}"
        CLUSTER_NAME     = 'roboshop-eks-cluster'
        NAMESPACE        = 'roboshop'
        APP_URL          = ''
        SONAR_AUTH_TOKEN = credentials('sonar-token')
    }
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main',
                    credentialsId: 'github-creds',
                    url: 'https://github.com/manojkumardevops89/Microservices-ROBOSHOP.git'
            }
        }
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
        stage('Create ECR Repositories') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    sh """
                        aws ecr describe-repositories --repository-names ${ECR_REPO}/cart --region ${AWS_REGION} 2>/dev/null || \
                        aws ecr create-repository --repository-name ${ECR_REPO}/cart --region ${AWS_REGION}
                        aws ecr describe-repositories --repository-names ${ECR_REPO}/catalogue --region ${AWS_REGION} 2>/dev/null || \
                        aws ecr create-repository --repository-name ${ECR_REPO}/catalogue --region ${AWS_REGION}
                        aws ecr describe-repositories --repository-names ${ECR_REPO}/user --region ${AWS_REGION} 2>/dev/null || \
                        aws ecr create-repository --repository-name ${ECR_REPO}/user --region ${AWS_REGION}
                        aws ecr describe-repositories --repository-names ${ECR_REPO}/shipping --region ${AWS_REGION} 2>/dev/null || \
                        aws ecr create-repository --repository-name ${ECR_REPO}/shipping --region ${AWS_REGION}
                        aws ecr describe-repositories --repository-names ${ECR_REPO}/frontend --region ${AWS_REGION} 2>/dev/null || \
                        aws ecr create-repository --repository-name ${ECR_REPO}/frontend --region ${AWS_REGION}
                    """
                }
            }
        }
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
        stage('Deploy to EKS') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-credentials']]) {
                    sh """
                        aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}
                        helm upgrade --install cart helm/cart \
                            --namespace ${NAMESPACE} --create-namespace \
                            --set image.repository=${ECR_REGISTRY}/${ECR_REPO}/cart \
                            --set image.tag=${IMAGE_TAG}
                        helm upgrade --install catalogue helm/catalogue \
                            --namespace ${NAMESPACE} \
                            --set image.repository=${ECR_REGISTRY}/${ECR_REPO}/catalogue \
                            --set image.tag=${IMAGE_TAG}
                        helm upgrade --install user helm/user \
                            --namespace ${NAMESPACE} \
                            --set image.repository=${ECR_REGISTRY}/${ECR_REPO}/user \
                            --set image.tag=${IMAGE_TAG}
                        helm upgrade --install shipping helm/shipping \
                            --namespace ${NAMESPACE} \
                            --set image.repository=${ECR_REGISTRY}/${ECR_REPO}/shipping \
                            --set image.tag=${IMAGE_TAG}
                        helm upgrade --install frontend helm/frontend \
                            --namespace ${NAMESPACE} \
                            --set image.repository=${ECR_REGISTRY}/${ECR_REPO}/frontend \
                            --set image.tag=${IMAGE_TAG}
                    """
                }
            }
        }
    }
    post {
        success {
            echo "Pipeline SUCCESS - Build #${BUILD_NUMBER}"
        }
        failure {
            echo "Pipeline FAILED - Build #${BUILD_NUMBER}"
        }
    }
}
