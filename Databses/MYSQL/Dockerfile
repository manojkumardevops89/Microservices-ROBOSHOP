FROM mysql:8.0                     # Uses official MySQL 8.0 image as base

ENV MYSQL_ROOT_PASSWORD=RoboShop@1   # Sets root user password for MySQL

ENV MYSQL_DATABASE=roboshop       # Creates a database named 'roboshop' at startup

COPY *.sql /docker-entrypoint-initdb.d/   # Copies all .sql files to init directory (auto executed during container startup)
