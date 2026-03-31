FROM mongo:7.0                     # Uses official MongoDB 7.0 image as base

COPY *.js /docker-entrypoint-initdb.d/   # Copies all .js files to init directory (auto executed during container startup)
