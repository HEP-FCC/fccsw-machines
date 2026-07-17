# FCC Software Machines Status Webpage

This PHP page shows status of the FCC Ironic and GPU machines at:

[https://fccsw.web.cern.ch/fccsw-machines](https://fccsw.web.cern.ch/fccsw-machines)


## Local development

Install PHP, for RedHat based Linux distributions use:
```
dnf install php-cli php-snmp
```
>
> This page depends on PHP SNMP Class
>

Run local server (from this `web/` directory):
```
php -S localhost:8000
```


## Deployment

The page lives at
```
/eos/project/f/fccsw-web/www/fccsw-machines/index.php
```
