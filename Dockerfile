FROM brunotm/correto-jre:8
LABEL maintainer="brunotm@gmail.com"

# Kafka and Scala versions
ENV KAFKA_VERSION=2.1.1
ENV	SCALA_VERSION=2.12
ENV KAFKA_RELEASE="kafka_${SCALA_VERSION}-${KAFKA_VERSION}"
ENV KAFKA_URL="https://archive.apache.org/dist/kafka/${KAFKA_VERSION}/${KAFKA_RELEASE}.tgz"

# Default Kafka options
ENV KAFKA_HEAP_OPTS="${JAVA_TOOL_OPTIONS} -Xmx1G -Xms1G" \
	KAFKA_CONFIG_FILE=/kafka/config/server.properties \
	KAFKA_BROKER_ID=-1 \
	KAFKA_LOG_DIRS=/kafka/data/logs \
	KAFKA_ZOOKEEPER.CONNECT=localhost:2181 \
	KAFKA_LISTENERS="" \
	KAFKA_DELETE_TOPIC_ENABLE=true \
	KAFKA_AUTO_CREATE_TOPICS_ENABLE=true \
	KAFKA_AUTO_LEADER_REBALANCE_ENABLE=true \
	KAFKA_LOG_RETENTION_HOURS=168 \
	KAFKA_JMX_PORT=8004 \
	ZOOKEEPER_ENABLE=false \
	ZOOKEEPER_CONFIG_FILE=/kafka/config/zookeeper.properties \
	ZOOKEEPER_NODE_ID=-1 \
	ZOOKEEPER_DATA_DIR=/kafka/data/zookeeper \
	ZOOKEEPER_DATA_LOG_DIR=/kafka/data/zookeeper \
	ZOOKEEPER_CLIENT_PORT=2181 \
	ZOOKEEPER_TICK_TIME=2000 \
	ZOOKEEPER_INIT_LIMIT=5 \
	ZOOKEEPER_SYNC_LIMIT=2 \
	ZOOKEEPER_MAX_CLIENT_CONN=60 \
	ZOOKEEPER_AUTO_PURGE_SNAP_RETAIN_COUNT=10 \
	ZOOKEEPER_AUTO_PURGE_INTERVAL=24 \
	ZOOKEEPER_SERVERS="" \
	ZOOKEEPER_JMX_PORT=8005

RUN set -ex \
	&& curl "${KAFKA_URL}" -o "/tmp/${KAFKA_RELEASE}.tgz" \
	&& tar xfz /tmp/${KAFKA_RELEASE}.tgz -C /tmp \
	&& mv /tmp/${KAFKA_RELEASE} /kafka \
	&& rm /tmp/${KAFKA_RELEASE}.tgz

WORKDIR /kafka
VOLUME /kafka/data

# Kafka ports
EXPOSE 9092 9093 8004

# ZooKeeper ports
EXPOSE 2181 2888 3888 8005

ADD start-kafka.sh /kafka/bin/start-kafka.sh
RUN chmod 700 /kafka/bin/start-kafka.sh
CMD ["/kafka/bin/start-kafka.sh"]
