FROM tomcat:7.0.70-jre7

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends wget unzip git openjdk-7-jdk maven build-essential

RUN mkdir /app/

WORKDIR /app/

# Get the latest Geosupport
RUN wget http://www1.nyc.gov/assets/planning/download/zip/data-maps/open-data/gdelx16b.zip \
    && unzip gdelx16b.zip \
    && rm gdelx16b.zip

# Set some paths
ENV GEOSUPPORT_HOME=/app/version-16b_16.2 \
    JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64/
ENV LD_LIBRARY_PATH=$GEOSUPPORT_HOME/lib/ \
    GEOFILES=$GEOSUPPORT_HOME/fls/ \
    GS_INCLUDE_PATH=$GEOSUPPORT_HOME/include/foruser \
    GS_LIBRARY_PATH=$GEOSUPPORT_HOME/lib

# Install JSONP support
RUN git clone https://github.com/bhagyas/spring-jsonp-support \
    && ( cd spring-jsonp-support \
         && mvn -Dmaven.compiler.source=1.7 -Dmaven.compiler.target=1.7 install ) \
    && rm -rf spring-jsonp-support

# Patch & build the Geoclient from master
COPY geoclient-build.patch .
RUN git clone https://github.com/CityOfNewYork/geoclient.git \
    && ( cd geoclient \
         && git checkout master \
         && patch -p1 < /app/geoclient-build.patch \
         && ./gradlew build -x test )

# Cleanup unused files
RUN DEBIAN_FRONTEND=noninteractive apt-get remove -y unzip wget git openjdk-7-jdk maven build-essential \
    && DEBIAN_FRONTEND=noninteractive apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /root/.m2 root/.gradle

# Setup Tomcat to link to our native library
ENV CATALINA_OPTS=-Djava.library.path=/usr/lib/jni/:$LD_LIBRARY_PATH:/app/geoclient/build/libs/

# Replace default Tomcat web application with Geoclient
RUN rm -rf $CATALINA_HOME/webapps/ROOT
RUN cp /app/geoclient/geoclient-service/build/libs/geoclient-service-2.0.0-SNAPSHOT.war $CATALINA_HOME/webapps/ROOT.war