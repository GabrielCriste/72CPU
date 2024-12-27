# Base Image Selection
ARG BASE_IMAGE_TAG
FROM amazoncorretto:${BASE_IMAGE_TAG:-21.0.5-al2023} as scala-sbt

# Env variables for Scala and sbt
ARG SCALA_VERSION
ENV SCALA_VERSION=${SCALA_VERSION:-3.3.4}
ARG SBT_VERSION
ENV SBT_VERSION=${SBT_VERSION:-1.10.5}
ARG USER_ID
ENV USER_ID=${USER_ID:-1001}
ARG GROUP_ID
ENV GROUP_ID=${GROUP_ID:-1001}

# Install dependencies for sbt, Scala, and Java
RUN dnf -y update \
 && dnf -y install tar gzip procps git rpm java-17-amazon-corretto \
 && rm -rf /var/cache/dnf/* && dnf clean all

# Install sbt
RUN curl -fsL --show-error "https://github.com/sbt/sbt/releases/download/v$SBT_VERSION/sbt-$SBT_VERSION.tgz" | tar xfz - -C /usr/share \
 && chown -R root:root /usr/share/sbt \
 && chmod -R 755 /usr/share/sbt \
 && ln -s /usr/share/sbt/bin/sbt /usr/local/bin/sbt

# Install Scala
RUN case $SCALA_VERSION in \
      2.*) URL=https://downloads.typesafe.com/scala/$SCALA_VERSION/scala-$SCALA_VERSION.tgz SCALA_DIR=/usr/share/scala-$SCALA_VERSION ;; \
      *) URL=https://github.com/scala/scala3/releases/download/$SCALA_VERSION/scala3-$SCALA_VERSION.tar.gz SCALA_DIR=/usr/share/scala3-$SCALA_VERSION ;; \
    esac \
 && curl -fsL --show-error $URL | tar xfz - -C /usr/share \
 && mv $SCALA_DIR /usr/share/scala \
 && chown -R root:root /usr/share/scala \
 && chmod -R 755 /usr/share/scala \
 && ln -s /usr/share/scala/bin/* /usr/local/bin

# Switch to Jupyter base image
FROM quay.io/jupyter/base-notebook:2024-12-02 as jupyter-env

# Install system dependencies for Jupyter and remote desktop
USER root
RUN apt-get -y -qq update \
 && apt-get -y -qq install \
        dbus-x11 \
        xclip \
        xfce4 \
        xfce4-panel \
        xfce4-session \
        xfce4-settings \
        xorg \
        xubuntu-icon-theme \
        fonts-dejavu \
 && apt-get -y -qq remove xfce4-screensaver \
 && mkdir -p /opt/install \
 && chown -R $NB_UID:$NB_GID $HOME /opt/install \
 && rm -rf /var/lib/apt/lists/*

# Install VNC server
ARG vncserver=tigervnc
RUN if [ "${vncserver}" = "tigervnc" ]; then \
        apt-get -y -qq update; \
        apt-get -y -qq install tigervnc-standalone-server; \
        rm -rf /var/lib/apt/lists/*; \
    fi

# Install environment and additional tools
USER $NB_USER
COPY --chown=$NB_UID:$NB_GID environment.yml /tmp
RUN . /opt/conda/bin/activate && \
    mamba env update --quiet --file /tmp/environment.yml

# Install Node.js and package
COPY --chown=$NB_UID:$NB_GID . /opt/install
RUN . /opt/conda/bin/activate && \
    mamba install -y -q "nodejs>=22" && \
    pip install /opt/install

# Include Scala and sbt environment
COPY --from=scala-sbt /usr/share/sbt /usr/share/sbt
COPY --from=scala-sbt /usr/share/scala /usr/share/scala

# Garantir permissões de root para criar links simbólicos
USER root
RUN ln -sf /usr/share/sbt/bin/sbt /usr/local/bin/sbt \
 && ln -sf /usr/share/scala/bin/* /usr/local/bin

# Warm up sbt
USER root
RUN mkdir -p /test && \
    echo "scalaVersion := \"${SCALA_VERSION}\"" > /test/build.sbt && \
    sbt -sbt-create compile

CMD ["start.sh"]


