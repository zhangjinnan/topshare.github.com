#!/bin/bash

ldapadd -Y EXTERNAL -H ldapi:/// -f chrootpw.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif
ldapmodify -Y EXTERNAL -H ldapi:/// -f chdomain.ldif

# init basedomain
#ldapadd -x -D cn=Manager,dc=99cloud,dc=net -W -f basedomain.ldif

# modify some schema for OpenStack
#ldapmodify -c -Y EXTERNAL -H ldapi:/// -f modify_for_openstack.ldif


exit 0
