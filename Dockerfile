FROM openjdk:8u121-jre-alpine

ADD target/universal/clusterlite /opt/clusterlite
ADD clusterlite.sh /opt/clusterlite

RUN apk update && apk add bash && chmod a+x /opt/clusterlite/bin/clusterlite

CMD /opt/clusterlite/bin/clusterlite
