#!/bin/bash
# Copyright (C) 2019 Rama Bondan Prakoso (rama982)
# Copyright (C) 2021 alanndz @ github & telegram
# Scripts to merge / upstream kernel drivers (wifi and audio)
# for msm-4.4+

cwd=$(pwd)

while (( ${#} )); do
  case ${1} in
       "-a"|"--audio") AUDIO=true ;;
       "-i"|"--init") INIT=true ;;
       "-w"|"--wlan") WLAN=true ;;
       "-p"|"--prima") PRIMA=true ;;
       "-d"|"--data") DATA=true ;;
       "-k"|"--kernelsu") KSU=true ;;
       "-t"|"--tag") shift; TAG=${1} ;;
       "-u"|"--update") UPDATE=true ;;
       "-C"|"--dir") shift; DIRS=${1} ;;
       "-e"|"--exfat") EXFAT=true ;;
       "-g"|"--wireguard") WIREGUARD=true ;;
  esac
  shift
done

[[ -n ${DIRS} ]] && {
  echo "Entering ${DIRS}"
  cd ${DIRS}
}

[[ -n ${INIT} && -n ${UPDATE} ]] && { echo "Both init and update were specified!"; exit; }

[[ -z ${TAG} ]] && { echo "No tag was specified!"; exit; }

function drivers()
{
  if [[ $4 == "wlan" ]]; then
     PREFIX="staging"
     NAME="$1/$3"
  elif [[ $4 == "fs" ]]; then
     PREFIX=fs
     NAME=$1
  elif [[ $4 == "wireguard" ]]; then
     PREFIX=net
     NAME=$1
  elif [[ $4 == "kernelsu" ]]; then
     PREFIX=drivers
     NAME=$1
  else
     PREFIX=techpack
     NAME=$1
  fi
  echo "${3}"
  git fetch "$2/$3" "${TAG}"
  if [[ -n ${INIT} ]]; then
    #git merge -s ours --no-commit --allow-unrelated-histories FETCH_HEAD
    git read-tree --prefix="${NAME}" -u FETCH_HEAD
    [[ $? -eq 1 ]] && { exit; }
    git commit -m "${PREFIX}: ${3}: Add from ${TAG}" -s
  elif [[ -n ${UPDATE} ]]; then
    git merge --no-edit -m "${PREFIX}: ${3}: Merge tag '${TAG}' into $(git rev-parse --abbrev-ref HEAD)"  \
              -m "$(git log --oneline --no-merges $(git branch | grep "\*" | sed 's/\* //')..FETCH_HEAD)" \
              -X subtree="${NAME}" --signoff FETCH_HEAD
  fi
}

if [[ -n ${WLAN} ]]; then
  SUBFOLDER_WLAN=drivers/staging
  URL_WLAN=https://git.codelinaro.org/clo/la/platform/vendor/qcom-opensource/wlan
  if [[ -z ${PRIMA} ]]; then
    REPOS_WLAN=( "fw-api" "qcacld-3.0" "qca-wifi-host-cmn" )
  else
    REPOS_WLAN=( "prima" )
  fi
  for REPO in "${REPOS_WLAN[@]}"; do
    drivers $SUBFOLDER_WLAN $URL_WLAN $REPO wlan
  done
fi

if [[ -n ${AUDIO} ]]; then
  SUBFOLDER_AUDIO=techpack/audio
  REPO_AUDIO=( "audio-kernel" )
  URL_AUDIO=https://git.codelinaro.org/clo/la/platform/vendor/opensource
  drivers $SUBFOLDER_AUDIO $URL_AUDIO $REPO_AUDIO
fi

if [[ -n ${DATA} ]]; then
  SUBFOLDER_DATA=techpack/data
  REPO_DATA=( "data-kernel" )
  URL_DATA=https://git.codelinaro.org/clo/la/platform/vendor/qcom-opensource
  drivers $SUBFOLDER_DATA $URL_DATA $REPO_DATA
fi

if [[ -n ${EXFAT} ]]; then
  SUBFOLDER_EXFAT=fs/exfat
  REPO_EXFAT=( "exfat-linux" )
  URL_EXFAT=https://github.com/arter97
  drivers $SUBFOLDER_EXFAT $URL_EXFAT $REPO_EXFAT fs
fi

if [[ -n ${WIREGUARD} ]]; then
  SUBFOLDER_WG=net/wireguard
  REPO_WG=( "wireguard-linux-compat" )
  URL_WG=https://git.zx2c4.com
  drivers $SUBFOLDER_WG $URL_WG $REPO_WG wireguard
fi

if [[ -n ${KSU} ]]; then
  SUBFOLDER_KSU=KernelSU
  REPO_KSU=( "KernelSU" )
  URL_KSU=https://github.com/tiann
  drivers $SUBFOLDER_KSU $URL_KSU $REPO_KSU kernelsu
  cd drivers
  ln -sf "../KernelSU/kernel" "kernelsu"
  git add kernelsu && git commit -m "drivers: kernelsu: Link to KernelSU"
  cd ${DIRS}
fi

[[ -n ${DIRS} ]] && { echo "Entering ${cwd}"; cd ${cwd}; }
