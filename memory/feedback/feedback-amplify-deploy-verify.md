---
name: feedback-amplify-deploy-verify
description: 배포 확인은 git push가 아니라 Amplify 잡 상태로; Amplify는 npm run ci 전체(테스트 포함)를 돌림
metadata: 
  node_type: memory
  type: feedback
  originSessionId: d5fa37fa-9083-4723-aa2f-118b43ccae7f
---

admin-web 배포(AWS Amplify Hosting, master 자동빌드)에서 **git push 성공 ≠ 배포 성공**.

**Why:** Amplify `amplify.yml`의 build는 `npm ci` 후 **`npm run ci`** 를 실행하고, `ci = build:strict = typecheck && lint && test && build` 다. 즉 **`tsc --noEmit`·`eslint . --max-warnings 0`·`vitest run`(전체 유닛테스트)·`next build`** 를 전부 통과해야 배포된다. 로컬에서 `next build`만 green이면 테스트/린트 실패를 못 잡는다. 실제로 MUI 전환 후 킷 유닛테스트(옛 Tailwind 클래스 단언)를 안 고쳐 잡 150~153이 전부 FAILED, 프로덕션이 옛 커밋(149)에 정체된 걸 한참 뒤에야 발견했다(나는 push만 보고 "배포됐다"고 잘못 단정).

**How to apply:**
1. master push 후 반드시 `aws amplify list-jobs --app-id d1a73bpt0mqv58 --branch-name master --max-items 3 --profile KMS --region ap-northeast-2 --query 'jobSummaries[].{id:jobId,status:status,commit:commitId}' --output text` 로 잡 상태(SUCCEED/FAILED) 확인.
2. 푸시 전 로컬에서 `cd admin-web && npm run ci` 를 돌려 Amplify와 동일 파이프라인을 재현(특히 컴포넌트 변경 시 대응 vitest 테스트도 함께 갱신).
3. 실패 로그는 `aws amplify get-job ... --query 'job.steps[0].logUrl'` 의 S3 URL을 curl.
4. UI 라이브 검증은 [[aws-migration-progress]]의 배포 URL에서.
