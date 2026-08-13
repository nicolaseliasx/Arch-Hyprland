---
name: clarify-task
description: Investigate planning, issue-analysis, solution-definition, and alternative-comparison requests; resolve decisions before delivering a chat-only plan.
---

# Clarify task

Use this skill only for explicit requests to plan, analyze an issue, define a
solution, or compare alternatives. Do not use it for direct implementation,
explanation, status, or review requests.

## Workflow

1. Read the request, `AGENTS.md`, applicable playbooks, documentation, and any
   supplied issue.
2. Investigate the current implementation, callers, tests, history, and
   integrations before asking questions.
3. Classify each point as evidence, decision required, research required, or
   not applicable.
4. Examine the complete matrix in `references/question-matrix.md`, explicitly
   dismissing points that are not applicable.
5. Ask adaptive rounds of two or three questions, only about open decisions or
   research that applies.
6. For every decision, show alternatives, impacts, risks, and a recommendation.
7. When the user says they do not know, research available sources and propose
   a solution. If evidence or a business decision is still missing, ask one
   objective research question and pause.
8. Facts demonstrated by the repository do not need approval. Require explicit
   approval for proposed decisions and solutions.
9. Finish only when no decisions or research remain open and the objective,
   limits, flows, failures, and acceptance criteria are defined.

## Delivery

Deliver a self-contained plan in chat with context, expected result, approved
decisions, relevant rejected alternatives, implementation, and validation.
Do not create `PLAN.md` or `latest.txt`, score ambiguity, limit rounds, or
commit automatically.
