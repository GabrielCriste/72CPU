# Use uma imagem base com JDK
FROM openjdk:17-slim AS base

# Definir a versão do Scala
ENV SCALA_VERSION=3.3.1

# Instalar dependências necessárias
RUN apt-get update && apt-get install -y \
    curl \
    tar \
    && apt-get clean

# Baixar e configurar Scala
RUN curl -fsL "https://github.com/scala/scala3/releases/download/v$SCALA_VERSION/scala3-$SCALA_VERSION.tar.gz" -o scala3.tar.gz && \
    tar -xzf scala3.tar.gz -C /usr/share && \
    mv /usr/share/scala3-$SCALA_VERSION /usr/share/scala && \
    ln -s /usr/share/scala/bin/* /usr/local/bin && \
    rm scala3.tar.gz

# Definir o diretório de trabalho
WORKDIR /app

# Comando padrão
CMD ["scala", "--version"]
