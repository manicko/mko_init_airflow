#!/bin/bash
USUARIO_SO="$(whoami)"
ANACONDA_URL="https://repo.anaconda.com/archive/Anaconda3-5.2.0-Linux-x86_64.sh"
_DB_PASSWORD="la contraseña"
_IP=$(hostname -I | cut -d' ' -f1)
while getopts "a:p:h" opt; do
  case $opt in
    a) ANACONDA_URL="$OPTARG";;
	p) _DB_PASSWORD="$OPTARG";;
	h) cat <<EOF
All arguments are optional
-a anaconda url
-p password for airflow postgres user 
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
#Prerequisites installation: 
while sudo fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do
   echo "Waiting while other process ends installs (dpkg/lock is locked)"
   sleep 1
done
sudo apt update && sudo apt upgrade -y
sudo apt install -y openssh-server git wget htop postgresql postgresql-client postgresql-contrib

if ! hash conda &> /dev/null; then
	mkdir -p ~/instaladores && wget -c -P "$HOME/instaladores" "$ANACONDA_URL"
	bash "$HOME/instaladores/${ANACONDA_URL##*/}" -b -p "$HOME/anaconda2"
	export PATH="$HOME/anaconda2/bin:$PATH"
	echo "export PATH='$HOME/anaconda2/bin:$PATH'">>"$HOME/.bashrc"
fi

conda install -y psycopg2
conda install -y -c conda-forge airflow "celery<4" 
if [[ -z "${AIRFLOW_HOME}" ]]; then
	export AIRFLOW_HOME="$HOME/airflow"
	echo "export AIRFLOW_HOME='$HOME/airflow'" >>"$HOME/.bashrc"
fi
airflow initdb
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
sudo su -c "echo 'host    all             all             0.0.0.0/0            md5' >>$_HBA" 
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" "$_CONFIG"
sudo systemctl restart postgresql.service
sed -i "s%sql_alchemy_conn.*%sql_alchemy_conn = postgresql+psycopg2://airflow:$_DB_PASSWORD@$_IP:5432/airflow%" "$AIRFLOW_HOME/airflow.cfg"
sed -i "s%executor =.*%executor = LocalExecutor%" "$AIRFLOW_HOME/airflow.cfg"
sed -i "s%default_timezone =.*%default_timezone = Europe/Moscow%" "$AIRFLOW_HOME/airflow.cfg"
sed -i "s%default_ui_timezone =.*%default_ui_timezone = Europe/Moscow%" "$AIRFLOW_HOME/airflow.cfg"
sed -i "s%load_examples = True.*%load_examples = False%" "$AIRFLOW_HOME/airflow.cfg"


mkdir -p "$AIRFLOW_HOME/dags"

cat <<EOF >"$AIRFLOW_HOME/dags/dummy.py"
import airflow
from airflow.models import DAG
from airflow.operators.dummy_operator import DummyOperator

from datetime import timedelta

args = {
    'owner': 'airflow',
    'start_date': airflow.utils.dates.days_ago(2)
}

dag = DAG(
    dag_id='example_dummy', default_args=args,
    schedule_interval=None,
    dagrun_timeout=timedelta(minutes=1))

run_this_last = DummyOperator(task_id='DOES_NOTHING', dag=dag)
EOF

airflow initdb
airflow scheduler -D
airflow webserver -p 8080 -D