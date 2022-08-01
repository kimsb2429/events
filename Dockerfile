FROM debezium/example-mysql:1.6
ENV MYSQL_DATABASE tweetdata
COPY ./sql/ /docker-entrypoint-initdb.d/