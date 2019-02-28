FROM brunotm/correto-jre:8
LABEL maintainer="brunotm@gmail.com"

ENV KAFKA_VERSION 2.1.1
ENV SCALA_VERSION 2.12
ENV KAFKA_JMX_PORT 8004
ENV KAFKA_RELEASE="kafka_${SCALA_VERSION}-${KAFKA_VERSION}"
ENV KAFKA_URL="https://archive.apache.org/dist/kafka/${KAFKA_VERSION}/${KAFKA_RELEASE}.tgz"

RUN set -x \
	&& curl "${KAFKA_URL}" -o "/tmp/${KAFKA_RELEASE}.tgz" \
	&& tar xfz /tmp/${KAFKA_RELEASE}.tgz -C /tmp \
	&& mv /tmp/${KAFKA_RELEASE} /kafka \
	&& rm /tmp/${KAFKA_RELEASE}.tgz

VOLUME /kafka/logs
WORKDIR /kafka
EXPOSE 9092 9093 8004

ADD start-kafka.sh /kafka/bin/start-kafka.sh
RUN chmod 700 /kafka/bin/start-kafka.sh
CMD ["/kafka/bin/start-kafka.sh"]
