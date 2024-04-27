#!/bin/bash
USUARIO_SO="$(whoami)"

echo "Installation will be performed as  $USUARIO_SO"

if [[ $(id -u) -eq 0 ]] ; then echo "This script must  not be excecuted as root or using sudo(althougth the user must be sudoer and password will be asked in some steps)" ; exit 1 ; fi

# Make a package manager wait if another instance of APT is running:
while sudo fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do
   echo "Waiting while other process ends installs (dpkg/lock is locked)"
   sleep 1
done

pip3 install --index-url https://test.pypi.org/simple/ --extra-index-url https://pypi.org/simple mko-get-mediascope-data
pip3 install --index-url https://test.pypi.org/simple/ --extra-index-url https://pypi.org/simple mko-gloader

# create ext_packs folder and folder for modules and ignore file
mkdir -p "$AIRFLOW_HOME/dags/"
cat <<EOF >"$AIRFLOW_HOME/dags/.airflowignore"
ext_packs/.*
EOF
# put gdrive loader
mkdir -p "$AIRFLOW_HOME/dags/ext_packs"
cat <<EOF >"$AIRFLOW_HOME/dags/loader.py"
from mko_gloader import gloader

if __name__ == '__main__':
    gloader.main()
EOF

# create ext_packs folder and folder for mediascope_data
mkdir -p "$AIRFLOW_HOME/dags/ext_packs/mediascope_data/data/output"

cat <<EOF >"$AIRFLOW_HOME/dags/sovcombank_tv_new_creatives.py"
import pendulum
from pathlib import Path
from airflow.decorators import dag, task
from mko_get_mediascope_data.get_data import get_data
import os


LOADER_PATH = f'/home/airflow/dags/ext_packs/loader.py'
MEDIASCOPE_PATH = f'/home/airflow/dags/ext_packs/mediascope_data'
REPORT_PATH = f'{MEDIASCOPE_PATH}/mko_get_mediascope_data/settings/reports/test.yaml'
OUTPUT_PATH = f'{MEDIASCOPE_PATH}/data/output/'
SETTINGS = f'{MEDIASCOPE_PATH}/mko_get_mediascope_data/settings/connections/mediascope.json'

REPORT_SETTINGS = [
    REPORT_PATH,
    OUTPUT_PATH,
    SETTINGS
]


@dag(
    dag_id="Sovcombank_tv_new_creatives",
    schedule_interval="00 07 * * 2",  # 11 00 Tuesday weekly
    start_date=pendulum.datetime(2024, 1, 1, tz='Europe/Moscow'),
    catchup=False,
    tags=["sovcombank", 'tv'],
)
def dag_wrapper():
    @task
    def build_report(report_settings):
        return get_data(*report_settings)

    @task.bash
    def load(folder) -> str:
        params = {
            'script_file': f'python3 {LOADER_PATH}',
            'arg': f'-up',
            'source_path': f'{OUTPUT_PATH}{folder}',
            'parent_id': f'1YtkAcIHDdUKIqWvLHxxALgwrgDMZupAt',
            'destination_path': folder,
        }
        return ' '.join(params.values())

    @task
    def flush_folder(folder):
        folder_path = OUTPUT_PATH + folder  # Enter your path here
        try:
            for root, dirs, files in os.walk(folder_path, topdown=False):
                for file in files:
                    os.remove(os.path.join(root, file))
                    # Add this block to remove folders
                for d in dirs:
                    os.rmdir(os.path.join(root, d))
        except Exception as err:
            print(err)
            # # Add this line to remove the root folder at the end
            # os.rmdir(folder_path)

    folders = build_report(REPORT_SETTINGS)
    load.expand(folder=folders) >> flush_folder(folder=folders)


dag_wrapper()

EOF


mkdir -p "$AIRFLOW_HOME/info/logs"

python3 "$HOME/.local/lib/python3.10/site-packages/mko_gloader/gloader.py" -set "$AIRFLOW_HOME/info"
cat <<EOF >"$AIRFLOW_HOME/info/config.ini"
[Logs]
logs_path = $AIRFLOW_HOME/info/logs
keep_logs = True

[GoogleDriveAPI]
cred_path = $AIRFLOW_HOME/info/credentials.json
use_token = False
scopes = https://www.googleapis.com/auth/drive
EOF
