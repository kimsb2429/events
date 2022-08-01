FROM debezium/example-mysql:1.5
ENV MYSQL_DATABASE tweetdata
COPY ./sql/ /docker-entrypoint-initdb.d/