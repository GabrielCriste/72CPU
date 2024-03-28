# Use a multi-stage build to reduce the size of the final image
FROM eclipse-temurin:${BASE_IMAGE_TAG:-21.0.2_13-jdk-alpine} as builder

ARG SCALA_VERSION=3.4.0
ARG SBT_VERSION=1.9.9
ARG USER_ID=1001
ARG GROUP_ID=1001
ENV SCALA_HOME=/usr/share/scala

# Install scala and sbt
RUN apk add --no-cache --virtual=.build-dependencies wget ca-certificates bash curl bc && \
    cd "/tmp" && \
    case $SCALA_VERSION in \
      "3"*) URL=https://github.com/lampepfl/dotty/releases/download/$SCALA_VERSION/scala3-$SCALA_VERSION.tar.gz SCALA_DIR=scala3-$SCALA_VERSION ;; \
      *) URL=https://downloads.typesafe.com/scala/$SCALA_VERSION/scala-$SCALA_VERSION.tgz SCALA_DIR=scala-$SCALA_VERSION ;; \
    esac && \
    curl -fsL $URL | tar xfz - -C /usr/share && \
    mv /usr/share/$SCALA_DIR $SCALA_HOME && \
    ln -s "$SCALA_HOME/bin/"* "/usr/bin/" && \
    update-ca-certificates && \
    scala -version && \
    case $SCALA_VERSION in \
      "3"*) echo '@main def main = println(s"Scala library version ${dotty.tools.dotc.config.Properties.versionNumberString}")' > test.scala ;; \
      *) echo "println(util.Properties.versionMsg)" > test.scala ;; \
    esac && \
    scala -nocompdaemon test.scala && rm test.scala

RUN \
    curl -fsL https://github.com/sbt/sbt/releases/download/v$SBT_VERSION/sbt-$SBT_VERSION.tgz | tar xfz - -C /usr/local && \
    $(mv /usr/local/sbt-launcher-packaging-$SBT_VERSION /usr/local/sbt || true) && \
    ln -s /usr/local/sbt/bin/* /usr/local/bin/ && \
    sbt -Dsbt.rootdir=true -batch sbtVersion && \
    apk del .build-dependencies && \
    rm -rf "/tmp/"* && \
    rm -rf /var/cache/apk/*

# Start a new stage for the final image
FROM eclipse-temurin:${BASE_IMAGE_TAG:-21.0.2_13-jdk-alpine}

ARG SCALA_VERSION=3.4.0
ARG SBT_VERSION=1.9.9
ARG USER_ID=1001
ARG GROUP_ID=1001

RUN apk add --no-cache bash git rpm

COPY --from=builder /usr/share/scala /usr/share/scala
COPY --from=builder /usr/local/sbt /usr/local/sbt
COPY --from=builder /usr/local/bin/sbt /usr/local/bin/sbt

# Add and use user sbtuser
RUN addgroup -g $GROUP_ID sbtuser && adduser -D -u $USER_ID -G sbtuser sbtuser
USER sbtuser

# Switch working directory
WORKDIR /home/sbtuser

ENV PATH="/usr/share/scala/bin:${PATH}"

# Prepare sbt (warm cache)
RUN \
  mkdir -p project && \
  echo "scalaVersion := \"${SCALA_VERSION}\"" > build.sbt && \
  echo "sbt.version=${SBT_VERSION}" > project/build.properties && \
  echo "// force sbt compiler-bridge download" > project/Dependencies.scala && \
  echo "case object Temp" > Temp.scala && \
  sbt sbtVersion && \
  sbt compile && \
  rm -r project && rm build.sbt && rm Temp.scala && rm -r target

# Link everything into root as well
# This allows users of this container to choose, whether they want to run the container as sbtuser (non-root) or as root
USER root
RUN \
  rm -rf /tmp/..?* /tmp/.[!.]* * && \
  ln -s /home/sbtuser/.cache /root/.cache && \
  ln -s /home/sbtuser/.sbt /root/.sbt && \
  if [ -d "/home/sbtuser/.ivy2" ]; then ln -s /home/sbtuser/.ivy2 /root/.ivy2; fi

# Switch working directory back to root
## Users wanting to use this container as non-root should combine the two following arguments
## -u sbtuser
## -w /home/sbtuser
WORKDIR /root

CMD sbt