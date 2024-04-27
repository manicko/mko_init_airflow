#!/bin/bash

USER_NAME='dataflow'
USER_PASSWORD="PASSWORD"
USER_GROUP='sudo'

#sudo adduser $USER_NAME
#sudo usermod -a -G sudo $USER_NAME
#sudo nano /etc/sudoers


getent group $USER_GROUP
if [ $? -ne 0 ] ; then
    sudo su -c "groupadd $USER_GROUP"
fi


sudo su -c "useradd $USER_NAME -s /bin/bash -m -g $PRIMARYGRP -G $USER_GROUP"
echo $USER_NAME:$USER_PASSWORD | sudo chpasswd
