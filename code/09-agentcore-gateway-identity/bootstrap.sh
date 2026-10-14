#!/usr/bin/env bash
# Chapter 9 bootstrap for events launched from mainline: pulls the chapter folder
# into the code-server workspace and grants the two IAM permissions it needs.
set -euo pipefail

cd ~/workspace/my-workspace/code

echo "1) Downloading chapter 9 files..."
curl -sL https://github.com/amsypark/sample-aws-agentic-ai-workshop/archive/refs/heads/gateway-identity-chapter.tar.gz \
  | tar xz --strip-components=2 sample-aws-agentic-ai-workshop-gateway-identity-chapter/code/09-agentcore-gateway-identity

echo "2) Granting cognito-idp and secretsmanager permissions to the code-server role..."
aws iam put-role-policy --role-name strand-iamrole-developer --policy-name ch9-gateway-identity \
  --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":"cognito-idp:*","Resource":"*"},{"Effect":"Allow","Action":"secretsmanager:*","Resource":"arn:aws:secretsmanager:*:*:secret:bedrock-agentcore-identity!*"}]}'

echo "3) Waiting 10s for the IAM change to propagate..."
sleep 10

echo
echo "Done. Files in 09-agentcore-gateway-identity/labs:"
ls 09-agentcore-gateway-identity/labs
echo
echo "Next: cd 09-agentcore-gateway-identity/labs && uv run setup_gateway.py"
