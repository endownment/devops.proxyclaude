FROM eclipse-temurin:25-jdk

ARG HOST_UID
ARG HOST_GID

RUN : "${HOST_UID:?HOST_UID is not set: build the image with docker compose}" \
 && : "${HOST_GID:?HOST_GID is not set: build the image with docker compose}" \
 && apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates git zip unzip jq less zsh iputils-ping iproute2 zstd \
 && rm -rf /var/lib/apt/lists/* \
 && usermod -s /usr/bin/zsh ubuntu \
 && if [ "$(id -g ubuntu)" != "${HOST_GID}" ]; then groupmod -g "${HOST_GID}" ubuntu; fi \
 && if [ "$(id -u ubuntu)" != "${HOST_UID}" ]; then usermod -u "${HOST_UID}" ubuntu; fi

USER ubuntu
WORKDIR /home/ubuntu

RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
 && git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions \
 && git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting \
 && sed -i 's/^plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc

RUN curl -fsSL https://get.sdkman.io | bash \
 && bash -c 'source ~/.sdkman/bin/sdkman-init.sh && sdk install maven && sdk install gradle' \
 && mv ~/.sdkman ~/.sdkman-seed \
 && mkdir ~/.sdkman

ENV PATH="/home/ubuntu/.local/bin:/home/ubuntu/.sdkman/candidates/maven/current/bin:/home/ubuntu/.sdkman/candidates/gradle/current/bin:${PATH}"

# Keep this near the end: editing start.sh must not invalidate the slow layers above.
COPY start.sh /usr/local/bin/start.sh

WORKDIR /projects
CMD ["sh", "/usr/local/bin/start.sh"]
