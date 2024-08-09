#!/bin/bash

INSTANCE_IDS=(1 2) # instance id's
PROJECT_ID="8" # id of the project to sync
CONTROLLER_URL="controller.example.com" # without http or https
CONTROLLER_USERNAME="admin" # username to controller
CONTROLLER_PASSWORD="superSecretPassword" # password to controller

ROUND=0

## check if jq is installed
if [[ $(jq --help >/dev/null 2>&1; echo $?) != "0" ]]; then
  echo "jq package is required for script"
  exit 42
fi

for INSTANCE in ${INSTANCE_IDS[@]}; do
  KEEP_ENABLE="${INSTANCE_IDS[$ROUND]}"

  # echo "$KEEP_ENABLE $ROUND"
  for INSTANCE_INCEPTION in ${INSTANCE_IDS[@]}; do
    if [[ $INSTANCE_INCEPTION == $KEEP_ENABLE ]]; then
      echo "Enabling Instance $INSTANCE_INCEPTION"
      curl -X PATCH -H "Content-Type: application/json" -d '{"enabled": true}' https://${CONTROLLER_URL}/api/v2/instances/${INSTANCE_INCEPTION}/ -u "${CONTROLLER_USERNAME}:${CONTROLLER_PASSWORD}" 2>/dev/null
      echo
    else
      echo "Disabling Instance $INSTANCE_INCEPTION"
      curl -X PATCH -H "Content-Type: application/json" -d '{"enabled": false}' https://${CONTROLLER_URL}/api/v2/instances/${INSTANCE_INCEPTION}/ -u "${CONTROLLER_USERNAME}:${CONTROLLER_PASSWORD}" 2>/dev/null
      echo
    fi
  done

  SYNCED=0
  # run project sync
  until [[ $SYNCED == 1 ]]; do

    echo "Running project sync..."
    PROJECT_SYNC=$(curl -X POST https://${CONTROLLER_URL}/api/v2/projects/${PROJECT_ID}/update/ -u "${CONTROLLER_USERNAME}:${CONTROLLER_PASSWORD}" 2>/dev/null)
    PROJECT_SYNC_URL=$(echo "${PROJECT_SYNC}" | jq -r .url)

    while true; do
      echo "Checking if project sync finished..."
      if [[ $(curl https://${CONTROLLER_URL}${PROJECT_SYNC_URL} -u "${CONTROLLER_USERNAME}:${CONTROLLER_PASSWORD}" 2>/dev/null | jq -r .status) == 'successful' ]]; then
          echo "Project synced."
          SYNCED=1
          break
      elif [[ $(curl https://${CONTROLLER_URL}${PROJECT_SYNC_URL} -u "${CONTROLLER_USERNAME}:${CONTROLLER_PASSWORD}" 2>/dev/null | jq -r .status) == 'failed' ]]; then
          echo "Project sync failed."
          break
      fi
      sleep 5
    done
  done
  let ROUND++
  sleep 5
done

## Enable all
for INSTANCE2 in ${INSTANCE_IDS[@]}; do
  echo "Enabling Instance $INSTANCE2"
  curl -X PATCH -H "Content-Type: application/json" -d '{"enabled": true}' https://${CONTROLLER_URL}/api/v2/instances/${INSTANCE2}/ -u "${CONTROLLER_USERNAME}:${CONTROLLER_PASSWORD}" 2>/dev/null
  echo
done
