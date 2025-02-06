import pendulum
from pathlib import Path
from airflow.decorators import dag, task
from mko_get_mediascope_data.get_data import get_data
import os

USER = 'dataflow'

LOADER_PATH = f'/home/{USER}/airflow/dags/ext_packs/loader.py'
MEDIASCOPE_PATH = f'/home/{USER}/airflow/dags/ext_packs/mediascope_data'
REPORT_PATH = f'{MEDIASCOPE_PATH}/mko_get_mediascope_data/settings/reports/sovcombank/nat_tv_tvreport.yaml'
OUTPUT_PATH = f'{MEDIASCOPE_PATH}/data/output/sovcombank'
SETTINGS = f'{MEDIASCOPE_PATH}/mko_get_mediascope_data/settings/connections/mediascope.json'

REPORT_SETTINGS = [
    REPORT_PATH,
    OUTPUT_PATH,
    SETTINGS
]


@dag(
    dag_id="Sovcombank_nat_tv_tvreport",
                    # .---------------- minute (0 - 59)
                    # |  .------------- hour (0 - 23)
                    # |  |  .---------- day of month (1 - 31)
                    # |  |  |  .------- month (1 - 12) OR jan,feb,mar,apr ...
                    # |  |  |  |  .---- day of week (0 - 6) (Sunday=0 or 7) OR sun,mon,tue,wed,thu,fri,sat
                    # |  |  |  |  |
                    # *  *  *  *  * user-name command to be executed
    schedule_interval="07 05 06 * *",  # 05 07 Every 6th of a month|  minute (0-59), hour (0-23, 0 = midnight), day (1-31), month (1-12), weekday (0-6, 0 = Sunday).
    start_date=pendulum.datetime(2024, 1, 1, tz='Europe/Moscow'),
    catchup=False,
    tags=["sovcombank", 'tv', 'tvreport'],
)
def dag_wrapper():
    @task
    def build_report(report_settings):
        return list(get_data(*report_settings))

    @task.bash
    def load(folder) -> str:
        params = {
            'script_file': f'python3 {LOADER_PATH}',
            'arg': f'-up',
            'source_path': f'{OUTPUT_PATH}/{folder}',
            'destination_path': f'sovcombank/{folder}',
            'parent_id': f'1YtkAcIHDdUKIqWvLHxxALgwrgDMZupAt'
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
    load.expand(folder=folders) >> flush_folder.expand(folder=folders)


dag_wrapper()
