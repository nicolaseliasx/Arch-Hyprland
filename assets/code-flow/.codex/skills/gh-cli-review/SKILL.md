---
name: gh-cli-review
description: Carrega contexto completo de issues e pull requests via gh CLI e publica reviews inline selecionados. Use quando Codex precisar consultar PRs, issues, comentarios, reviews ou threads sem MCP do GitHub, quando o usuario pedir para carregar um numero no repositorio Git atual, preparar achados numerados de code review, ou enviar somente os comentarios que o usuario selecionar por numero.
---

# GitHub CLI Review

Usar `scripts/gh_cli_review.py` para operacoes agregadas. Usar `gh` diretamente para consultas simples que um unico comando nativo ja resolve.

## Contexto

1. Confirmar a credencial local com `gh auth token -h github.com >/dev/null`. Nao concluir que o token e invalido apenas porque `gh auth status` falhou: esse comando tambem falha quando a sessao Codex esta sem rede.
2. Tratar o repositorio Git do diretorio atual como fonte de verdade em qualquer projeto. Quando o usuario disser apenas "carrega 123", "veja 123" ou equivalente, procurar o numero nesse repositorio; nao pedir `owner/repo` nem assumir um projeto conhecido. O script resolve esse contexto com `gh repo view`. Usar `-R owner/repo` somente fora de um checkout GitHub ou quando o usuario indicar outro repositorio ou uma URL.
3. Inferir PR ou issue pelas palavras do pedido. Se o usuario fornecer somente um numero sem dizer o tipo, tentar primeiro `pr-context ID` e, se o ID nao for um PR, tentar `issue-context ID`.
4. Executar `pr-context [PR|URL|branch] [-R owner/repo]` para PRs ou `issue-context ISSUE [-R owner/repo]` para issues.
5. Em repositorios instalados pelo codex-flow, usar `--materialize .codex/codereview` apenas quando um comando legado precisar dos arquivos locais.
6. Inspecionar o diff real separadamente; contexto remoto nao substitui o diff.

## Review selecionavel

1. Produzir achados objetivos, cada um com um unico comentario canonico.
2. Mostrar na conversa a lista numerada completa antes de qualquer escrita no GitHub.
3. Gravar `.codex/codereview/review-draft.json` com:

```json
{
  "version": 1,
  "repository": "owner/repo",
  "pull_request": 123,
  "head_sha": "sha",
  "comments": [
    {"id": 1, "path": "src/file.py", "line": 42, "side": "RIGHT", "body": "Texto exato"}
  ]
}
```

4. Pedir que o usuario responda somente com os numeros desejados. A selecao autoriza apenas os textos ja exibidos.
5. Depois da selecao, executar primeiro `publish-review --draft ARQUIVO --select 1,3` para conferir o payload e entao repetir com `--send`.
6. Nunca enviar no mesmo turno em que os achados foram apresentados. Nunca adicionar comentarios nao selecionados ou alterar o texto depois da selecao.

O script publica um unico review `COMMENT`. Cada comentario comeca com `*Achados com auxílio de IA*`. SHA alterado, ancora fora do diff ou payload invalido devem abortar todo o envio; nao converter silenciosamente em comentario geral.
