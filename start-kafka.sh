#!/bin/bash
set -x

if [[ ! -f ${KAFKA_CONFIG_FILE} ]]; then
  echo "Config file not found, exiting!!"
  exit 1
fi

# configure ${KAFKA_CONFIG_FILE} broker.id -1
configure () {
  if [[ ! -z "$3" ]]; then
    if egrep -q "(^|^#)${2}=" ${1}; then
        sed -r -i "s@(^|^#)(${2})=(.*)@\2=${3}@g" ${1}
    else
        echo -e "\n${2}=${3}" >> ${1}
    fi
  fi
}

# Parse kafka options from environment variables.
# Options must be specified as in server.properties, capitalizing, replacing "."
# with "_" and prefixing each configuration option with "KAFKA_".
# zookeeper.connect=localhost:2181 becomes KAFKA_ZOOKEEPER.CONNECT=zookeeper:2181
blacklist="KAFKA_CONFIG_FILE KAFKA_VERSION KAFKA_RELEASE KAFKA_URL KAFKA_HEAP_OPTS KAFKA_JMX_PORT"
while IFS='=' read -r key value; do
  if [[ ${blacklist} =~ ${key} ]]; then
    continue
  fi

  key=$(echo $key|tr "[:upper:]" "[:lower:]"|tr "_" ".")
  configure ${KAFKA_CONFIG_FILE} $key $value
done < <(env|grep ^KAFKA_*|cut -d_ -f2-)


# Configure and start ZooKeeper if enabled
if [[ "$ZOOKEEPER_ENABLE" == "true" ]]; then
  mkdir -p ${ZOOKEEPER_DATA_DIR}

  if [[ ! -f "$ZOOKEEPER_DATA_DIR/myid" ]]; then
    echo "${ZOOKEEPER_NODE_ID}" > "$ZOOKEEPER_DATA_DIR/myid"
  fi

  configure ${ZOOKEEPER_CONFIG_FILE} "dataDir" "${ZOOKEEPER_DATA_DIR}"
  configure ${ZOOKEEPER_CONFIG_FILE} "dataLogDir" "${ZOOKEEPER_DATA_LOG_DIR}"
  configure ${ZOOKEEPER_CONFIG_FILE} "clientPort" "${ZOOKEEPER_CLIENT_PORT}"
  configure ${ZOOKEEPER_CONFIG_FILE} "tickTime" "${ZOOKEEPER_TICK_TIME}"
  configure ${ZOOKEEPER_CONFIG_FILE} "initLimit" "${ZOOKEEPER_INIT_LIMIT}"
  configure ${ZOOKEEPER_CONFIG_FILE} "syncLimit" "${ZOOKEEPER_SYNC_LIMIT}"
  configure ${ZOOKEEPER_CONFIG_FILE} "maxClientCnxns" "${ZOOKEEPER_MAX_CLIENT_CONN}"
  configure ${ZOOKEEPER_CONFIG_FILE} "autopurge.snapRetainCount" "${ZOOKEEPER_AUTO_PURGE_SNAP_RETAIN_COUNT}"
  configure ${ZOOKEEPER_CONFIG_FILE} "autopurge.purgeInterval" "${ZOOKEEPER_AUTO_PURGE_INTERVAL}"

  for server in $ZOOKEEPER_SERVERS; do
        echo "$server" >> "$ZOOKEEPER_CONFIG_FILE"
    done

  JMX_PORT=${ZOOKEEPER_JMX_PORT} /kafka/bin/zookeeper-server-start.sh -daemon ${ZOOKEEPER_CONFIG_FILE}

fi



# Setup SSL and TLS authentication
if [[ -n "${SSL_CA_CERT}" && -n "${SSL_CA_KEY}" ]]; then

  KAFKA_SECURITY_PATH=${KAFKA_SECURITY_PATH:-"/kafka/security"}
  KAFKA_KEYSTORE="${KAFKA_SECURITY_PATH}/${HOSTNAME}.keystore.jks"
  KAFKA_KEYSTORE_PASSWORD="${KAFKA_KEYSTORE_PASSWORD:-"secure password"}"
  KAFKA_TRUSTSTORE="${KAFKA_SECURITY_PATH}/${HOSTNAME}.truststore.jks"
  KAFKA_SSL_CSR="${KAFKA_SECURITY_PATH}/${HOSTNAME}.csr"
  KAFKA_SSL_CRT="${KAFKA_SECURITY_PATH}/${HOSTNAME}.crt"
  KAFKA_SSL_CRT_VALIDITY="${KAFKA_SSL_CRT_VALIDITY:-365}"

  mkdir -p ${KAFKA_SECURITY_PATH}

  # Add supplied names to our subject alternative names
  # from SSL_SAN_IP_ADDRESSES
  cnt=1
  FULL_SSL_DNS_NAMES="DNS.${cnt}:${HOSTNAME}"
  for name in $(echo $SSL_SAN_DNS_NAMES|tr "," " "); do
    cnt=$(($cnt+1))
    FULL_SSL_DNS_NAMES="${FULL_SSL_DNS_NAMES},DNS.${cnt}:${name}"
  done

  # Add all local ip addresses to our subject alternative names
  cnt=1
  FULL_SSL_IP_ADDRESSES="IP.${cnt}:127.0.0.1"
  for addr in $(ip addr list|awk '/inet/ {print $2}'|grep -v "127.0.0.1"); do
    cnt=$(($cnt+1))
    FULL_SSL_IP_ADDRESSES="${FULL_SSL_IP_ADDRESSES},IP.${cnt}:${addr%/*}"
  done

  # Add supplied ip addresses to our subject alternative names
  # from SSL_SAN_IP_ADDRESSES
  for addr in $(echo $SSL_SAN_IP_ADDRESSES|tr "," " "); do
    cnt=$(($cnt+1))
    SSL_IP_ADDRESSES="${FULL_SSL_IP_ADDRESSES},IP.${cnt}:${addr}"
  done

  # Generate broker keystore
  keytool -genkey -noprompt \
    -alias localhost \
    -validity 3650 \
    -dname "CN=${HOSTNAME}" \
    -ext SAN=${FULL_SSL_DNS_NAMES},${FULL_SSL_IP_ADDRESSES} \
    -keyalg RSA \
    -keystore ${KAFKA_KEYSTORE} \
    -storepass ${KAFKA_KEYSTORE_PASSWORD} \
    -keypass ${KAFKA_KEYSTORE_PASSWORD}

  # Generate broker CSR
  keytool -certreq -noprompt \
  -keystore ${KAFKA_KEYSTORE} \
  -alias localhost \
  -file ${KAFKA_SSL_CSR} \
  -storepass ${KAFKA_KEYSTORE_PASSWORD} \
  -keypass ${KAFKA_KEYSTORE_PASSWORD}

  # Sign broker certificate
  openssl x509 -req \
    -CA ${SSL_CA_CERT} \
    -CAkey ${SSL_CA_KEY} \
    -in ${KAFKA_SSL_CSR} \
    -out ${KAFKA_SSL_CRT} \
    -days 3650 \
    -CAcreateserial

  # Import CA and broker certificates
  keytool -import -noprompt \
    -keystore ${KAFKA_KEYSTORE} \
    -alias CARoot \
    -file ${SSL_CA_CERT} \
    -storepass ${KAFKA_KEYSTORE_PASSWORD}

  keytool -import -noprompt \
    -keystore ${KAFKA_KEYSTORE} \
    -alias localhost \
    -file ${KAFKA_SSL_CRT} \
    -storepass ${KAFKA_KEYSTORE_PASSWORD}

  # Import given CA certificate to the server truststore
  keytool -import -noprompt \
  -keystore ${KAFKA_TRUSTSTORE} \
  -alias CARoot \
  -file ${SSL_CA_CERT} \
  -storepass ${KAFKA_KEYSTORE_PASSWORD}

  configure ${KAFKA_CONFIG_FILE} "ssl.keystore.location" "${KAFKA_KEYSTORE}"
  configure ${KAFKA_CONFIG_FILE} "ssl.keystore.password" "${KAFKA_KEYSTORE_PASSWORD}"
  configure ${KAFKA_CONFIG_FILE} "ssl.key.password" "${KAFKA_KEYSTORE_PASSWORD}"
  configure ${KAFKA_CONFIG_FILE} "ssl.truststore.location" "${KAFKA_TRUSTSTORE}"
  configure ${KAFKA_CONFIG_FILE} "ssl.truststore.password" "${KAFKA_KEYSTORE_PASSWORD}"
  # configure ${KAFKA_CONFIG_FILE} "ssl.client.auth" "required"
  # configure ${KAFKA_CONFIG_FILE} "security.inter.broker.protocol" "SSL"
  # configure ${KAFKA_CONFIG_FILE} "ssl.secure.random.implementation" "SHA1PRNG"
  # configure ${KAFKA_CONFIG_FILE} "ssl.enabled.protocols" "TLSv1.2,TLSv1.1,TLSv1"

fi

# Stop ZooKeeper node if enabled
if [[ "$ZOOKEEPER_ENABLE" == "true" ]]; then
  trap /kafka/bin/zookeeper-server-stop.sh SIGKILL SIGTERM SIGHUP SIGINT EXIT
fi

exec env JMX_PORT=${KAFKA_JMX_PORT} /kafka/bin/kafka-server-start.sh ${KAFKA_CONFIG_FILE}