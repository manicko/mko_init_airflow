#!/bin/bash
#
#Set up a git repo
mkdir -p "$AIRFLOW_HOME/dags/ext_packs/mediascope_data/"
cd "$AIRFLOW_HOME/dags/ext_packs/mediascope_data/" || exit
git init
git remote add origin 'https://github.com/manicko/mko_get_mediascope_data.git'

# Configure your git-repo to download only specific directories
git config core.sparseCheckout true # enable this
#Set the folder you like to be downloaded, e.g. you only
# want to download the doc directory from https://github.com/project-tree/master/doc
#E.g. if you only want to download the doc
# directory from your master repo https://github.com/project-tree/master/doc,
# then your command is echo "doc" > .git/info/sparse-checkout.

echo "settings" > .git/info/sparse-checkout
echo "settings" > .git/info/sparse-checkout
#Download your repo as usual
git pull origin master
