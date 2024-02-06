#!/bin/bash

aws-vault export tiry-dev --format=ini > ~/.aws/credentials ; sed -i '' '1s/.*/[default]/' ~/.aws/credentials

