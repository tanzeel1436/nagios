ARG DOCKER_REG
#4.3.4
ARG NAGIOS_RELEASE
#0.6.26
ARG PNP_NAGIOS
FROM centos:centos7
ENV NAGIOS_RELEASE 4.3.4
ENV PNP_NAGIOS 0.6.26


RUN yum update -y
RUN yum install -y \
    httpd \
    mod_ssl \
    php \
    php-cli \
    gcc \
    glibc \
    glibc-common \
    gd \
    gd-devel \
    net-snmp \
    make \
    wget \
    gcc-c++ \
    rrdtool \
    perl-Time-HiRes \
    perl-rrdtool \
    php-gd \
    unzip && \
    chkconfig httpd on && \
    useradd nagios && \
    usermod -a -G nagios apache && \
    mkdir -p /usr/local/nagios/etc/ && \
    touch /usr/local/nagios/etc/htpasswd.users && \
    htpasswd -b -c /usr/local/nagios/etc/htpasswd.users emoney emoney@123! 

RUN yum install epel-release -y  
RUN yum install ssmtp -y 

RUN echo root:`hostname`@finja.pk > /etc/ssmtp/revaliases
RUN echo "root=tanzeel.iqbal@finja.pk" > /etc/ssmtp/ssmtp.conf && echo "hostname=`hostname`" >> /etc/ssmtp/ssmtp.conf && echo "mailhub=172.25.20.55:25" >> /etc/ssmtp/ssmtp.conf

RUN cd /opt/ && \
    wget https://assets.nagios.com/downloads/nagioscore/releases/nagios-$NAGIOS_RELEASE.tar.gz && \
    tar xzvf nagios-$NAGIOS_RELEASE.tar.gz

RUN cd /opt/nagios-$NAGIOS_RELEASE && \
    chmod +x configure && \
    ./configure --with-command-group=nagios && \
    make all && \
    make install && \
    make install-init && \
    make install-config && \
    make install-commandmode && \
    make install-webconf && \
    make install-classicui

RUN cd /usr/local/src/ && \
    wget https://excellmedia.dl.sourceforge.net/project/pnp4nagios/PNP-0.6/pnp4nagios-$PNP_NAGIOS.tar.gz && \
    tar xzvf pnp4nagios-$PNP_NAGIOS.tar.gz 

RUN cd /usr/local/src/pnp4nagios-$PNP_NAGIOS && \
    ./configure && \
    make all && \
    make fullinstall && \
    chkconfig npcd on && \ 
    rm -rf /usr/local/pnp4nagios/share/install.php
#COPY ./usr/local/nagios/etc/objects /usr/local/nagios/etc/objects
#COPY ./usr/local/nagios/etc/cgi.cfg /usr/local/nagios/etc/cgi.cfg
#COPY ./usr/local/nagios/etc/nagios.cfg /usr/local/nagios/etc/nagios.cfg
#COPY ./docker-compose.yml /tmp/docker-compose.yml
RUN yum install mailx  -y

RUN cp /usr/share/zoneinfo/Asia/Karachi /etc/localtime 
EXPOSE 80

COPY startup.sh startup.sh
CMD bash -C 'startup.sh';'bash'
