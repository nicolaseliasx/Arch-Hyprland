#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, NoReturn


def fail(message: str) -> NoReturn:
    raise SystemExit(message)


def run(cmd: list[str], *, stdin: str | None = None) -> str:
    result = subprocess.run(cmd, input=stdin, capture_output=True, text=True)
    if result.returncode:
        detail = result.stderr.strip() or f"comando falhou: {' '.join(cmd[:3])}"
        lowered = detail.lower()
        if any(marker in lowered for marker in ("error connecting to", "could not resolve host", "failed to connect", "network is unreachable", "temporary failure in name resolution")):
            fail(f"falha de rede ao acessar o GitHub; a credencial local existe, mas esta sessao pode estar sem acesso a rede. Detalhe: {detail}")
        if "http 401" in lowered or "bad credentials" in lowered:
            fail(f"credencial rejeitada pelo GitHub. Detalhe: {detail}")
        fail(detail)
    return result.stdout


def run_json(cmd: list[str], *, stdin: str | None = None) -> Any:
    try:
        return json.loads(run(cmd, stdin=stdin))
    except json.JSONDecodeError as error:
        fail(f"gh retornou JSON invalido: {error}")


def auth() -> None:
    result = subprocess.run(["gh", "auth", "token", "-h", "github.com"], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
    if result.returncode:
        fail("nenhuma credencial local do gh para github.com; execute `gh auth login -h github.com`")


def repo_from_url(target: str | None) -> str | None:
    if not target:
        return None
    match = re.match(r"https://github\.com/([^/]+/[^/]+)/(?:pull|issues)/\d+", target)
    return match.group(1) if match else None


def resolve_repo(repo: str | None, target: str | None = None) -> str:
    if repo:
        return repo.removesuffix(".git")
    if parsed := repo_from_url(target):
        return parsed
    return run(["gh", "repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner"]).strip()


def flatten(pages: list[list[Any]]) -> list[Any]:
    return [item for page in pages for item in page]


def api_pages(endpoint: str) -> list[Any]:
    return flatten(run_json(["gh", "api", endpoint, "--paginate", "--slurp"]))


PR_FIELDS = ",".join(
    [
        "number", "url", "title", "body", "state", "isDraft", "author",
        "baseRefName", "headRefName", "headRefOid", "labels", "assignees",
        "milestone", "files", "commits", "statusCheckRollup",
    ]
)


def resolve_pr(target: str | None, repo: str) -> dict[str, Any]:
    if not target:
        return run_json(["gh", "pr", "view", "-R", repo, "--json", PR_FIELDS])
    if re.fullmatch(r"#?\d+", target) or "/pull/" in target:
        return run_json(["gh", "pr", "view", target.lstrip("#"), "-R", repo, "--json", PR_FIELDS])
    matches = run_json(["gh", "pr", "list", "-R", repo, "--head", target, "--state", "open", "--json", "number"])
    if len(matches) != 1:
        fail(f"esperado um PR aberto para a branch {target}; encontrados: {len(matches)}")
    return run_json(["gh", "pr", "view", str(matches[0]["number"]), "-R", repo, "--json", PR_FIELDS])


THREAD_QUERY = """
query($owner:String!,$name:String!,$number:Int!,$endCursor:String) {
  repository(owner:$owner,name:$name) {
    pullRequest(number:$number) {
      closingIssuesReferences(first:100) { nodes { number title body url state } }
      reviewThreads(first:100,after:$endCursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id isResolved isOutdated path line diffSide startLine startDiffSide originalLine originalStartLine
          comments(first:100) {
            totalCount
            nodes { id databaseId body createdAt updatedAt url author { login } path line originalLine }
          }
        }
      }
    }
  }
}
"""


def pr_context(target: str | None, repo_arg: str | None) -> dict[str, Any]:
    auth()
    repo = resolve_repo(repo_arg, target)
    pr = resolve_pr(target, repo)
    number = int(pr["number"])
    owner, name = repo.split("/", 1)
    graph_pages = run_json(
        [
            "gh", "api", "graphql", "--paginate", "--slurp",
            "-F", f"owner={owner}", "-F", f"name={name}", "-F", f"number={number}",
            "-f", f"query={THREAD_QUERY}",
        ]
    )
    linked: list[Any] = []
    threads: list[Any] = []
    for page in graph_pages:
        node = page["data"]["repository"]["pullRequest"]
        if not linked:
            linked = node["closingIssuesReferences"]["nodes"]
        threads.extend(node["reviewThreads"]["nodes"])
    return {
        "repository": repo,
        "pullRequest": pr,
        "linkedIssues": linked,
        "conversationComments": api_pages(f"repos/{repo}/issues/{number}/comments?per_page=100"),
        "reviews": api_pages(f"repos/{repo}/pulls/{number}/reviews?per_page=100"),
        "reviewComments": api_pages(f"repos/{repo}/pulls/{number}/comments?per_page=100"),
        "reviewThreads": threads,
    }


ISSUE_FIELDS = "number,url,title,body,state,author,labels,assignees,milestone"


def issue_context(target: str, repo_arg: str | None) -> dict[str, Any]:
    auth()
    repo = resolve_repo(repo_arg, target)
    issue = run_json(["gh", "issue", "view", target.lstrip("#"), "-R", repo, "--json", ISSUE_FIELDS])
    issue["comments"] = api_pages(f"repos/{repo}/issues/{issue['number']}/comments?per_page=100")
    return {"repository": repo, "issue": issue}


def quote(text: str | None) -> str:
    return "\n".join(f"> {line}" if line else ">" for line in (text or "_sem conteudo_").splitlines())


def materialize(context: dict[str, Any], directory: Path, commit: str | None = None) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    pr = context["pullRequest"]
    (directory / "github-pr-context.json").write_text(json.dumps(context, ensure_ascii=False, indent=2) + "\n")
    lines = [
        "# Contexto de PR via gh CLI", "", f"- Repositorio: {context['repository']}",
        f"- PR: #{pr['number']} - {pr['title']}", f"- URL: {pr['url']}",
        f"- Base: {pr['baseRefName']}", f"- Head: {pr['headRefName']}",
        f"- SHA: {pr['headRefOid']}", "", "## Descricao do PR", "", quote(pr.get("body")),
    ]
    for heading, key in (("Comentarios", "conversationComments"), ("Reviews", "reviews"), ("Threads inline", "reviewThreads")):
        lines += ["", f"## {heading}", "", f"_Consulte `{directory / 'github-pr-context.json'}` ({len(context[key])} itens)._" ]
    (directory / "github-pr-comments.md").write_text("\n".join(lines).rstrip() + "\n")
    summary = [
        "# Contexto de review via gh CLI", "", f"- Repositorio: {context['repository']}",
        f"- PR resolvido: #{pr['number']}", f"- URL do PR: {pr['url']}",
        f"- Base do PR: {pr['baseRefName']}", f"- Head do PR: {pr['headRefName']}",
        f"- SHA do PR: {pr['headRefOid']}", f"- JSON do PR: {directory / 'github-pr-context.json'}",
        f"- Markdown de comentarios: {directory / 'github-pr-comments.md'}",
    ]
    if commit:
        summary.append(f"- Commit ancora: {commit}")
    (directory / "github-review-context.md").write_text("\n".join(summary) + "\n")
    issue_file = directory / "github-issue-context.json"
    if len(context["linkedIssues"]) == 1:
        issue_file.write_text(json.dumps(context["linkedIssues"][0], ensure_ascii=False, indent=2) + "\n")
    elif issue_file.exists():
        issue_file.unlink()


def parse_selection(raw: str) -> list[int]:
    try:
        selected = [int(value) for value in re.split(r"[\s,]+", raw.strip()) if value]
    except ValueError:
        fail("selecao invalida; use numeros separados por virgula")
    if not selected or len(selected) != len(set(selected)):
        fail("a selecao deve conter IDs unicos")
    return selected


def changed_lines(files: list[dict[str, Any]]) -> set[tuple[str, int, str]]:
    anchors: set[tuple[str, int, str]] = set()
    for file in files:
        old_line = new_line = 0
        for line in (file.get("patch") or "").splitlines():
            if match := re.match(r"@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@", line):
                old_line, new_line = map(int, match.groups())
            elif line.startswith("+") and not line.startswith("+++"):
                anchors.add((file["filename"], new_line, "RIGHT")); new_line += 1
            elif line.startswith("-") and not line.startswith("---"):
                anchors.add((file["filename"], old_line, "LEFT")); old_line += 1
            elif line.startswith(" "):
                anchors.add((file["filename"], new_line, "RIGHT")); old_line += 1; new_line += 1
    return anchors


def review_payload(draft: dict[str, Any], selection: str) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    required = {"version", "repository", "pull_request", "head_sha", "comments"}
    if not isinstance(draft, dict) or not required <= draft.keys() or draft["version"] != 1:
        fail("rascunho invalido ou versao nao suportada")
    if not isinstance(draft["repository"], str) or not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", draft["repository"]):
        fail("repositorio invalido no rascunho")
    if not isinstance(draft["pull_request"], int) or draft["pull_request"] < 1:
        fail("numero de PR invalido no rascunho")
    if not isinstance(draft["head_sha"], str) or not re.fullmatch(r"[0-9a-fA-F]{40,64}", draft["head_sha"]):
        fail("head SHA invalido no rascunho")
    by_id = {item.get("id"): item for item in draft["comments"] if isinstance(item, dict)}
    ids = parse_selection(selection)
    if missing := [item_id for item_id in ids if item_id not in by_id]:
        fail(f"IDs inexistentes: {missing}")
    chosen = [by_id[item_id] for item_id in ids]
    comments = []
    for item in chosen:
        if item.get("side") not in {"LEFT", "RIGHT"} or not isinstance(item.get("line"), int) or item["line"] < 1:
            fail(f"ancora invalida no achado {item.get('id')}")
        if not all(isinstance(item.get(key), str) and item[key].strip() for key in ("path", "body")):
            fail(f"conteudo invalido no achado {item.get('id')}")
        comments.append({
            "path": item["path"], "line": item["line"], "side": item["side"],
            "body": f"*Achados com auxílio de IA*\n\n{item['body'].strip()}",
        })
    return {
        "commit_id": draft["head_sha"], "body": f"Review com {len(comments)} achado(s) selecionado(s).",
        "event": "COMMENT", "comments": comments,
    }, chosen


def publish(draft_path: Path, selection: str, send: bool) -> None:
    try:
        draft = json.loads(draft_path.read_text())
    except (OSError, json.JSONDecodeError) as error:
        fail(f"nao foi possivel ler o rascunho: {error}")
    payload, chosen = review_payload(draft, selection)
    if not send:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
        return
    auth()
    repo = draft["repository"]
    number = int(draft["pull_request"])
    current = run_json(["gh", "pr", "view", str(number), "-R", repo, "--json", "headRefOid"])
    if current["headRefOid"] != draft["head_sha"]:
        fail("o SHA do PR mudou; gere um novo review antes de publicar")
    files = api_pages(f"repos/{repo}/pulls/{number}/files?per_page=100")
    anchors = changed_lines(files)
    invalid = [item["id"] for item in chosen if (item["path"], item["line"], item["side"]) not in anchors]
    if invalid:
        fail(f"achados fora do diff atual: {invalid}")
    result = run_json(
        ["gh", "api", "-X", "POST", f"repos/{repo}/pulls/{number}/reviews", "--input", "-"],
        stdin=json.dumps(payload),
    )
    print(json.dumps({"id": result.get("id"), "state": result.get("state"), "html_url": result.get("html_url")}, ensure_ascii=False))


def self_test() -> None:
    draft = {
        "version": 1, "repository": "acme/app", "pull_request": 7, "head_sha": "a" * 40,
        "comments": [
            {"id": 1, "path": "a.py", "line": 2, "side": "RIGHT", "body": "Primeiro"},
            {"id": 2, "path": "a.py", "line": 3, "side": "LEFT", "body": "Segundo"},
        ],
    }
    payload, chosen = review_payload(draft, "2")
    assert [item["id"] for item in chosen] == [2]
    assert payload["event"] == "COMMENT" and payload["comments"][0]["body"].startswith("*Achados")
    patch = [{"filename": "a.py", "patch": "@@ -1,2 +1,2 @@\n same\n-old\n+new"}]
    assert ("a.py", 2, "LEFT") in changed_lines(patch)
    assert ("a.py", 2, "RIGHT") in changed_lines(patch)
    print("self-test OK")


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description="Contexto e reviews GitHub via gh CLI")
    sub = root.add_subparsers(dest="command", required=True)
    pr = sub.add_parser("pr-context")
    pr.add_argument("target", nargs="?"); pr.add_argument("-R", "--repo")
    pr.add_argument("--materialize", type=Path); pr.add_argument("--commit")
    issue = sub.add_parser("issue-context")
    issue.add_argument("target"); issue.add_argument("-R", "--repo")
    review = sub.add_parser("publish-review")
    review.add_argument("--draft", required=True, type=Path); review.add_argument("--select", required=True)
    review.add_argument("--send", action="store_true")
    sub.add_parser("self-test")
    return root


def main() -> None:
    args = parser().parse_args()
    if args.command == "pr-context":
        context = pr_context(args.target, args.repo)
        if args.materialize:
            materialize(context, args.materialize, args.commit)
        print(json.dumps(context, ensure_ascii=False, indent=2))
    elif args.command == "issue-context":
        print(json.dumps(issue_context(args.target, args.repo), ensure_ascii=False, indent=2))
    elif args.command == "publish-review":
        publish(args.draft, args.select, args.send)
    else:
        self_test()


if __name__ == "__main__":
    main()
