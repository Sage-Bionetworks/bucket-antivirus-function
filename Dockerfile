FROM amazonlinux:2

# Install packages
RUN yum update -y
RUN yum install -y cpio yum-utils zip unzip less
RUN yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

# Install Python 3.11
RUN yum groupinstall -y "Development Tools"
RUN yum install -y libffi-devel bzip2-devel
RUN yum remove -y openssl-devel
RUN yum install -y openssl11-devel wget

WORKDIR /tmp
RUN wget https://python.org/ftp/python/3.11.1/Python-3.11.1.tgz
RUN tar xzf Python-3.11.1.tgz 
WORKDIR /tmp/Python-3.11.1
RUN ./configure --enable-optimizations
RUN make altinstall

# Set up working directories
RUN mkdir -p /opt/app
RUN mkdir -p /opt/app/build
RUN mkdir -p /opt/app/bin/

# Copy in the lambda source
WORKDIR /opt/app
COPY ./*.py /opt/app/
COPY requirements.txt /opt/app/requirements.txt

# This had --no-cache-dir, tracing through multiple tickets led to a problem in wheel
RUN /usr/local/bin/pip3.11 install -r requirements.txt
RUN rm -rf /root/.cache/pip

# Download libraries we need to run in lambda
RUN yumdownloader -x \*i686 --archlist=x86_64 clamav clamav-lib clamav-update json-c pcre2 libprelude gnutls libtasn1 lib64nettle nettle
RUN rpm2cpio clamav-0*.rpm | cpio -idmv
RUN rpm2cpio clamav-lib*.rpm | cpio -idmv
RUN rpm2cpio clamav-update*.rpm | cpio -idmv
RUN rpm2cpio json-c*.rpm | cpio -idmv
RUN rpm2cpio pcre*.rpm | cpio -idmv
RUN rpm2cpio gnutls* | cpio -idmv
RUN rpm2cpio nettle* | cpio -idmv
RUN rpm2cpio lib* | cpio -idmv
RUN rpm2cpio *.rpm | cpio -idmv
RUN rpm2cpio libtasn1* | cpio -idmv

# Copy over the binaries and libraries
RUN cp /tmp/usr/bin/clamscan /tmp/usr/bin/freshclam /tmp/usr/lib64/* /opt/app/bin/

# Fix the freshclam.conf settings
RUN echo "DatabaseMirror database.clamav.net" > /opt/app/bin/freshclam.conf
RUN echo "CompressLocalDatabase yes" >> /opt/app/bin/freshclam.conf

# Create the zip file
WORKDIR /opt/app
RUN zip -r9 --exclude="*test*" /opt/app/build/lambda.zip *.py bin

WORKDIR /usr/local/lib/python3.11/site-packages
RUN zip -r9 /opt/app/build/lambda.zip *

WORKDIR /opt/app
