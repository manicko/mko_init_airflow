The systemd files in this directory are tested on RedHat based systems.
Copy (or link) them to /usr/lib/systemd/system or etc/systemd/system
and copy the airflow.conf to /etc/tmpfiles.d/ or /usr/lib/tmpfiles.d/.
Copying airflow.conf ensures /run/airflow is
created with the right owner and permissions (0755 airflow airflow)

You can then start the different servers by using systemctl start <service>.
Enabling services can be done by issuing
 systemctl enable <service>.

By default the environment configuration points to /etc/sysconfig/airflow .
You can copy the "airflow" file in this
directory and adjust it to your liking.

With some minor changes they probably work on other systemd systems.
