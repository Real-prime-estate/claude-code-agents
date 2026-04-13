---
name: analyze
description: 현재 프로젝트를 분석하여 아키텍처, 기술 스택, 코드 품질, 최근 활동을 파악한다. 분석 결과를 메모리와 프로젝트 파일로 저장.
metadata:
  priority: 6
  promptSignals:
    phrases:
      - "프로젝트 분석"
      - "코드베이스 파악"
      - "구조 분석"
    noneOf:
      - "토론"
      - "코드 작성"
      - "수정"
    minScore: 6
---

# Analyze: 프로젝트 분석

현재 작업 디렉토리의 프로젝트를 분석하여 컨텍스트를 생성합니다.

## 인자 파싱

사용자 입력: `$ARGUMENTS`

옵션:
- `--brief`: 간략 모드 (기본값)
- `--full`: 상세 모드 (4축 전체)
- 인자 없으면: 상세 모드

## 실행 프로토콜

### Phase 0: 프로젝트 식별

1. 현재 작업 디렉토리 확인
2. 프로젝트명 추출 (디렉토리명 또는 package.json/Makefile에서)
3. git 저장소 여부 확인

### Phase 1: 분석가 에이전트 스폰

Agent 도구로 `agents:project-analyzer` 에이전트를 스폰한다:

```
Agent(
  subagent_type="agents:project-analyzer",
  description="프로젝트 분석: {프로젝트명}",
  prompt="
    ## 분석 대상
    프로젝트 경로: {현재 작업 디렉토리}
    프로젝트명: {프로젝트명}
    모드: {brief 또는 full}

    ## 산출물 저장 경로
    메모리 요약: ~/.claude/projects/{프로젝트 경로 인코딩}/memory/project_{프로젝트명}.md
    상세 분석: {프로젝트 경로}/.claude/analysis.md

    ## 지시
    {모드}에 따라 분석을 수행하고, 산출물을 Write 도구로 저장하라.
    모든 응답은 한국어로 작성.
  "
)
```

### Phase 2: 결과 확인

1. 에이전트 완료 후 메모리 파일과 분석 파일이 생성되었는지 확인
2. 사용자에게 분석 결과 요약 표시

## 복잡도 자동 판단

**실행**: "이 프로젝트 뭐야?", "코드베이스 파악해", "구조 분석해"
**무시**: 코드 작성/수정/토론 요청
