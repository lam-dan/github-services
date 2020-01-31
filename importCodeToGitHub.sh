#! /usr/bin/env /bin/bash

###################################################################
# Script Name : importCodeToGitHub.sh
# Description : Plume new code drop in AWS S3 bucket, fetch and import to CC repos
###################################################################

# Global variables 
export _STGDIR=~/Plume/downloads
export _Base=~/Plume/mesh
# export _Base=~/Documents/mesh

echo -n "Please enter release number (eg. 1.49.2-rc1): "
read release
export _Release=${release}
export _Pname="plume-cloud"
# export _Sufix="source"
export _Sufix="master-source"
export _Branch=${_Release%-*}
export _FileExt=".tar.gz"

# Change token for other users using this script
export GITHUB_TOKEN="secretkey"
export do_not_process_list=(akka-zk-cluster-seed cloud-middleware cloudServicesConfig-chi-staging eslint-config-plume-v event-manager plume-akka subscription)

# Create folders
echo -e "\033[37mStarting Scripts..."
create_folders () {
  echo -e "\033[37mChecking for required directories."
  cd ~/Plume/
  echo -e "\033[37m  - Checking for Downloads folder... (1/7)"
  if [ ! -d "downloads" ]
    then
      echo -e "\033[37m  - Downloads folder does not exist. Creating Folder... (2/7)"  
      mkdir -p ./downloads
      echo -e "\033[37m  - Folder created at ${_STGDIR}. (3/7)"
    fi
  echo -e "\033[37m  - Checking for Mesh folder (4/7)"
  if [ ! -d "mesh" ]
    then
      echo -e "\033[37m  - mesh folder does not exist. Creating Folder... (5/7)"  
      mkdir -p ./mesh
      cd ${_Base}
      echo -e "\033[37m  - Folder created at ${_Base}. (6/7)"
      echo -e "\033[37m  - Cloning all repositories from GitHub into ${_Base}. (7/7)"
      curl -X GET -u ${GITHUB_TOKEN}:x-oauth-basic https://github.comcast.com/api/v3/orgs/mesh/repos?per_page=200 2> /dev/null |
      awk '/full_name/' | awk -F "\/" '{print $2}' | sed 's/",//g'  > ${_Base}/temp
      cat temp | 
      while read line
      do 
        git clone git@github.comcast.com:mesh/$line
        echo $line;
      done
      rm rf temp
      echo -e "\033[32mSUCCESSFULLY CLONED GITHUB REPOSITORIES."
    fi
    echo -e "\033[32mSUCCESSFULLY COMPLETED FOLDER REQUIREMENTS."
}

# Download the Plume source from AWS S3 and open the tgz file in the staging area. 
# Put it in the folder with the same name as the tgz file.
# Move 4 files into renamed folder names
fetch_s3_ball () {
  echo -e "\033[37mSourcing the Data."
  echo -e "\033[37m  - Fetching source file from AWS. (1/2)"
  aws --profile saml s3 cp s3://mesh-prod-w2-source/${_Pname}-${_Release}-${_Sufix}${_FileExt} ${_STGDIR}
  echo -e "\033[37m  - Unpacking source file to ${_STGDIR}. (2/2)"
  tar xzf ${_STGDIR}/${_Pname}-${_Release}-${_Sufix}${_FileExt} -C ${_STGDIR}
  echo -e "\033[32mFETCHING DATA PROCESS COMPLETE."  
}

# Generate repos list from the source ball.
# Remove numbers from folder list names for each repo and put into write into new source_list file.
plume_source_list () {
  echo -e "\033[37mCleaning folder names."
  cd $(ls -d ${_STGDIR}/${_Pname}-${_Release}*/)
  echo -e "\033[37m  - Removing trailing version numbers folder names and writing to file ${_STGDIR}/source_list (1/1)"
  # In the current directory, find a directory and only return the 1st level.
  # Find by default is recursive and will go into directories and sub directories, thus we specify maxdepth as 1st level
  find . -type d -maxdepth 1 | cut -d "/" -f2 | 
  while read D
  do
    H=$(echo ${D} | awk -F"[0-9]*" '{print $1}')
    echo ${H%-}
  done | sort -u | sed '/\./d' > ${_STGDIR}/source_list 
  cat -- ${_STGDIR}/source_list 
  echo -e "\033[32mSUCCESSFULLY CREATED NEW FILE."
}

# Download list of repo names from github and save in mesh_list folder
# Compare list from mesh_list folder with source_list folder list and exit if there are differences
# Check with Suret and if it is have Ahmandeep create a new repo in Mesh repository since he has permission to do so
check_if_new_repo () {
  # get mesh full repo list
  echo -e "\033[37mNew repository check."
  echo -e "\033[37m  - Getting mesh repository names from github mesh and writing to file ${_STGDIR}/mesh_list (1/2)"
  curl -X GET -u ${GITHUB_TOKEN}:x-oauth-basic https://github.comcast.com/api/v3/orgs/mesh/repos?per_page=200 2> /dev/null |
  awk '/full_name/' | awk -F "\/" '{print $2}' | sed 's/",//g'  > ${_STGDIR}/mesh_list

  # check if there is new repo name
  echo -e "\033[37m  - Comparing github repo list names vs the aws repo list to see if there are differences. (2/2)"

  # printf -- '\037\[37m Comparing github repo list names vs the aws repo list to see if there are differences. \037[0m\n';
  _Found=$(grep -v -F -f ${_STGDIR}/mesh_list ${_STGDIR}/source_list)
  if [[ ! -z ${_Found} ]]
  then
    echo -e "\033[33mWARNING: NEW REPO NAME FOUND: ${_Found}"
    exit 1
  fi
  echo -e "\033[32mSUCCESSFULLY COMPLETED CHECK."
}

# Cleanup source list repo name 
# We filter out the do not process list because they already contain the tags
clean_source_list () {
  echo -e "\033[37mFilter out uneeded repositories."
  echo -e "\033[37m  - Filtering out repositories that should not be pushed into Github. (1/1)"
  full_list=($(cat ${_STGDIR}/source_list | tr '\n' ' '))
  for RR in ${do_not_process_list[@]}
  do
    full_list=( "${full_list[@]/${RR}/}" )
  done
  export full_list
  # echo $full_list
  echo -e "\033[32mSUCCESSFULLY COMPLETED FILTERING OF SOURCE LIST."
}

# New branch and migrate the new code to repo
branching_newcode () {
  echo -e "\033[37mMigrate new code into Github mesh organization."
  echo -e "\033[37m  - Pushing each Github repository with the new version tag. (1/1)"
  for Repo in ${full_list[@]}
  do
    echo "--- ${Repo} ---"
    cd ${_Base}/${Repo}
    git checkout master
    git pull
    SHA=$(git log --oneline | tail -1 | awk '{print $1}')
    git checkout -b ${_Branch} ${SHA}
    mv -f ${_STGDIR}/${_Pname}-${_Release}-rc9-${_Sufix}/${Repo}/* ${_Base}/${Repo}
    mv -f ${_STGDIR}/${_Pname}-${_Release}-rc9-${_Sufix}/${Repo}/.??* ${_Base}/${Repo}
    git add -A
    git commit -m "${_Branch} code"
    git push --set-upstream origin ${_Branch}
    git branch -r
  done 
  echo -e "\033[32mSUCCESSFULLY COMPLETED PUSHING THE NEW REPOSITORIES INTO GITHUB."
}

# Clean up
clean_up () {
  echo -e "\033[37mCleaning up files."
  echo -e "\033[37m  - Moving the ${_STGDIR}/${_Pname}-${_Release}-*${_FileExt} files into ${_STGDIR}/archive."
  mv ${_STGDIR}/*${_FileExt} ${_STGDIR}/archive
  echo -e "\033[37m  - Deleting the ${_STGDIR}/${_Pname}-${_Release}* file."
  rm -rf ${_STGDIR}/${_Pname}-${_Release}*
  echo -e "\033[32mSUCCESSFULLY COMPLETED CLEAN UP."
}

# main: steps of process
# generate_token
create_folders
fetch_s3_ball
plume_source_list
check_if_new_repo
clean_source_list
branching_newcode
clean_up
