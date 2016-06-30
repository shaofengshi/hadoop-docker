# Creates a kylin 1.5.2 + hbase 0.98 + hive 0.14 + hadoop 2.6

FROM sequenceiq/pam:centos-6.5
MAINTAINER Kyligence

USER root

# install dev tools
RUN yum clean all; \
    rpm --rebuilddb; \
    yum install -y curl which tar sudo openssh-server openssh-clients rsync
# update libselinux. see https://github.com/sequenceiq/hadoop-docker/issues/14
RUN yum update -y libselinux

# passwordless ssh
RUN ssh-keygen -q -N "" -t dsa -f /etc/ssh/ssh_host_dsa_key
RUN ssh-keygen -q -N "" -t rsa -f /etc/ssh/ssh_host_rsa_key
RUN ssh-keygen -q -N "" -t rsa -f /root/.ssh/id_rsa
RUN cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys


# java
RUN curl -LO 'http://download.oracle.com/otn-pub/java/jdk/7u71-b14/jdk-7u71-linux-x64.rpm' -H 'Cookie: oraclelicense=accept-securebackup-cookie'
RUN rpm -i jdk-7u71-linux-x64.rpm
RUN rm jdk-7u71-linux-x64.rpm

ENV JAVA_HOME /usr/java/default
ENV PATH $PATH:$JAVA_HOME/bin
RUN rm /usr/bin/java && ln -s $JAVA_HOME/bin/java /usr/bin/java

# hadoop
RUN curl -s http://www.eu.apache.org/dist/hadoop/common/hadoop-2.6.0/hadoop-2.6.0.tar.gz | tar -xz -C /usr/local/
RUN cd /usr/local && ln -s ./hadoop-2.6.0 hadoop

# hbase 0.98
RUN curl -s https://www-us.apache.org/dist/hbase/0.98.20/hbase-0.98.20-hadoop2-bin.tar.gz | tar -xz -C /usr/local/
RUN cd /usr/local && ln -s ./hbase-0.98.20-hadoop2 hbase

# hive 0.14
RUN curl -s https://archive.apache.org/dist/hive/hive-0.14.0/apache-hive-0.14.0-bin.tar.gz | tar -xz -C /usr/local/
RUN cd /usr/local && ln -s ./apache-hive-0.14.0-bin hive
# remove old jar to avoid conflict
RUN rm -rf /usr/local/hadoop/share/hadoop/yarn/lib/jline-0.9.94.jar

# kylin 1.5.2
RUN curl -s https://www-us.apache.org/dist/kylin/apache-kylin-1.5.2.1/apache-kylin-1.5.2.1-bin.tar.gz | tar -xz -C /usr/local/
RUN cd /usr/local && ln -s ./apache-kylin-1.5.2.1-bin kylin

ENV HADOOP_PREFIX /usr/local/hadoop
ENV HADOOP_COMMON_HOME /usr/local/hadoop
ENV HADOOP_HDFS_HOME /usr/local/hadoop
ENV HADOOP_MAPRED_HOME /usr/local/hadoop
ENV HADOOP_YARN_HOME /usr/local/hadoop
ENV HADOOP_CONF_DIR /usr/local/hadoop/etc/hadoop
ENV YARN_CONF_DIR $HADOOP_PREFIX/etc/hadoop

ENV HBASE_PREFIX /usr/local/hbase
ENV HBASE_CONF_DIR $HBASE_PREFIX/conf
ENV HIVE_PREFIX /usr/local/hive
ENV HIVE_CONF_DIR $HIVE_PREFIX/conf
ENV KYLIN_HOME /usr/local/kylin

ENV PATH $PATH:$HADOOP_PREFIX/bin:$HBASE_PREFIX/bin:$HIVE_PREFIX/bin:$KYLIN_HOME/bin

RUN sed -i '/^export JAVA_HOME/ s:.*:export JAVA_HOME=/usr/java/default\nexport HADOOP_PREFIX=/usr/local/hadoop\nexport HADOOP_HOME=/usr/local/hadoop\n:' $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh
RUN sed -i '/^export HADOOP_CONF_DIR/ s:.*:export HADOOP_CONF_DIR=/usr/local/hadoop/etc/hadoop/:' $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh
#RUN . $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh

RUN mkdir $HADOOP_PREFIX/input
RUN cp $HADOOP_PREFIX/etc/hadoop/*.xml $HADOOP_PREFIX/input

# pseudo distributed
#ADD core-site.xml.template $HADOOP_PREFIX/etc/hadoop/core-site.xml.template
#RUN sed s/HOSTNAME/localhost/ /usr/local/hadoop/etc/hadoop/core-site.xml.template > /usr/local/hadoop/etc/hadoop/core-site.xml
ADD core-site.xml $HADOOP_PREFIX/etc/hadoop/core-site.xml
ADD hdfs-site.xml $HADOOP_PREFIX/etc/hadoop/hdfs-site.xml
ADD mapred-site.xml $HADOOP_PREFIX/etc/hadoop/mapred-site.xml
ADD yarn-site.xml $HADOOP_PREFIX/etc/hadoop/yarn-site.xml
ADD hbase-site.xml $HBASE_CONF_DIR/hbase-site.xml
ADD hive-site.xml $HIVE_CONF_DIR/hive-site.xml
ADD kylin.properties $KYLIN_HOME/conf/kylin.properties

# fixing the libhadoop.so like a boss
RUN rm  /usr/local/hadoop/lib/native/*
RUN curl -Ls http://dl.bintray.com/sequenceiq/sequenceiq-bin/hadoop-native-64-2.6.0.tar | tar -x -C /usr/local/hadoop/lib/native/

ADD ssh_config /root/.ssh/config
RUN chmod 600 /root/.ssh/config
RUN chown root:root /root/.ssh/config

ADD bootstrap.sh /etc/bootstrap.sh
RUN chown root:root /etc/bootstrap.sh
RUN chmod 700 /etc/bootstrap.sh

ENV BOOTSTRAP /etc/bootstrap.sh

# workingaround docker.io build error
RUN ls -la /usr/local/hadoop/etc/hadoop/*-env.sh
RUN chmod +x /usr/local/hadoop/etc/hadoop/*-env.sh
RUN ls -la /usr/local/hadoop/etc/hadoop/*-env.sh

# fix the 254 error code
RUN sed  -i "/^[^#]*UsePAM/ s/.*/#&/"  /etc/ssh/sshd_config
RUN echo "UsePAM no" >> /etc/ssh/sshd_config
RUN echo "Port 2122" >> /etc/ssh/sshd_config

CMD ["/etc/bootstrap.sh", "-d"]

# Kylin and Other ports
EXPOSE 7070 7443 49707 2122

