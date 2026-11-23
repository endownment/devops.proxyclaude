FROM eclipse-temurin:17-jdk AS jdk17

FROM eclipse-temurin:25-jdk

ARG DEBIAN_FRONTEND=noninteractive
ARG HOST_UID
ARG HOST_GID

# Base tools, Python, a virtual display for JavaFX (Xvfb, xdotool, screenshots with ImageMagick),
# the native libraries JavaFX needs (GTK, GL, pango for font rendering) and fonts.
RUN : "${HOST_UID:?HOST_UID is not set: build the image with docker compose}" \
 && : "${HOST_GID:?HOST_GID is not set: build the image with docker compose}" \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      curl ca-certificates git zip unzip jq less zsh iputils-ping iproute2 zstd file \
      python3 python3-venv python3-pip \
      xvfb xauth xdotool x11-utils imagemagick \
      libgtk-3-0t64 libgl1 libgl1-mesa-dri libxtst6 libxxf86vm1 \
      libpango-1.0-0 libpangoft2-1.0-0 libpangocairo-1.0-0 \
      libnspr4 libnss3 libasound2t64 \
      tini \
      fontconfig fonts-dejavu-core fonts-liberation \
 && rm -rf /var/lib/apt/lists/* \
 && usermod -s /usr/bin/zsh ubuntu \
 && if [ "$(id -g ubuntu)" != "${HOST_GID}" ]; then groupmod -g "${HOST_GID}" ubuntu; fi \
 && if [ "$(id -u ubuntu)" != "${HOST_UID}" ]; then usermod -u "${HOST_UID}" ubuntu; fi

# Node.js 22 (scell-specs/tools/check_mermaid.mjs checks the mermaid diagrams in a headless browser;
# the libraries of that Chromium are in the apt-get install list above).
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/* /root/.npm

# JDK 17 for scell (the build fails on JDK 25); JDK 25 of the base image stays in /opt/java/openjdk.
COPY --from=jdk17 /opt/java/openjdk /opt/java/jdk17
ENV JAVA_HOME=/opt/java/jdk17

USER ubuntu
WORKDIR /home/ubuntu

RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
 && git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions \
 && git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting \
 && sed -i 's/^plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc

# Maven 3.9.16: Maven 3.10 rejects the duplicated dependencies of api-core-impl/pom.xml.
RUN curl -fsSL https://get.sdkman.io | bash \
 && bash -c 'source ~/.sdkman/bin/sdkman-init.sh && sdk install maven 3.9.16 && sdk default maven 3.9.16 && sdk install gradle' \
 && mv ~/.sdkman ~/.sdkman-seed \
 && mkdir ~/.sdkman

# Keep the version equal to "playwright" in scell-specs/tools/package.json: each version looks for its own browser build.
RUN npx -y playwright@1.65.1 install chromium

ENV PATH="/opt/java/jdk17/bin:/home/ubuntu/.local/bin:/home/ubuntu/.sdkman/candidates/maven/current/bin:/home/ubuntu/.sdkman/candidates/gradle/current/bin:${PATH}"

# Keep this near the end: editing start.sh must not invalidate the slow layers above.
COPY start.sh /usr/local/bin/start.sh

WORKDIR /projects
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["sh", "/usr/local/bin/start.sh"]
