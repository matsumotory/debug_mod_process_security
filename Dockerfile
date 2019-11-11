FROM centos:8

# Build:
#   docker build -t mod_process_security-centos8 .
#
# Run:
#   docker run --rm -p 8080:80 mod_process_security-centos8
#   - Check: http://localhost:8080
#
# Run with debug:
#   docker run -it --rm -p 8080:80 mod_process_security-centos8 bash
#   vi /etc/httpd/conf.d/mod_process_security.conf
#     # Disable mod_process_security
#     #PSExAll On
#   /usr/sbin/httpd -D FOREGROUND
#   - Check: http://localhost:8080

RUN dnf -y update && \
    dnf -y install gcc make httpd httpd-devel pkgconfig libcap-devel redhat-rpm-config && \
    dnf clean all && \
    rm -rf /var/cache/dnf

RUN pushd /root && \
    curl -o v1.1.4.tar.gz -LO https://github.com/matsumotory/mod_process_security/archive/v1.1.4.tar.gz && \
    tar zxf v1.1.4.tar.gz && \
    pushd mod_process_security-1.1.4 && \
    make && \
    make install && \
    popd && \
    rm -rf v1.1.4.tar.gz mod_process_security-1.1.4 && \
    popd

RUN echo "LoadModule mpm_prefork_module modules/mod_mpm_prefork.so" > /etc/httpd/conf.modules.d/00-mpm.conf && \
    echo -e 'ErrorLog /dev/stderr\n\
TransferLog /dev/stdout\n\
<Directory /var/www/html>\n\
    Options Indexes ExecCGI\n\
</Directory>\n\
AddHandler cgi-script .cgi .pl\n\
PSExAll On' > /etc/httpd/conf.d/mod_process_security.conf

RUN groupadd -g 1000 user1 && \
    useradd -u 1000 -g user1 user1 && \
    echo '<a href="test.pl">test.pl</a>' > /var/www/html/index.html && \
    echo -e '#!/bin/env perl\n\
use strict;\n\
print "Content-type: text/html; charset=UTF-8\\n\\n";\n\
my $real_uid = $<;\n\
my $real_name = getpwuid($real_uid);\n\
my $effective_uid = $>;\n\
my $effective_name = getpwuid($effective_uid);\n\
print "real_uid : $real_uid ($real_name)<br />";\n\
print "effective_uid : $effective_uid ($effective_name)<br /><br />";\n\
exit;' > /var/www/html/test.pl && \
    chmod 755 /var/www/html/test.pl && \
    chown -R user1: /var/www/html

EXPOSE 80

CMD ["/usr/sbin/httpd", "-D", "FOREGROUND"]
