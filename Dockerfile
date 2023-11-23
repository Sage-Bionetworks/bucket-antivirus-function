FROM public.ecr.aws/lambda/python:3.11

# Install packages
RUN yum update -y
RUN yum install -y cpio yum-utils zip unzip less wget
RUN yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

# Set up working directories
RUN mkdir -p /opt/app
RUN mkdir -p /opt/app/build
RUN mkdir -p /opt/app/bin/

# Copy in the lambda source
WORKDIR /opt/app
COPY ./*.py /opt/app/
COPY requirements.txt /opt/app/requirements.txt

# This had --no-cache-dir, tracing through multiple tickets led to a problem in wheel
RUN pip3 install -r requirements.txt
RUN rm -rf /root/.cache/pip

# Download libraries we need to run in lambda
WORKDIR /tmp
RUN wget https://www.clamav.net/downloads/production/clamav-1.0.4.linux.x86_64.rpm
RUN rpm2cpio clamav-1.0.4.linux.x86_64.rpm | cpio -idmv

# Copy over the binaries and libraries
RUN cp -a /tmp/usr/local/bin/clamscan /tmp/usr/local/bin/freshclam /tmp/usr/local/lib64/* /opt/app/bin/

# Fix the freshclam.conf settings
RUN echo "DatabaseMirror database.clamav.net" > /opt/app/bin/freshclam.conf
RUN echo "CompressLocalDatabase yes" >> /opt/app/bin/freshclam.conf

# Create the zip file
WORKDIR /opt/app
RUN zip -r9 --exclude="*test*" /opt/app/build/lambda.zip *.py bin

WORKDIR /var/lang/lib/python3.11/site-packages
RUN zip -r9 /opt/app/build/lambda.zip *

WORKDIR /opt/app