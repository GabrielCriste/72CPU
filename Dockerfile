
# Stage 1: Base image with Java, sbt, and Scala
FROM amazoncorretto:17 AS scala-sbt

# Define arguments for Scala and sbt versions
ARG SCALA_VERSION=3.3.4
ARG SBT_VERSION=1.10.5

# Install sbt
RUN yum -y update && yum -y install tar gzip procps curl && \
    curl -fsL "https://github.com/sbt/sbt/releases/download/v$SBT_VERSION/sbt-$SBT_VERSION.tgz" | \
    tar xfz - -C /usr/share && \
    ln -s /usr/share/sbt/bin/sbt /usr/local/bin/sbt

# Install Scala
RUN curl -fsL "https://github.com/scala/scala3/releases/download/v$SCALA_VERSION/scala3-$SCALA_VERSION.tar.gz" | \
    tar xfz - -C /usr/share && mv /usr/share/scala3-$SCALA_VERSION /usr/share/scala && \
    ln -s /usr/share/scala/bin/* /usr/local/bin

# Stage 2: Final Jupyter image with Scala and sbt
FROM quay.io/jupyter/base-notebook:2024-12-02 AS final-stage

# Switch to root user for installation
USER root

# Copy Scala and sbt from the scala-sbt stage
COPY --from=scala-sbt /usr/share/sbt /usr/share/sbt
COPY --from=scala-sbt /usr/share/scala /usr/share/scala

# Set up symbolic links
RUN ln -s /usr/share/sbt/bin/sbt /usr/local/bin/sbt && \
    ln -s /usr/share/scala/bin/* /usr/local/bin

# Pre-warm sbt and Scala compilation
RUN mkdir -p /test && \
    echo "scalaVersion := \"3.3.4\"" > /test/build.sbt && \
    sbt -sbt-create compile

# Switch back to the default Jupyter user
USER $NB_UID

# Expose Jupyter port
EXPOSE 8888

# Set default command to start Jupyter
CMD ["start-notebook.sh"]
