FROM phusion/baseimage:0.9.18

CMD ["/sbin/my_init"]

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends wget unzip git openjdk-7-jdk maven build-essential

RUN mkdir /app/

WORKDIR /app/

RUN wget http://www1.nyc.gov/assets/planning/download/zip/data-maps/open-data/gdelx16b.zip \
    && unzip gdelx16b.zip \
    && rm gdelx16b.zip

ENV GEOSUPPORT_HOME=/app/version-16b_16.2 \
    JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64/
ENV LD_LIBRARY_PATH=$GEOSUPPORT_HOME/lib/ \
    GEOFILES=$GEOSUPPORT_HOME/fls/ \
    GS_INCLUDE_PATH=$GEOSUPPORT_HOME/include/foruser \
    GS_LIBRARY_PATH=$GEOSUPPORT_HOME/lib


RUN git clone https://github.com/bhagyas/spring-jsonp-support \
    && ( cd spring-jsonp-support \
         && mvn -Dmaven.compiler.source=1.7 -Dmaven.compiler.target=1.7 install ) \
    && rm -rf spring-jsonp-support

COPY geoclient-build.patch .

RUN git clone https://github.com/CityOfNewYork/geoclient.git \
    && ( cd geoclient \
         && git checkout dev \
         && patch -p1 < /app/geoclient-build.patch \
         && ./gradlew build -x test )

RUN wget http://central.maven.org/maven2/com/github/jsimone/webapp-runner/7.0.57.2/webapp-runner-7.0.57.2.jar

RUN DEBIAN_FRONTEND=noninteractive apt-get remove -y unzip wget git openjdk-7-jdk maven build-essential \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends openjdk-7-jre-headless \
    && DEBIAN_FRONTEND=noninteractive apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /root/.m2 root/.gradle

RUN mkdir /etc/service/tomcat
ADD tomcat.sh /etc/service/tomcat/run
RUN chmod +x /etc/service/tomcat/run