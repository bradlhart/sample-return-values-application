FROM bradlhart/sample-return-values:v0.0.4

USER gitpod
ENV ROOT_DIR="/home/gitpod"

WORKDIR /home/gitpod
RUN git clone https://github.com/EOSIO/eosio.cdt.git \
 && cd eosio.cdt \
 && git checkout eosio-cdt-2.1-staging-c \
 && git submodule update --init --recursive \
 && mkdir build \
 && cd build \
 && cmake -GNinja .. \
 && ninja -j8

ENV PATH="/home/gitpod/eos/build/bin/:/home/gitpod/eosio.cdt/build/bin/:${PATH}"

RUN echo "COPYING APP CONTRACTS"
COPY ./.docker/contracts /home/gitpod/contracts
COPY ./.docker/scripts/deploy_contracts.sh /home/gitpod/

### nginx, /password $HOME/contracts and deploy_contracts.sh
USER root
WORKDIR /root
RUN echo >/password && chown gitpod /password && chgrp gitpod /password \
 && chown -R gitpod /home/gitpod/contracts && chgrp -R gitpod /home/gitpod/contracts \
 && chown gitpod /home/gitpod/deploy_contracts.sh && chgrp gitpod /home/gitpod/deploy_contracts.sh \
 && >/run/nginx.pid \
 && chmod 666 /run/nginx.pid \
 && chmod 666 /var/log/nginx/* \
 && chmod 777 /var/lib/nginx /var/log/nginx

### Gitpod user (2)
WORKDIR $HOME
USER gitpod
# custom Bash prompt
RUN { echo && echo "PS1='\[\e]0;\u \w\a\]\[\033[01;32m\]\u\[\033[00m\] \[\033[01;34m\]\w\[\033[00m\] \\\$ '" ; } >> .bashrc
# use sudo so that user does not get sudo usage info on (the first) login
RUN sudo echo "Running 'sudo' for Gitpod: success"

RUN echo "DEPLOYING CONTRACTS"
RUN /bin/bash /home/gitpod/deploy_contracts.sh

### checks
# no root-owned files in the home directory
RUN rm -f $HOME/.wget-hsts
WORKDIR $HOME
USER gitpod
RUN notOwnedFile=$(find . -not "(" -user gitpod -and -group gitpod ")" -print -quit) \
    && { [ -z "$notOwnedFile" ] \
        || { echo "Error: not all files/dirs in $HOME are owned by 'gitpod' user & group"; exit 1; } }
