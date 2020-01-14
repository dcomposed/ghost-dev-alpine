FROM timbru31/node-alpine-git:12

RUN apk add --no-cache \
  yarn

RUN yarn global add knex-migrator grunt-cli ember-cli bower

# http://debuggable.com/posts/disable-strict-host-checking-for-git-clone:49896ff3-0ac0-4263-9703-1eae4834cda3
RUN mkdir -p ~/.ssh/ && echo -e "Host github.com\n\tStrictHostKeyChecking no\n" >> ~/.ssh/config

# First clone Ghost with submodules and make it your working dir (https://ghost.org/docs/install/source/#ghost-core)
RUN mkdir /Ghost
WORKDIR /Ghost
RUN git clone --recurse-submodules https://github.com/TryGhost/Ghost .


ARG GITHUB_USERNAME=onezoomin
#note: can be trumped from docker-compose:
ENV GITHUB_USERNAME=$GITHUB_USERNAME

WORKDIR /Ghost
RUN echo  "Rename origin to upstream and adding fork in `pwd`" && git remote rename origin upstream && \
    git remote add origin git@github.com:$GITHUB_USERNAME/Ghost.git

# Switch to Ghost-Admin dir
WORKDIR /Ghost/core/client
RUN echo  "Rename origin to upstream and adding fork in `pwd`" && git remote rename origin upstream &&  \
    git remote add origin git@github.com:$GITHUB_USERNAME/Ghost-Admin.git

# Quick check that everything is on latest and # Then return to Ghost root directory and do the same there
RUN git checkout master && git pull upstream master
WORKDIR /Ghost
RUN git checkout master && git pull upstream master

# Only ever run this once
RUN yarn config set network-timeout 180000 && yarn add cli

# all commands from yarn setup (as of commit ) in separate layers:
RUN yarn add grunt && yarn install
RUN knex-migrator init
RUN grunt symlink
RUN grunt init

ARG PORT=2378
ENV PORT=$PORT
EXPOSE $PORT

RUN grunt build

# Not quite sure about the best way to get the right ports exposed but --server down below seems to work for now
#RUN yarn global add ghost-cli@latest
#RUN ghost ls
    # ghost config server.port $port && \
    # ghost config server.host 0.0.0.0

WORKDIR /Ghost/content/themes
RUN apk add --no-cache \
    wget unzip

RUN wget https://github.com/Reedyn/Saga/releases/download/2.0.0/Saga-v2.0.0.zip && \
    unzip Saga-v2.0.0.zip -d saga

# cleanup
RUN  rm *.zip && ls -al && apk del wget unzip && yarn cache clean || true

ARG IP=0.0.0.0
ENV IP=$IP
ENV server.host=$IP
ENV server.port=$PORT

WORKDIR /Ghost
ENTRYPOINT cd /Ghost && \
  grunt dev --server
    # ghost config server.port $port ; \
    # ghost config server.host 0.0.0.0 ; \
    # --ip 0.0.0.0 --port $PORT
