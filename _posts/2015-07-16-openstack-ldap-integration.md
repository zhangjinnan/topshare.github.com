
#OpenLDAP OpenStack集成

##RDO All in One
referance RDO install.

##安装和配置OpenLDAP

###安装OpenStack

```
[root@ldap ~]# yum -y install openldap-servers openldap-clients
[root@ldap ~]# cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG 
[root@ldap ~]# chown ldap. /var/lib/ldap/DB_CONFIG 
[root@ldap ~]# systemctl start slapd 
[root@ldap ~]# systemctl enable slapd 
```
###初始化OpenLDAP

使用slappasswd Admin生成一个ldap的密码，如下：

```
[root@ldap ~]# slappasswd
New password:
Re-enter new password:
{SSHA}30laXQ0uxWOX7h+bI2sOIeRailLRdNYz
```

设置Admin的密码：

```
[root@ldap ldap_init]# cat chrootpw.ldif
# specify the password generated above for "olcRootPW" section
 dn: olcDatabase={0}config,cn=config
# By default passwd: admin
# You can change it use slappasswd generate it.
changetype: modify
add: olcRootPW
olcRootPW: {SSHA}C/HNqgSVybWMVujtbHg6DezkVNrFEVA6
[root@ldap ldap_init]# ldapadd -Y EXTERNAL -H ldapi:/// -f chrootpw.ldif
SASL/EXTERNAL authentication started
SASL username: gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth
SASL SSF: 0
```

导入基本的Schemas：


```
[root@ldap ~]# ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif
SASL/EXTERNAL authentication started
SASL username: gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth
SASL SSF: 0
adding new entry "cn=cosine,cn=schema,cn=config"

[root@ldap ~]# ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif
SASL/EXTERNAL authentication started
SASL username: gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth
SASL SSF: 0
adding new entry "cn=nis,cn=schema,cn=config"

[root@ldap ~]# ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif
SASL/EXTERNAL authentication started
SASL username: gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth
SASL SSF: 0
adding new entry "cn=inetorgperson,cn=schema,cn=config"
```

初始化Domain Name和Manage：
```

[root@ldap ldap_init]# ldapmodify -Y EXTERNAL -H ldapi:/// -f chdomain.ldif
SASL/EXTERNAL authentication started
SASL username: gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth
SASL SSF: 0
modifying entry "olcDatabase={2}hdb,cn=config"

modifying entry "olcDatabase={2}hdb,cn=config"

modifying entry "olcDatabase={2}hdb,cn=config"

modifying entry "olcDatabase={2}hdb,cn=config"
```

初始化Domain：

```
[root@ldap ldap_init]# cat basedomain.ldif
# Replace to your own domain name for "dc=***,dc=***" section
 dn: dc=99cloud,dc=net
objectClass: top
objectClass: dcObject
objectclass: organization
o: 99cloud company
dc: 99cloud

dn: cn=Manager,dc=99cloud,dc=net
objectClass: organizationalRole
cn: Manager
description: Directory Manager

dn: ou=People,dc=99cloud,dc=net
objectClass: organizationalUnit
ou: People

dn: ou=Group,dc=99cloud,dc=net
objectClass: organizationalUnit
ou: Group


[root@ldap ldap_init]# ldapadd -x -D cn=Manager,dc=99cloud,dc=net -W -f basedomain.ldif
Enter LDAP Password:
adding new entry "dc=99cloud,dc=net"

adding new entry "cn=Manager,dc=99cloud,dc=net"

adding new entry "ou=People,dc=99cloud,dc=net"

adding new entry "ou=Group,dc=99cloud,dc=net"

```


phpldapadmin安装配置:

```
[root@ldap ~]# yum install phpldapadmin

[root@ldap ~]# vim /etc/phpldapadmin/config.php
397 $servers->setValue('login','attr','dn');
398 //$servers->setValue('login','attr','uid');


[root@ldap conf.d]# cat /etc/httpd/conf.d/phpldapadmin.conf
#
#  Web-based tool for managing LDAP servers
#

Alias /phpldapadmin /usr/share/phpldapadmin/htdocs
Alias /ldapadmin /usr/share/phpldapadmin/htdocs

<Directory /usr/share/phpldapadmin/htdocs>
  <IfModule mod_authz_core.c>
    # Apache 2.4
    Require all granted
  </IfModule>
  <IfModule !mod_authz_core.c>
    # Apache 2.2
    Order Deny,Allow
    Allow from all
    Allow from ::1
  </IfModule>
</Directory>

```

修改inetorgperson,groupOfNames的schema从而适配OpenStack:

```
kevin-2:OpenStack_init_ldap kevin$ cat modify_for_openstack.ldif
#modify some schema for openstack, for example enable, description.

dn: cn={0}core,cn=schema,cn=config
changetype: modify
add: olcAttributeTypes
olcAttributeTypes: {52}( 2.5.4.66 NAME 'enabled' DESC 'RFC2256: enabled of a group' EQUALITY booleanMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.7 SINGLE-VALUE )

dn: cn={0}core,cn=schema,cn=config
changetype: modify
delete: olcObjectClasses
olcObjectClasses: {7}( 2.5.6.9 NAME 'groupOfNames' DESC 'RFC2256: a group of names (DNs)' SUP top STRUCTURAL MUST ( member $ cn ) MAY ( businessCategory $ seeAlso $ owner $ ou $ o $ description ) )
-
add: olcObjectClasses
olcObjectClasses: {7}( 2.5.6.9 NAME 'groupOfNames' DESC 'RFC2256: a group of names (DNs)' SUP top STRUCTURAL MUST ( member $ cn ) MAY ( businessCategory $ seeAlso $ owner $ ou $ o $ description $ enabled) )

dn: cn={3}inetorgperson,cn=schema,cn=config
changetype: modify
delete: olcObjectClasses
olcObjectClasses: {0}( 2.16.840.1.113730.3.2.2 NAME 'inetOrgPerson' DESC 'RFC2798: Internet Organizational Person' SUP organizationalPerson STRUCTURAL MAY ( audio $ businessCategory $ carLicense $ departmentNumber $ displayName $ employeeNumber $ employeeType $ givenName $ homePhone $ homePostalAddress $ initials $ jpegPhoto $ labeledURI $ mail $ manager $ mobile $ o $ pager $ photo $ roomNumber $ secretary $ uid $ userCertificate $ x500uniqueIdentifier $ preferredLanguage $ userSMIMECertificate $ userPKCS12 ) )
-
add: olcObjectClasses
olcObjectClasses: {0}( 2.16.840.1.113730.3.2.2 NAME 'inetOrgPerson' DESC 'RFC2798: Internet Organizational Person' SUP organizationalPerson STRUCTURAL MAY ( audio $ businessCategory $ carLicense $ departmentNumber $ displayName $ employeeNumber $ employeeType $ givenName $ homePhone $ homePostalAddress $ initials $ jpegPhoto $ labeledURI $ mail $ manager $ mobile $ o $ pager $ photo $ roomNumber $ secretary $ uid $ userCertificate $ x500uniqueIdentifier $ preferredLanguage $ userSMIMECertificate $ userPKCS12 $ description $ enabled $ email ) )
```

