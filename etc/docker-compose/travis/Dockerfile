FROM quay.io/travisci/travis-ruby
# Workaround for docker install issue
# https://github.com/moby/moby/issues/1024
RUN dpkg-divert --local --rename --add /sbin/initctl
RUN ln -s /bin/true /sbin/initctl

RUN apt-key adv --keyserver hkp://pgp.mit.edu:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
RUN sh -c "echo deb https://apt.dockerproject.org/repo ubuntu-precise main \
	> /etc/apt/sources.list.d/docker.list"
RUN apt-get update
RUN apt-get install docker-engine

RUN curl -L https://github.com/docker/compose/releases/download/1.8.0/docker-compose-`uname -s`-`uname -m` > docker-compose && \
  chmod +x docker-compose && \
  mv docker-compose /usr/local/bin

USER travis

