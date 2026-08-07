local M = {}

local PANEL_VAR = "nvim_hlp_panel"

local function panel_lines()
  return {
    "# NVIM HLP - comecando do zero",
    "",
    "Como abrir esta cola",
    "  Clique em HLP na barra de baixo.",
    "  Ou aperte Space e depois h.",
    "  Para fechar: q ou Esc.",
    "",
    "A coisa mais importante",
    "  Neovim tem MODOS.",
    "  Normal = voce manda o editor fazer algo.",
    "  Insert = voce digita texto.",
    "  Command = voce roda comandos com dois-pontos.",
    "",
    "Como saber onde voce esta",
    "  Se aparecer -- INSERT --, voce esta digitando.",
    "  Se aparecer : embaixo, voce esta num comando.",
    "  Se nao aparecer nada, geralmente esta no Normal.",
    "  Na duvida, aperte Esc.",
    "",
    "Como digitar texto",
    "  1. Aperte i.",
    "  2. Digite normal.",
    "  3. Aperte Esc quando terminar.",
    "",
    "Como rodar comando no Neovim",
    "  1. Aperte Esc.",
    "  2. Aperte :",
    "  3. Digite o comando.",
    "  4. Aperte Enter.",
    "",
    "Exemplos de comando",
    "  :w       salva o arquivo",
    "  :q       sai",
    "  :wq      salva e sai",
    "  :q!      sai sem salvar",
    "  :HLP     abre/fecha esta cola",
    "  :Tutor   abre o tutorial oficial",
    "",
    "Abrir o Neovim pelo terminal",
    "  nvim              abre vazio",
    "  nvim arquivo.txt  abre/cria arquivo.txt",
    "  nvim .            abre na pasta atual",
    "",
    "Abrir arquivo dentro do Neovim",
    "  :e arquivo.txt    abre arquivo.txt",
    "  :e .              abre a pasta atual",
    "  Space Space       busca arquivos do projeto",
    "  Space ff          busca arquivos do projeto",
    "  Space fr          arquivos recentes",
    "",
    "Navegar no texto",
    "  setas   funcionam normalmente",
    "  h       esquerda",
    "  j       baixo",
    "  k       cima",
    "  l       direita",
    "  w       proxima palavra",
    "  b       palavra anterior",
    "  0       inicio da linha",
    "  $       fim da linha",
    "  gg      inicio do arquivo",
    "  G       fim do arquivo",
    "",
    "Subir e descer mais rapido",
    "  Ctrl-d  desce meia pagina",
    "  Ctrl-u  sobe meia pagina",
    "  }       proximo bloco/paragrafo",
    "  {       bloco/paragrafo anterior",
    "",
    "Linhas novas",
    "  o       abre linha abaixo e ja digita",
    "  O       abre linha acima e ja digita",
    "  Esc     para de digitar",
    "",
    "Apagar, copiar e colar",
    "  x       apaga um caractere",
    "  dd      apaga/corta a linha inteira",
    "  yy      copia a linha inteira",
    "  p       cola depois do cursor",
    "  u       desfaz",
    "  Ctrl-r  refaz",
    "",
    "Editar uma palavra",
    "  ciw     troca a palavra do cursor",
    "  diw     apaga a palavra do cursor",
    "",
    "Buscar texto",
    "  /texto  busca texto",
    "  n       proximo resultado",
    "  N       resultado anterior",
    "  Esc     sai da busca",
    "",
    "Selecionar texto",
    "  v       selecao por caractere",
    "  V       selecao por linha",
    "  y       copia selecao",
    "  d       corta selecao",
    "  Esc     cancela selecao",
    "",
    "Janelas dentro do Neovim",
    "  :split   divide em cima/baixo",
    "  :vsplit  divide esquerda/direita",
    "  Ctrl-h   vai para janela da esquerda",
    "  Ctrl-l   vai para janela da direita",
    "  Ctrl-j   vai para janela de baixo",
    "  Ctrl-k   vai para janela de cima",
    "",
    "Buffers, que sao arquivos abertos",
    "  Shift-h   arquivo anterior",
    "  Shift-l   proximo arquivo",
    "  Space bd  fecha arquivo atual",
    "  Space bb  volta para o ultimo arquivo",
    "",
    "Atalhos da sua config",
    "  Space e outra tecla = atalho leader.",
    "  Space h   esta cola",
    "  Space l   tela de plugins Lazy",
    "  Ctrl-s    salva",
    "  K         ajuda do codigo sob o cursor",
    "  gd        ir para definicao",
    "  gr        referencias",
    "  Space ca  acao de codigo",
    "  Space cf  formatar",
    "",
    "Treino rapido",
    "  1. Abra: nvim teste.txt",
    "  2. Aperte i e escreva uma frase.",
    "  3. Aperte Esc.",
    "  4. Use h j k l para andar.",
    "  5. Use w e b para pular palavras.",
    "  6. Use x para apagar uma letra.",
    "  7. Use u para desfazer.",
    "  8. Use :w para salvar.",
    "  9. Use :q para sair.",
    "",
    "Regra de sobrevivencia",
    "  Quer digitar? i",
    "  Quer parar? Esc",
    "  Quer comando? :",
    "  Quer salvar? :w",
    "  Quer sair? :q",
    "  Fez besteira? u",
  }
end

local function is_panel(buf)
  return vim.api.nvim_buf_is_valid(buf) and vim.b[buf][PANEL_VAR] == true
end

local function panel_width()
  return math.max(44, math.min(60, math.floor(vim.o.columns * 0.38)))
end

function M.close()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local ok, buf = pcall(vim.api.nvim_win_get_buf, win)
    if ok and is_panel(buf) then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end
end

function M.open()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local ok, buf = pcall(vim.api.nvim_win_get_buf, win)
    if ok and is_panel(buf) then
      vim.api.nvim_set_current_win(win)
      return
    end
  end

  local origin = vim.api.nvim_get_current_win()
  vim.cmd("botright vertical new")

  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_get_current_buf()

  vim.b[buf][PANEL_VAR] = true
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buflisted = false
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true

  vim.api.nvim_buf_set_name(buf, "nvim-hlp")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, panel_lines())

  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true

  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].foldcolumn = "0"
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.wo[win].breakindent = true
  vim.wo[win].cursorline = true
  vim.wo[win].winfixwidth = true

  pcall(vim.api.nvim_win_set_width, win, panel_width())

  vim.keymap.set("n", "q", M.close, { buffer = buf, silent = true, nowait = true, desc = "Close HLP" })
  vim.keymap.set("n", "<Esc>", M.close, { buffer = buf, silent = true, nowait = true, desc = "Close HLP" })

  if vim.api.nvim_win_is_valid(origin) then
    vim.api.nvim_set_current_win(origin)
  end
end

function M.toggle()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local ok, buf = pcall(vim.api.nvim_win_get_buf, win)
    if ok and is_panel(buf) then
      M.close()
      return
    end
  end

  M.open()
end

function M.setup()
  vim.api.nvim_create_user_command("HLP", M.toggle, {
    desc = "Toggle the Neovim HLP side panel",
    force = true,
  })
end

return M
