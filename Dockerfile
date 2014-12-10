#  ------------------
# | Set source image |
#  ------------------

FROM ubuntu:14.10

# My info
MAINTAINER Ruddickmg@gmail.com

#  --------------
# | Install GDAL |
#  --------------

RUN apt-get update
RUN apt-get install -y wget unzip mysql-client libmysqlclient-dev gdal-bin python-gdal rng-tools krb5-doc krb5-user libhdf4-doc libhdf4-alt-dev hdf4-tools libjasper-runtime liblcms2-utils libmyodbc odbc-postgresql tdsodbc unixodbc-bin ogdi-bin poppler-data libsasl2-modules-otp libsasl2-modules-ldap libsasl2-modules-sql libsasl2-modules-gssapi-heimdal sgml-base-doc debhelper

#  ----------------------------------------------
# |    specify and download shape files (csv)    |
# | options: city,county,state,division,district |
#  ----------------------------------------------

# ENV SHAPES city,county,state,division,district

#  ---------------------------------------------------
# | import shape files into specified databases (csv) |
#  ---------------------------------------------------

# ENV IMPORTS btp

#  ---------------------
# | add startup scripts |
#  ---------------------

ADD shell/start.sh /bin/start.sh
RUN chmod +x /bin/start.sh
ADD shell/getShapes.sh /bin/getShapes.sh
RUN chmod +x /bin/getShapes.sh
ADD shell/unzip.sh /bin/unzip.sh
RUN chmod +x /bin/unzip.sh
ADD shell/importShapes.sh /bin/importShapes.sh
RUN chmod +x /bin/importShapes.sh

#  -----------------------------
# | run start.sh as login shell |
#  -----------------------------

ENTRYPOINT ["/bin/bash", "-c", "-l"]
CMD ["start.sh"]

