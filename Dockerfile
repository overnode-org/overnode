FROM openjdk:8u121-jre-alpine

ADD target/universal/clusterlite /opt/clusterlite
ADD clusterlite.sh /opt/clusterlite
ADD version.txt /version.txt
ADD deps/terraform /opt/terraform
RUN apk update && apk add bash && chmod a+x /opt/clusterlite/bin/clusterlite && rm -Rf /var/cache/apk/*

CMD /opt/clusterlite/bin/clusterlite
