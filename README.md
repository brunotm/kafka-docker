# Apache Kafka docker image
Apache Kafka docker image with full configuration options exposed via environment
variables, optional Kafka bundled ZooKeeper node configuration and automated broker ssl certificate generation.

## Environment variables
Any Kafka configuration parameter can be used as an environment variable, with all upercase characters, dots replaced by underscores and adding the KAFKA_ prefix.

### Default Kafka environment
```bash
KAFKA_AUTO_CREATE_TOPICS_ENABLE=true
KAFKA_AUTO_LEADER_REBALANCE_ENABLE=true
KAFKA_BROKER_ID=-1
KAFKA_CONFIG_FILE=/kafka/config/server.properties
KAFKA_DELETE_TOPIC_ENABLE=true
KAFKA_HEAP_OPTS=-XX:+UseContainerSupport -Xmx1G -Xms1G
KAFKA_JMX_PORT=8004
KAFKA_LISTENERS=""
KAFKA_LOG_DIRS=/kafka/data/logs
KAFKA_LOG_RETENTION_HOURS=168
KAFKA_RELEASE=kafka_2.12-2.1.1
KAFKA_VERSION=2.1.1
KAFKA_ZOOKEEPER.CONNECT=localhost:2181
```

### Default ZooKeeper environment (enable ZooKeeper with ZOOKEEPER_ENABLE=true )
```
ZOOKEEPER_AUTO_PURGE_INTERVAL=24
ZOOKEEPER_AUTO_PURGE_SNAP_RETAIN_COUNT=10
ZOOKEEPER_CLIENT_PORT=2181
ZOOKEEPER_CONFIG_FILE=/kafka/config/zookeeper.properties
ZOOKEEPER_DATA_DIR=/kafka/data/zookeeper
ZOOKEEPER_DATA_LOG_DIR=/kafka/data/zookeeper
ZOOKEEPER_ENABLE=false
ZOOKEEPER_INIT_LIMIT=5
ZOOKEEPER_JMX_PORT=8005
ZOOKEEPER_MAX_CLIENT_CONN=60
ZOOKEEPER_NODE_ID=-1
ZOOKEEPER_SERVERS=
ZOOKEEPER_SYNC_LIMIT=2
ZOOKEEPER_TICK_TIME=2000
```

The ZOOKEEPER_SERVERS variable should be set to a space separeted list of ZooKeeper nodes for clustering purposes. E.g.:
```
ZOOKEEPER="server.1=server1:2888:3888 server.2=server2:2888:3888 server.3=server3:2888:3888"
```

## SSL and Authentication
This image can autogenerate the needed Kafka keystore, truststore and broker keys and certificates if a CA Certificate and Key location are provided through the `SSL_CA_CERT` and `SSL_CA_KEY` environment variables. Both paths must be within the container and can be added via secrets or ordinary mounts. E.g.:
```
SSL_CA_CERT=/run/secrets/ca-cert
SSL_CA_KEY=/run/secrets/ca-key
```

The broker certificate will have 365 days validity by default, which can be overriden with the `KAFKA_SSL_CRT_VALIDITY` environment variable.

Subject alternative names for both name and ip addresses will be added in the generated broker certificate for all container local names and ip addresses. Additional ones can be provided through the `SSL_SAN_DNS_NAMES` and `SSL_SAN_IP_ADDRESSES` environment variables. E.g.:
```
SSL_SAN_DNS_NAMES="service_name1,host2.domain.com,host2"
SSL_SAN_IP_ADDRESSES="192.168.0.8,10.255.0.5"
```

In order to properly configure Kafka for SSL and authentication for both client and additional brokers the following must also be configured.
```
KAFKA_SSL_CLIENT_AUTH="required"
KAFKA_SECURITY_INTER_BROKER_PROTOCOL="SSL"
KAFKA_SECURE_RANDOM_IMPLEMENTATION="SHA1PRNG"
KAFKA_SSL_ENABLED_PROTOCOLS="TLSv1.2,TLSv1.1,TLSv1"
```

## Persisting data
Both Kafka and ZooKeeper will persist data to /kafka/data which is defined as a volume in the dockerfile, so in production setups this must be taken into account.

## Misc

JMX is enabled for both Kafka on port 8004 and ZooKeeper on port 8005.

## Contact
Bruno Moura [brunotm@gmail.com](mailto:brunotm@gmail.com)

## License
Code available under the Apache Version 2.0 [License](/LICENSE)