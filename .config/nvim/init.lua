--[[Neovim]]

-- Utils ====================================================================
_G.Config = {}

local gr = vim.api.nvim_create_augroup('custom-config', {})

Config.new_autocmd = function(event, pattern, callback, desc)
  local opts = { group = gr, pattern = pattern, callback = callback, desc = desc }
  vim.api.nvim_create_autocmd(event, opts)
end

Config.on_packchanged = function(plugin_name, kinds, callback, desc)
  local f = function(ev)
    local name, kind = ev.data.spec.name, ev.data.kind
    if not (name == plugin_name and vim.tbl_contains(kinds, kind)) then
      return
    end
    if not ev.data.active then
      vim.cmd.packadd(plugin_name)
    end
    callback(ev.data)
  end
  Config.new_autocmd('PackChanged', '*', f, desc)
end

vim.pack.add({ 'https://github.com/nvim-mini/mini.nvim' })

local misc = require('mini.misc')

Config.now = function(f)
  misc.safely('now', f)
end

Config.later = function(f)
  misc.safely('later', f)
end

Config.now_if_args = vim.fn.argc(-1) > 0 and Config.now or Config.later
Config.on_event = function(ev, f)
  misc.safely('event:' .. ev, f)
end

Config.on_filetype = function(ft, f)
  misc.safely('filetype:' .. ft, f)
end

local now, now_if_args, later = Config.now, Config.now_if_args, Config.later

-- Theme =========================================================================
now(function()
  vim.cmd('colorscheme miniautumn')
end)

-- Basic =========================================================================
now(function()
  require('mini.basics').setup({
    mappings = {
      windows = true,
      move_with_alt = true,
    },
  })
end)

-- Edit =========================================================================

Config.on_filetype('FileType', function()
  local lang = vim.treesitter.language.get_lang(vim.bo[ev.buf].filetype)
  if lang then
    pcall(vim.treesitter.language.add, lang)
    pcall(vim.treesitter.start, ev.buf, lang)
  end
end)

now(function()
  require('mini.completion').setup({
    delay = { completion = 10 ^ 7, info = 10 ^ 7, signature = 10 ^ 7 },
  })
  require('mini.pairs').setup()
  require('mini.pick').setup()
end)

later(function()
  require('mini.files').setup()
end)

-- UI =========================================================================
now(function()
  require('mini.statusline').setup()
  require('mini.notify').setup()
  require('mini.icons').setup()
  require('mini.statusline').setup()
end)

-- Language servers ===========================================================

local servers = { c = 'clangd', cpp = 'clangd', lua = 'lua_ls', rust = 'rust_analyzer' }

now_if_args(function()
  vim.pack.add({ 'https://github.com/neovim/nvim-lspconfig' })
  vim.lsp.config['lua_ls'] = {
    cmd = { 'lua-language-server' },
    filetypes = { 'lua' },
    root_markers = { { '.luarc.json', '.luarc.jsonc' }, '.git' },
    settings = {
      Lua = {
        runtime = {
          version = 'LuaJIT',
        },
      },
    },
  }
end)

Config.new_autocmd('FileType', '*', function(ev)
  local server = servers[vim.bo[ev.buf].filetype]
  if server then
    vim.lsp.enable(server)
  end
end, 'Enable LSP')

local diagnostic_goto = function(next, severity)
  return function()
    vim.diagnostic.jump({
      -- Multiply by `count1` so `3]e` skips three errors at once.
      count = (next and 1 or -1) * vim.v.count1,
      severity = severity and vim.diagnostic.severity[severity] or nil,
      float = true, -- show the message in a float; `focus = false` is implied
    })
  end
end

-- Formatting =================================================================
later(function()
  vim.pack.add({ 'https://github.com/stevearc/conform.nvim' })

  require('conform').setup({
    default_format_opts = {
      lsp_format = 'fallback',
    },
    formatters_by_ft = { lua = { 'stylua' }, c = { 'clang-format' }, cpp = { 'clang-format' } },
  })
end)

-- Keymaps =========================================================================
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

local nmap = function(lhs, rhs, desc)
  -- See `:h vim.keymap.set()`
  vim.keymap.set('n', lhs, rhs, { desc = desc })
end

local nmap_leader = function(suffix, rhs, desc)
  vim.keymap.set('n', '<Leader>' .. suffix, rhs, { desc = desc })
end

local xmap_leader = function(suffix, rhs, desc)
  vim.keymap.set('x', '<Leader>' .. suffix, rhs, { desc = desc })
end

nmap('<C-s>', '<Esc>', 'Quit Insert')

nmap('[p', '<Cmd>exe "iput! " . v:register<CR>', 'Paste Above')
nmap(']p', '<Cmd>exe "iput "  . v:register<CR>', 'Paste Below')

nmap_leader('ff', '<Cmd>Pick files<CR>', 'Find Files')
nmap_leader('/', '<Cmd>Pick grep_live<CR>', 'Find Words')
nmap('<Leader><Leader>', '<Cmd>Pick buffers<CR>', 'Find Buffers')
nmap('fm', function()
  require('conform').format({ async = true })
end, 'Format Buffer')

nmap('e', '<Cmd>lua MiniFiles.open()<CR>', 'File Tree')

nmap('[e', diagnostic_goto(false, 'ERROR'), 'Prev Error')
nmap(']e', diagnostic_goto(true, 'ERROR'), 'Next Error')
nmap('[w', diagnostic_goto(false, 'WARN'), 'Prev Warning')
nmap(']w', diagnostic_goto(true, 'WARN'), 'Next Warning')
