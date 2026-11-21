#!/bin/sh
set -eu
DLQ_URL=$(awslocal sqs create-queue --queue-name bankcore-dlq --attributes MessageRetentionPeriod=1209600,SqsManagedSseEnabled=true --query QueueUrl --output text)
DLQ_ARN=$(awslocal sqs get-queue-attributes --queue-url "$DLQ_URL" --attribute-names QueueArn --query Attributes.QueueArn --output text)
awslocal sqs create-queue --queue-name bankcore-events --attributes "{\"VisibilityTimeout\":\"10\",\"MessageRetentionPeriod\":\"345600\",\"SqsManagedSseEnabled\":\"true\",\"RedrivePolicy\":\"{\\\"deadLetterTargetArn\\\":\\\"$DLQ_ARN\\\",\\\"maxReceiveCount\\\":\\\"3\\\"}\"}"

