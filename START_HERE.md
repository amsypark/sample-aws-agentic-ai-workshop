# 챕터 9: AgentCore Gateway & Identity (시작 안내)

이 페이지는 mainline으로 띄운 이벤트에서 챕터 9를 추가로 진행할 때 쓰는 참가자용 안내입니다.

## 1. 코드서버 터미널에서 아래 한 줄을 실행하세요

```bash
curl -sL https://raw.githubusercontent.com/amsypark/sample-aws-agentic-ai-workshop/gateway-identity-chapter/code/09-agentcore-gateway-identity/bootstrap.sh -o /tmp/ch9.sh && bash /tmp/ch9.sh
```

챕터 9 파일을 받아오고, 실습에 필요한 IAM 권한 두 개를 추가한 뒤 10초 기다립니다. `Done.` 과 labs 파일 목록이 보이면 준비 끝입니다.

## 2. 가이드를 따라 실습하세요

- 한국어: [workshop/ko/09-agentcore-gateway-identity/README.md](workshop/ko/09-agentcore-gateway-identity/README.md)
- English: [workshop/en/09-agentcore-gateway-identity/README.md](workshop/en/09-agentcore-gateway-identity/README.md)

실행 순서 (모두 `09-agentcore-gateway-identity/labs` 폴더에서):

```bash
cd 09-agentcore-gateway-identity/labs
uv run setup_gateway.py
uv run gateway_agent.py
uv run outbound_auth_demo.py   # 선택
uv run cleanup.py
```

<details>
<summary>한 줄 명령 대신 직접 실행하고 싶다면</summary>

```bash
cd ~/workspace/my-workspace/code
curl -sL https://github.com/amsypark/sample-aws-agentic-ai-workshop/archive/refs/heads/gateway-identity-chapter.tar.gz | tar xz --strip-components=2 sample-aws-agentic-ai-workshop-gateway-identity-chapter/code/09-agentcore-gateway-identity
aws iam put-role-policy --role-name strand-iamrole-developer --policy-name ch9-gateway-identity --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":"cognito-idp:*","Resource":"*"},{"Effect":"Allow","Action":"secretsmanager:*","Resource":"arn:aws:secretsmanager:*:*:secret:bedrock-agentcore-identity!*"}]}'
```
</details>
