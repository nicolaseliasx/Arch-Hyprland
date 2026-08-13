#!/usr/bin/env zsh

__cf_err() {
  print -u2 -r -- "$*"
}

__cf_note() {
  print -r -- "$*"
}

__cf_abs_dir() {
  local dir="$1"
  (cd "$dir" && pwd -P)
}

__cf_repo_root() {
  command git rev-parse --show-toplevel 2>/dev/null
}

__cf_add_exclude_once() {
  local pattern="$1"
  local exclude_file="$2"

  mkdir -p "${exclude_file:h}" || return
  touch "$exclude_file" || return

  if ! grep -qxF -- "$pattern" "$exclude_file" 2>/dev/null; then
    print -r -- "$pattern" >> "$exclude_file"
  fi
}

__cf_configure_excludes() {
  local target_dir="$1"
  local exclude_file pattern

  exclude_file="$(command git -C "$target_dir" rev-parse --path-format=absolute --git-path info/exclude 2>/dev/null)" || {
    __cf_err "warning: could not resolve git info/exclude for $target_dir"
    return 0
  }

  for pattern in ".codex/" ".codex" "AGENTS.md" ".claude/" ".claude" "CLAUDE.md"; do
    __cf_add_exclude_once "$pattern" "$exclude_file" || return
  done
}

__cf_copy_snapshot() {
  local source_path="$1"
  local target_path="$2"
  local refresh="${3:-0}"

  [[ -e "$source_path" || -L "$source_path" ]] || return 0
  [[ "$source_path" == "$target_path" ]] && return 0

  if [[ -L "$target_path" ]]; then
    unlink "$target_path" || return
  elif [[ -e "$target_path" ]]; then
    if [[ "$refresh" == "1" ]]; then
      command rm -rf -- "$target_path" || return
    else
      return 0
    fi
  fi

  mkdir -p "${target_path:h}" || return
  cp -a "$source_path" "$target_path"
}

__cf_bootstrap_local_files() {
  local source_dir="$1"
  local target_dir="$2"
  local refresh="${3:-0}"
  local item

  source_dir="$(__cf_abs_dir "$source_dir")" || return
  target_dir="$(__cf_abs_dir "$target_dir")" || return

  __cf_configure_excludes "$target_dir" || return

  for item in ".codex" "AGENTS.md" ".claude" "CLAUDE.md"; do
    __cf_copy_snapshot "$source_dir/$item" "$target_dir/$item" "$refresh" || return
  done

  if (( $+functions[__cf_after_bootstrap_local_files] )); then
    __cf_after_bootstrap_local_files "$source_dir" "$target_dir" "$refresh" || return
  fi
}

__cf_parse_worktree_add_path() {
  shift 2

  while (( $# )); do
    case "$1" in
      --)
        shift
        print -r -- "$1"
        return
        ;;
      -b|-B|--orphan|--reason)
        shift 2
        ;;
      --orphan=*|--reason=*)
        shift
        ;;
      -*)
        shift
        ;;
      *)
        print -r -- "$1"
        return
        ;;
    esac
  done
}

__cf_each_worktree() {
  local line current_path
  current_path=""

  while IFS= read -r line; do
    if [[ "$line" == worktree\ * ]]; then
      current_path="${line#worktree }"
      print -r -- "$current_path"
    fi
  done < <(command git worktree list --porcelain)
}

__cf_collect_linked_worktrees() {
  local main_root="$1"
  local line worktree_path branch_ref branch_name
  local current_path="" current_branch=""

  while IFS= read -r line; do
    if [[ -z "$line" ]]; then
      if [[ -n "$current_path" && "$(__cf_abs_dir "$current_path" 2>/dev/null)" != "$main_root" ]]; then
        [[ -n "$current_branch" ]] && print -r -- "${current_path}"$'\t'"${current_branch}"
      fi
      current_path=""
      current_branch=""
      continue
    fi

    if [[ "$line" == worktree\ * ]]; then
      current_path="${line#worktree }"
      continue
    fi

    if [[ "$line" == branch\ refs/heads/* ]]; then
      branch_ref="${line#branch }"
      branch_name="${branch_ref#refs/heads/}"
      current_branch="$branch_name"
    fi
  done < <(command git worktree list --porcelain; print)
}

__cf_find_worktree_by_branch() {
  local wanted_branch="$1"
  local line branch_ref branch_name
  local current_path="" current_branch=""

  while IFS= read -r line; do
    if [[ -z "$line" ]]; then
      if [[ "$current_branch" == "$wanted_branch" && -n "$current_path" ]]; then
        print -r -- "$current_path"
        return 0
      fi
      current_path=""
      current_branch=""
      continue
    fi

    if [[ "$line" == worktree\ * ]]; then
      current_path="${line#worktree }"
      continue
    fi

    if [[ "$line" == branch\ refs/heads/* ]]; then
      branch_ref="${line#branch }"
      branch_name="${branch_ref#refs/heads/}"
      current_branch="$branch_name"
    fi
  done < <(command git worktree list --porcelain; print)

  return 1
}

__cf_source_root() {
  local root
  root="$(__cf_repo_root)" || {
    __cf_err "erro: execute dentro de um repositorio git"
    return 1
  }
  __cf_abs_dir "$root"
}

__cf_main_root() {
  local line worktree_path

  while IFS= read -r line; do
    if [[ "$line" == worktree\ * ]]; then
      worktree_path="${line#worktree }"
      __cf_abs_dir "$worktree_path"
      return
    fi
  done < <(command git worktree list --porcelain)

  return 1
}

__cf_path_is_registered() {
  local wanted_path="$1"
  local line current_path

  wanted_path="$(__cf_abs_dir "$wanted_path" 2>/dev/null)" || return 1
  while IFS= read -r line; do
    if [[ "$line" == worktree\ * ]]; then
      current_path="${line#worktree }"
      current_path="$(__cf_abs_dir "$current_path" 2>/dev/null)" || continue
      [[ "$current_path" == "$wanted_path" ]] && return 0
    fi
  done < <(command git worktree list --porcelain)

  return 1
}

__cf_remove_leftover_dir() {
  local repo_root="$1"
  local leftover_path="$2"
  local parent_dir repo_name

  repo_root="$(__cf_abs_dir "$repo_root")" || return
  if [[ "$leftover_path" != /* ]]; then
    leftover_path="${repo_root:h}/$leftover_path"
  fi
  parent_dir="${repo_root:h}"
  repo_name="${repo_root:t}"

  if [[ "$leftover_path" == "$repo_root" ]]; then
    __cf_err "erro: recusando remover o checkout principal: $leftover_path"
    return 1
  fi

  if [[ "$leftover_path" != "$parent_dir/$repo_name-"* ]]; then
    __cf_err "erro: recusando remover caminho fora do padrao de worktree: $leftover_path"
    return 1
  fi

  if __cf_path_is_registered "$leftover_path"; then
    __cf_err "erro: recusando remover pasta ainda registrada como worktree: $leftover_path"
    return 1
  fi

  if [[ -e "$leftover_path" ]]; then
    __cf_note "removendo sobra de worktree: $leftover_path"
    command rm -rf -- "$leftover_path"
  fi
}

wtfix() {
  local all=0
  local refresh=0
  local target=""
  local source_dir worktree_path
  local status_code=0

  while (( $# )); do
    case "$1" in
      --all)
        all=1
        shift
        ;;
      --refresh)
        refresh=1
        shift
        ;;
      -h|--help)
        wthelp
        return 0
        ;;
      *)
        if [[ -n "$target" ]]; then
          __cf_err "usage: wtfix [--refresh] [--all|path]"
          return 2
        fi
        target="$1"
        shift
        ;;
    esac
  done

  source_dir="$(__cf_source_root)" || return

  if (( all )); then
    while IFS= read -r worktree_path; do
      if [[ ! -d "$worktree_path" ]]; then
        __cf_err "warning: worktree ausente; pulando $worktree_path"
        continue
      fi
      __cf_note "bootstrapping $worktree_path"
      __cf_bootstrap_local_files "$source_dir" "$worktree_path" "$refresh" || status_code=1
    done < <(__cf_each_worktree)
    return "$status_code"
  fi

  [[ -n "$target" ]] || target="$source_dir"
  __cf_bootstrap_local_files "$source_dir" "$target" "$refresh"
}

wtdoctor() {
  local all=0
  local target=""
  local source_dir worktree_path
  local status_code=0

  while (( $# )); do
    case "$1" in
      --all)
        all=1
        shift
        ;;
      -h|--help)
        wthelp
        return 0
        ;;
      *)
        target="$1"
        shift
        ;;
    esac
  done

  source_dir="$(__cf_source_root)" || return

  if (( all )); then
    while IFS= read -r worktree_path; do
      if [[ ! -d "$worktree_path" ]]; then
        __cf_err "warning: worktree ausente; pulando $worktree_path"
        continue
      fi
      wtdoctor "$worktree_path" || status_code=1
    done < <(__cf_each_worktree)
    return "$status_code"
  fi

  [[ -n "$target" ]] || target="$source_dir"
  target="$(__cf_abs_dir "$target")" || return

  print -r -- "doctor: $target"

  if [[ -L "$target/.codex" || -h "$target/.codex" ]]; then
    __cf_err "  FAIL .codex is a symlink"
    status_code=1
  elif [[ -d "$target/.codex" ]]; then
    print -r -- "  OK   .codex directory"
  else
    __cf_err "  WARN .codex missing"
  fi

  if [[ -L "$target/AGENTS.md" || -h "$target/AGENTS.md" ]]; then
    __cf_err "  FAIL AGENTS.md is a symlink"
    status_code=1
  elif [[ -f "$target/AGENTS.md" ]]; then
    print -r -- "  OK   AGENTS.md file"
  else
    __cf_err "  WARN AGENTS.md missing"
  fi

  if command git -C "$target" check-ignore -q .codex 2>/dev/null && command git -C "$target" check-ignore -q AGENTS.md 2>/dev/null; then
    print -r -- "  OK   context files ignored"
  else
    __cf_err "  WARN context files are not ignored"
  fi

  return "$status_code"
}

git() {
  local source_dir="$PWD"
  local worktree_dir
  local exit_code

  if [[ "$1" == "worktree" && "$2" == "add" ]]; then
    worktree_dir="$(__cf_parse_worktree_add_path "$@")"
    command git "$@"
    exit_code=$?

    if (( exit_code == 0 )) && [[ -n "$worktree_dir" ]]; then
      __cf_bootstrap_local_files "$source_dir" "$worktree_dir"
    fi

    return "$exit_code"
  fi

  command git "$@"
}

wt() {
  if [[ $# -ne 1 ]]; then
    __cf_err "usage: wt <branch-destino>"
    return 2
  fi

  local branch="$1"
  local repo_root repo_name parent_dir worktree_name worktree_dir

  repo_root="$(__cf_source_root)" || return
  repo_name="${repo_root:t}"
  parent_dir="${repo_root:h}"
  worktree_name="${repo_name}-${branch//\//-}"
  worktree_dir="${parent_dir}/${worktree_name}"

  if command git show-ref --verify --quiet "refs/heads/$branch"; then
    command git worktree add "$worktree_dir" "$branch" || return
  elif command git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
    command git worktree add --track -b "$branch" "$worktree_dir" "origin/$branch" || return
  else
    command git worktree add -b "$branch" "$worktree_dir" || return
  fi

  __cf_bootstrap_local_files "$repo_root" "$worktree_dir" || return
  cd "$worktree_dir" || return
}

alias pwt='wt'

wtrm() {
  if [[ $# -ne 1 ]]; then
    __cf_err "usage: wtrm <branch>"
    return 2
  fi

  local branch="$1"
  local repo_root repo_name parent_dir worktree_path candidate_path
  local status_output remove_status

  repo_root="$(__cf_source_root)" || return
  repo_name="${repo_root:t}"
  parent_dir="${repo_root:h}"

  if worktree_path="$(__cf_find_worktree_by_branch "$branch")"; then
    status_output="$(command git -C "$worktree_path" status --porcelain --untracked-files=all 2>/dev/null)" || {
      __cf_err "erro: nao foi possivel verificar o estado do worktree '$worktree_path'"
      return 1
    }

    if [[ -n "$status_output" ]]; then
      __cf_err "erro: o worktree '$worktree_path' possui alteracoes nao commitadas"
      __cf_err "$status_output"
      return 1
    fi

    __cf_note "removendo worktree: $worktree_path ($branch)"
    if command git worktree remove -f "$worktree_path"; then
      __cf_remove_leftover_dir "$repo_root" "$worktree_path"
      return $?
    fi

    remove_status=$?
    if [[ -e "$worktree_path" ]] && ! __cf_path_is_registered "$worktree_path"; then
      __cf_err "warning: git remove falhou apos desregistrar; limpando pasta restante"
      __cf_remove_leftover_dir "$repo_root" "$worktree_path"
      return $?
    fi

    return "$remove_status"
  fi

  candidate_path="$parent_dir/${repo_name}-${branch//\//-}"
  if [[ -e "$candidate_path" ]]; then
    __cf_err "warning: nenhum worktree registrado para '$branch', mas existe pasta restante"
    __cf_remove_leftover_dir "$repo_root" "$candidate_path"
    return $?
  fi

  __cf_err "erro: nenhum worktree encontrado para a branch '$branch'"
  return 1
}

alias pwtrm='wtrm'

wtclean() {
  local main_root worktree_path status_output remove_status repo_name parent_dir orphan_path
  local status_code=0
  local removed_count=0
  local skipped_count=0

  __cf_source_root >/dev/null || return
  main_root="$(__cf_main_root)" || {
    __cf_err "erro: nao foi possivel identificar o worktree principal"
    return 1
  }
  repo_name="${main_root:t}"
  parent_dir="${main_root:h}"

  while IFS= read -r worktree_path; do
    [[ -n "$worktree_path" ]] || continue
    [[ "$(__cf_abs_dir "$worktree_path" 2>/dev/null)" == "$main_root" ]] && continue

    status_output="$(command git -C "$worktree_path" status --porcelain --untracked-files=all 2>/dev/null)" || {
      __cf_err "aviso: nao foi possivel verificar o estado do worktree '$worktree_path'; pulando"
      skipped_count=$((skipped_count + 1))
      status_code=1
      continue
    }

    if [[ -n "$status_output" ]]; then
      __cf_note "pulando worktree com alteracoes: $worktree_path"
      skipped_count=$((skipped_count + 1))
      continue
    fi

    __cf_note "removendo worktree: $worktree_path"
    if command git worktree remove -f "$worktree_path"; then
      __cf_remove_leftover_dir "$main_root" "$worktree_path" || status_code=1
      removed_count=$((removed_count + 1))
    else
      remove_status=$?
      if [[ -e "$worktree_path" ]] && ! __cf_path_is_registered "$worktree_path"; then
        __cf_err "warning: git remove falhou apos desregistrar; limpando pasta restante"
        __cf_remove_leftover_dir "$main_root" "$worktree_path" || status_code=1
        removed_count=$((removed_count + 1))
        continue
      fi
      status_code="${remove_status:-1}"
    fi
  done < <(__cf_each_worktree)

  for orphan_path in "$parent_dir"/"$repo_name"-*(N); do
    [[ "$(__cf_abs_dir "$orphan_path" 2>/dev/null)" == "$main_root" ]] && continue
    __cf_path_is_registered "$orphan_path" && continue
    __cf_note "removendo sobra nao registrada: $orphan_path"
    __cf_remove_leftover_dir "$main_root" "$orphan_path" || status_code=1
    removed_count=$((removed_count + 1))
  done

  if (( removed_count == 0 && skipped_count == 0 )); then
    __cf_note "nenhum worktree adicional para remover"
  fi

  return "$status_code"
}

alias pwtclean='wtclean'

wthelp() {
  cat <<'EOF'
Comandos de worktree:
  wt <branch>            cria um worktree para a branch e entra nele
  wtfix [path]           copia arquivos locais nao versionados para o worktree
  wtfix --all            aplica bootstrap em todos os worktrees
  wtfix --refresh        recopia snapshots de contexto
  wtdoctor [path|--all]  valida arquivos locais e excludes
  wtclean                remove worktrees adicionais sem alteracoes
  wtrm <branch>          remove o worktree da branch informada
  wthelp                 mostra esta ajuda

Aliases de compatibilidade:
  pwt, pwtclean, pwtrm, pwthelp
EOF
}

alias pwthelp='wthelp'

__cf_codex_run() {
  local codex_home="$1"
  shift

  CODEX_HOME="$codex_home" command codex -a never -s danger-full-access "$@"
}

codex() {
  __cf_codex_run "$HOME/.codex" "$@"
}
