-- Set up nvim-cmp.
local cmp = require'cmp'
local luasnip = require("luasnip")

require("luasnip.loaders.from_vscode").lazy_load()

cmp.setup({
  preselect = cmp.PreselectMode.None,
  snippet = {
    -- REQUIRED - you must specify a snippet engine
    expand = function(args)
      --vim.fn["vsnip#anonymous"](args.body) -- For `vsnip` users.
      require('luasnip').lsp_expand(args.body) -- For `luasnip` users.
      -- require('snippy').expand_snippet(args.body) -- For `snippy` users.
      -- vim.fn["UltiSnips#Anon"](args.body) -- For `ultisnips` users.
      -- vim.snippet.expand(args.body) -- For native neovim snippets (Neovim v0.10+)

      -- For `mini.snippets` users:
      -- local insert = MiniSnippets.config.expand.insert or MiniSnippets.default_insert
      -- insert({ body = args.body }) -- Insert at cursor
      -- cmp.resubscribe({ "TextChangedI", "TextChangedP" })
      -- require("cmp.config").set_onetime({ sources = {} })
    end,
  },
  window = {
    -- completion = cmp.config.window.bordered(),
    -- documentation = cmp.config.window.bordered(),
  },
  mapping = cmp.mapping.preset.insert({
    ['<C-b>'] = cmp.mapping.scroll_docs(-4),
    ['<C-f>'] = cmp.mapping.scroll_docs(4),
    ['<C-^>c<C-^><Space>'] = cmp.mapping.complete(),
    ['<C-e>'] = cmp.mapping.abort(),
    --['<Tab>'] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
    --['<Tab>'] = function(fallback)
    --  if cmp.visible() then
    --    cmp.select_next_item()
    --  else
    --    fallback()
    --  end
    --end
    ['<CR>'] = cmp.mapping(function(fallback)
         if cmp.visible() then
             local selected = cmp.get_selected_entry()
             if selected ~= nil and selected.source.name == 'luasnip' and luasnip.expandable() then
                 luasnip.expand()
             else
                 cmp.confirm({
                     select = true,
                 })
             end
         else
             fallback()
         end
     end),

    ["<Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      elseif luasnip.locally_jumpable(1) then
        luasnip.jump(1)
      else
        fallback()
      end
    end, { "i", "s" }),

    --  ["<S-Tab>"] = cmp.mapping(function(fallback)
    --    if cmp.visible() then
    --      cmp.select_prev_item()
    --    elseif luasnip.locally_jumpable(-1) then
    --      luasnip.jump(-1)
    --    else
    --      fallback()
    --    end
    --  end, { "i", "s" }),
  }),
  sources = cmp.config.sources({
    { name = 'nvim_lsp' },
    { name = 'luasnip' }, -- For luasnip users.
    --{ name = 'vsnip' }, -- For vsnip users.
    -- { name = 'ultisnips' }, -- For ultisnips users.
    -- { name = 'snippy' }, -- For snippy users.
  }, {
    { name = 'buffer' },
  })
})

-- To use git you need to install the plugin petertriho/cmp-git and uncomment lines below
-- Set configuration for specific filetype.
--[[ cmp.setup.filetype('gitcommit', {
  sources = cmp.config.sources({
    { name = 'git' },
  }, {
    { name = 'buffer' },
  })
)
equire("cmp_git").setup() ]]--

-- Use buffer source for `/` and `?` (if you enabled `native_menu`, this won't work anymore).
cmp.setup.cmdline({ '/', '?' }, {
  mapping = cmp.mapping.preset.cmdline(),
  sources = {
    { name = 'buffer' }
  }
})

-- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
cmp.setup.cmdline(':', {
  mapping = cmp.mapping.preset.cmdline(),
  sources = cmp.config.sources({
    { name = 'path' }
  }, {
    { name = 'cmdline' }
  }),
  matching = { disallow_symbol_nonprefix_matching = false }
})

local home = os.getenv("HOME")
local arcadia_root = home .. "/go/src/a.yandex-team.ru"
local cloudia_root = home .. "/go/src/cloudia"

local capabilities = require('cmp_nvim_lsp').default_capabilities()
local default_diagnostic_handler = vim.lsp.handlers["textDocument/publishDiagnostics"]

local debug_gopls = false
local gopls_args = debug_gopls and {"-logfile", "/tmp/gopls.log", "-rpc.trace"} or {}
local arcadia_gopls_cmd = { "bash", "-c", "cd " .. arcadia_root .. " && exec " .. home .. "/.ya/tools/v4/gopls-linux/gopls" .. table.concat(gopls_args, ' ')}
local has_arcadia = vim.fn.isdirectory(arcadia_root) == 1 and true or false
local gopls_cmd = has_arcadia and arcadia_gopls_cmd or { "gopls" }
local gopls_root = has_arcadia and arcadia_root or nil

local gopls_options = {
  expandWorkspaceToModule = true,
  ["local"]               = "a.yandex-team.ru", -- Put imports beginning with 'a.yandex-team.ru' after all other imports, e.g. from vendor/
  hints = {
      assignVariableTypes     =  true,
      compositeLiteralFields  =  true,
      compositeLiteralTypes   =  true,
      constantValues          =  true,
      functionTypeParameters  =  true,
      parameterNames          =  true,
      rangeVariableTypes      =  true,
  },
}
if has_arcadia then
    gopls_options['arcadiaIndexDirs'] = {
      arcadia_root .. "/cloud/dataplatform",
      arcadia_root .. "/transfer_manager",
      cloudia_root .. "/cloud/cloud-go/devtools/terraform-provider-ycp",
  }
end

Goplscfg = {
  name = "gopls",
  cmd                 = gopls_cmd,
  filetypes           = { "go", "gomod", "gowork", "gotmpl" },
  root_dir            = gopls_root,
  single_file_support = true,
  init_options = gopls_options,
  handlers = {
      ["$/progress"] = function(_, result, _)
          vim.print(result.value.message)
          return nil, nil
      end,
      ["textDocument/publishDiagnostics"] = function(err, result, ctx)
          local handler_res, handler_err = default_diagnostic_handler(err, result, ctx)
          if result["uri"] == 'file://' .. vim.fn.expand('%:p') then
              vim.diagnostic.setloclist({open = false})
          end
          return handler_res, handler_err
      end,
  },
  settings = gopls_options,
  capabilities = capabilities,
}

Lualscfg = {
  capabilities = capabilities,
  cmd = { home .. "/luals/bin/lua-language-server" },
  filetypes           = { "lua" },
  on_init = function(client)
    if client.workspace_folders then
      local path = client.workspace_folders[1].name
      if path ~= vim.fn.stdpath('config') and (vim.fn.filereadable(path..'/.luarc.json') or vim.fn.filereadable(path..'/.luarc.jsonc')) then
        return
      end
    end

    client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
      runtime = {
        -- Tell the language server which version of Lua you're using
        -- (most likely LuaJIT in the case of Neovim)
        version = 'LuaJIT'
      },
      -- Make the server aware of Neovim runtime files
      workspace = {
        checkThirdParty = false,
        library = {
          vim.env.VIMRUNTIME
          -- Depending on the usage, you might want to add additional paths here.
          -- "${3rd}/luv/library"
          -- "${3rd}/busted/library",
        }
        -- or pull in all of 'runtimepath'. NOTE: this is a lot slower and will cause issues when working on your own configuration (see https://github.com/neovim/nvim-lspconfig/issues/3189)
        -- library = vim.api.nvim_get_runtime_file("", true)
      }
    })
  end,
  settings = {
    Lua = {
        hint = {enable = true}
    }
  }
}

Pylspcfg = {
  cmd = { 'pylsp' },
  filetypes = { 'python' },
  root_markers = {
    'pyproject.toml',
    'setup.py',
    'setup.cfg',
    'requirements.txt',
    'Pipfile',
    '.git',
  },
  handlers = {
      ["$/progress"] = function(_, result, _)
          vim.print(result.value.message)
          return nil, nil
      end,
      ["textDocument/publishDiagnostics"] = function(err, result, ctx)
          local handler_res, handler_err = default_diagnostic_handler(err, result, ctx)
          if result["uri"] == 'file://' .. vim.fn.expand('%:p') then
              vim.diagnostic.setloclist({open = false})
          end
          return handler_res, handler_err
      end,
  },
}

Clangdcfg = {
  capabilities = {
    offsetEncoding = { "utf-8", "utf-16" },
    textDocument = {
  	  completion = {
  	    editsNearCursor = true
  	  }
    }
  },
  cmd = {"clangd-12"},
  filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
  root_markers = { ".clangd", ".clang-tidy", ".clang-format", "compile_commands.json", "compile_flags.txt", "configure.ac", ".git" },
}

vim.lsp.config['gopls'] = Goplscfg
vim.lsp.config['lua_ls'] = Lualscfg
vim.lsp.config['pylsp'] = Pylspcfg
vim.lsp.config['clangd'] = Clangdcfg

vim.lsp.enable('gopls')
vim.lsp.enable('lua_ls')
vim.lsp.enable('pylsp')
vim.lsp.enable("clangd")

vim.diagnostic.config({
  float = true,
  jump = {
    float = false,
    wrap = true
  },
  severity_sort = false,
  signs = {
    priority = 100,
  },
  underline = true,
  update_in_insert = false,
  virtual_lines = false,
  virtual_text = false
})

vim.lsp.start(Goplscfg)
vim.diagnostic.config({update_in_insert = false})
