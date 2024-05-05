#!/bin/bash
USUARIO_SO="$(whoami)"
AIRFLOW_VERS="2.9.0"
PYTHON_VERSION='3.10'
_DB_PASSWORD="PASSWORD"
AIRFLOW_PASSWORD="PASSWORD"
#_IP=$(hostname -I | cut -d' ' -f1) replace below for production
_IP='localhost'
while getopts "a:p:b:h" opt; do
  case $opt in
    a) AIRFLOW_VERS="$OPTARG";;
      p) PYTHON_VERSION="$OPTARG";;
	b) _DB_PASSWORD="$OPTARG";;
	h) cat <<EOF
All arguments are optional
-a airflow version
-p python version
-b password for airflow postgres user
-h this help
EOF
exit 0;
;;
	\?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done

echo "Installation will be performed as  $USUARIO_SO"

if [[ $(id -u) -eq 0 ]] ; then echo "This script must  not be excecuted as root or using sudo(althougth the user must be sudoer and password will be asked in some steps)" ; exit 1 ; fi

# Make a package manager wait if another instance of APT is running:
while sudo fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do
   echo "Waiting while other process ends installs (dpkg/lock is locked)"
   sleep 1
done

sudo apt-get autoclean
sudo apt-get autoremove
sudo apt-get clean

# Ensure all packages are up too date
sudo apt update && sudo apt upgrade -y


# Install Postgresql:
sudo apt install -y postgresql postgresql-contrib
# Install Postgresql connector to Airflow:
sudo apt install python3-pip
pip3 install psycopg2-binary

#set home for airflow
if [[ -z "${AIRFLOW_HOME}" ]]; then
	export "AIRFLOW_HOME=$HOME/airflow"
	echo "export AIRFLOW_HOME=$HOME/airflow" >>"$HOME/.bashrc"
fi

#install airflow
pip3 install "apache-airflow==$AIRFLOW_VERS" --constraint "https://raw.githubusercontent.com/apache/airflow/constraints-$AIRFLOW_VERS/constraints-$PYTHON_VERSION.txt"

export "PATH=$PATH:$HOME/.local/bin"
echo "export PATH=$PATH:$HOME/.local/bin >>$HOME/.bashrc"

#initialize airflow to setup home folder
airflow db migrate
sudo chmod og+rX "$HOME"
sudo -u postgres createdb airflow
sudo -u postgres createuser airflow
sudo -u postgres psql airflow -c "alter user airflow with encrypted password '$_DB_PASSWORD';"
sudo -u postgres psql airflow -c "grant all privileges on database airflow to airflow;"
#Configurar postgresql para que admita conexiones remotas
_HBA=$(sudo -u postgres psql -t -P format=unaligned -c 'show hba_file')
_CONFIG=$(sudo -u postgres psql -t -P format=unaligned -c 'show config_file')
mkdir -p "$HOME/pg_backup"
sudo cp "$_HBA" "$HOME/pg_backup"
cp "$_CONFIG" "$HOME/pg_backup"

sudo systemctl restart postgresql.service
sed -i "s%sql_alchemy_conn.*%sql_alchemy_conn = postgresql+psycopg2://airflow:$_DB_PASSWORD@$_IP:5432/airflow%" "$AIRFLOW_HOME/airflow.cfg"
sed -i "s%executor =.*%executor = LocalExecutor%" "$AIRFLOW_HOME/airflow.cfg"
sed -i "s%default_timezone =.*%default_timezone = Europe/Moscow%" "$AIRFLOW_HOME/airflow.cfg"
sed -i "s%default_ui_timezone =.*%default_ui_timezone = Europe/Moscow%" "$AIRFLOW_HOME/airflow.cfg"
sed -i "s%load_examples =.*%load_examples = False%" "$AIRFLOW_HOME/airflow.cfg"
# Helps to eliminate error with scheduler not running
sed -i "s%job_heartbeat_sec =.*%job_heartbeat_sec = 30%" "$AIRFLOW_HOME/airflow.cfg"


airflow users create --username admin \
          --firstname FIRST_NAME \
          --lastname LAST_NAME \
          --role Admin \
          --email admin@example.org\
          --password "$AIRFLOW_PASSWORD"


airflow scheduler -D
airflow webserver -p 8080 -D