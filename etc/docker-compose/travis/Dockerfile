FROM quay.io/travisci/travis-ruby
# FROM quay.io/travisci/travis-nodejs
# FROM quay.io/travisci/ci-nodejs
# FROM quay.io/travisci/travis-minimal

# RUN apt-get update && \
#   apt-get install \
#     apt-transport-https \
#     ca-certificates \
#     curl \
#     software-properties-common && \
#   curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - && \
#   add-apt-repository \
#    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
#    $(lsb_release -cs) \
#    stable" && \
#   apt-get update && \
#   apt-get install docker-ce && \
#   apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
#   curl -L https://github.com/docker/compose/releases/download/1.8.0/docker-compose-`uname -s`-`uname -m` > docker-compose && \
#   chmod +x docker-compose && \
#   mv docker-compose /usr/local/bin


# RUN apt-get update && \
#   apt-get install \
#     apt-transport-https \
#     ca-certificates \
#     curl \
#     software-properties-common && \
#   apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

# RUN add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" && \
#   apt-get update && \
#   apt-get install docker-ce && \
#   apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Workaround for docker install issue
# https://github.com/moby/moby/issues/1024
RUN dpkg-divert --local --rename --add /sbin/initctl
RUN ln -s /bin/true /sbin/initctl

RUN apt-key adv --keyserver hkp://pgp.mit.edu:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
RUN sh -c "echo deb https://apt.dockerproject.org/repo ubuntu-precise main \
	> /etc/apt/sources.list.d/docker.list"
# RUN apt-get purge lxc-docker
RUN apt-get update
RUN apt-get install docker-engine


RUN curl -L https://github.com/docker/compose/releases/download/1.8.0/docker-compose-`uname -s`-`uname -m` > docker-compose && \
  chmod +x docker-compose && \
  mv docker-compose /usr/local/bin


# ## sudo apt-get -y -o Dpkg::Options::="--force-confnew" install docker-ce && \
# USER travis
