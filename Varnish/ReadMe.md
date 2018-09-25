# sudo su -
# yum install epel-release
# yum install varnish
# vi /etc/host
add the following line:
<ip of nginx server>        nginx-vip
:wq

# vi /etc/varnish/varnish.params
change the varnish listen port:
VARNISH_LISTEN_PORT=8080
:wq

# vi /etc/varnish/default.vcl
Replace the content of this file with the content of the attached default.vcl. Do not cp the file, because it might change file permissions.
:wq

Optional - test the varnish config:
# varnishd -C -f /etc/varnish/default.vcl

# systemctl enable varnish
# systemctl start varnish
# setenforce 0
