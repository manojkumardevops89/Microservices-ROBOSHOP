FROM mysql:8.0

ENV MYSQL_ROOT_PASSWORD=RoboShop@1
ENV MYSQL_DATABASE=roboshop

COPY *.sql /docker-entrypoint-initdb.d/
