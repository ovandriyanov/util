-- Set up nvim-cmp.
local cmp = require 'cmp'
local luasnip = require("luasnip")

local buffer_source = {
    name = 'buffer',
    option = {
        get_bufnrs = function()
            local bufnr = vim.api.nvim_get_current_buf()
            if vim.bo[bufnr].buftype == 'terminal' then
                return {}
            end
            return { bufnr }
        end,
    },
}

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
        buffer_source,
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
equire("cmp_git").setup() ]] --

-- Use buffer source for `/` and `?` (if you enabled `native_menu`, this won't work anymore).
cmp.setup.cmdline({ '/', '?' }, {
    mapping = cmp.mapping.preset.cmdline(),
    sources = {
        buffer_source,
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
local arcadia_root = os.getenv("ARCADIA_ROOT")
local cloudia_base = os.getenv("CLOUDIA_ROOT")
local cloudia_root = cloudia_base and cloudia_base .. "/cloud/cloud-go" or nil

local capabilities = require('cmp_nvim_lsp').default_capabilities()
local default_diagnostic_handler = vim.lsp.handlers["textDocument/publishDiagnostics"]
local default_semantic_tokens_handler = vim.lsp.handlers["textDocument/semanticTokens/full"]

local debug_gopls = true
local has_arcadia = arcadia_root and vim.fn.isdirectory(arcadia_root) == 1 and true or false
local has_cloudia = cloudia_root and vim.fn.isdirectory(cloudia_root) == 1 and true or false
local gopls_args = debug_gopls and { "-logfile", "/tmp/gopls-nvim-" .. vim.fn.getpid() .. ".log", "-rpc.trace" } or {}
local gopls_cmd = { "gopls" }
if has_arcadia then
    local command = {
        "cd",
        vim.fn.shellescape(arcadia_root),
        "&&",
        "exec",
        vim.fn.shellescape(home .. "/.ya/tools/v4/gopls-linux/gopls"),
    }
    for _, argument in ipairs(gopls_args) do
        table.insert(command, vim.fn.shellescape(argument))
    end
    gopls_cmd = { "bash", "-c", table.concat(command, " ") }
end
local gopls_root = has_arcadia and arcadia_root or home .. '/github/ovandriyanov/test'
--local gopls_root = has_cloudia and cloudia_root or home .. '/github/ovandriyanov/test'

local gopls_options = {
    expandWorkspaceToModule = true,
    matcher                 = "Fuzzy",
    ["local"]               = "a.yandex-team.ru", -- Put imports beginning with 'a.yandex-team.ru' after all other imports, e.g. from vendor/
    hints                   = {
        assignVariableTypes    = true,
        compositeLiteralFields = true,
        compositeLiteralTypes  = true,
        constantValues         = true,
        functionTypeParameters = true,
        parameterNames         = true,
        rangeVariableTypes     = true,
    },
    semanticTokens = false,
    --["build.directoryFilters"] = {
    --    "-/",
    --    "+cloud",
    --},
}

if has_arcadia then
    gopls_options['arcadiaIndexDirs'] = {
        arcadia_root .. "/cloud/dataplatform",
        arcadia_root .. "/transfer_manager",
    }
end

--if has_cloudia then
--    gopls_options['arcadiaIndexDirs'] = {
--        cloudia_root .. "/cloud/cloud-go/cli/pkg/public",
--        cloudia_root .. "/cli",
--        cloudia_root .. "/devtools/terraform-provider-ycp",
--    }
--end

Goplscfg = {
    name                = "gopls",
    cmd                 = gopls_cmd,
    filetypes           = { "go", "gomod", "gowork", "gotmpl" },
    root_dir            = gopls_root,
    single_file_support = true,
    init_options        = gopls_options,
    on_attach = function(client, bufnr)
        -- A workaround for a bug in https://github.com/esmuellert/codediff.nvim
        -- Whenever unified diff view is toggled, gopls hangs due to empty file URI in the "textDocument/semanticTokens/full" request
        client.server_capabilities.semanticTokensProvider = nil
    end,
    handlers            = {
        ["$/progress"] = function(_, result, _)
            vim.print(result.value.message)
            return nil, nil
        end,
        ["textDocument/publishDiagnostics"] = function(err, result, ctx)
            local handler_res, handler_err = default_diagnostic_handler(err, result, ctx)
            if result["uri"] == 'file://' .. vim.fn.expand('%:p') then
                vim.diagnostic.setloclist({ open = false })
            end
            return handler_res, handler_err
        end,
        ["textDocument/semanticTokens/full"] = function(err, result, ctx)
            vim.cmd.echomsg('HELLO YOBA')
            print(vim.inspect(err))
            print(vim.inspect(result))
            print(vim.inspect(ctx))
            local handler_res, handler_err = default_semantic_tokens_handler(err, result, ctx)
            return handler_res, handler_err
        end,
    },
    settings            = gopls_options,
    capabilities        = capabilities,
}

Lualscfg = {
    capabilities = capabilities,
    cmd          = { home .. "/luals/bin/lua-language-server" },
    filetypes    = { "lua" },
    on_init      = function(client)
        if client.workspace_folders then
            local path = client.workspace_folders[1].name
            if path ~= vim.fn.stdpath('config') and (vim.fn.filereadable(path .. '/.luarc.json') or vim.fn.filereadable(path .. '/.luarc.jsonc')) then
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
    settings     = {
        Lua = {
            hint = { enable = true }
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
                vim.diagnostic.setloclist({ open = false })
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
    cmd = { "clangd-12" },
    filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
    root_markers = { ".clangd", ".clang-tidy", ".clang-format", "compile_commands.json", "compile_flags.txt", "configure.ac", ".git" },
    settings = {
        Index = {
            Background = 'Skip',
        },
    },
}

JSCfg = {
    cmd = { "typescript-language-server", "--stdio" },
    capabilities = capabilities,
    root_markers = { "tsconfig.json" },
    filetypes = { "javascript", "typescript" },
    settings = {}
}
vim.lsp.config['js'] = JSCfg
vim.lsp.enable('js')

TerraformCfg = {
    cmd = {
        "bash",
        "-c",
        "cd " .. vim.fn.shellescape(arcadia_root .. "/cloud/dataplatform/datacatalog/infra/terraform")
            .. " && exec terraform-ls serve --log-file "
            .. vim.fn.shellescape(home .. "/terraform/terraform-ls-" .. vim.fn.getpid() .. ".log"),
    },
    root_markers = {".terraform"},
    capabilities = capabilities,
    filetypes = { "tf", "terraform" },
    settings = {
        logFilePath = home .. "/terraform/terraform-ls.log",
    },
}

YamlCfg = {
    cmd = { "yaml-language-server", "--stdio" },
    capabilities = capabilities,
    filetypes = { "yaml" },
    settings = {
        yaml = {
            -- Disable built-in schemaStore if using SchemaStore.nvim plugin
            schemaStore = {
                enable = false,
                -- url = "...", -- Or specify a custom URL if not using the plugin
            },
            keyOrdering = false, -- Disable alphabetical key ordering
            format = {
                enable = true,
            },
            validate = false,
            schemas = {
                ["file://" .. arcadia_root .. "/" .. "devtools/schemas/public/a-yaml/ci/src/a-yaml.yaml"] = "a.yaml",
                ["file://" .. arcadia_root .. "/" .. "devtools/schemas/public/a-yaml/ci/src/dot-a-yaml.yaml"] = "*.a.yaml",
            },
            customTags = {
                "!override",
                "!evaluate",
                "!unset",
                "!merge-policy:override",
            },
        }
    },
}

vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    -- Only apply to floating windows (hover)
    if vim.fn.win_gettype() == "popup" or vim.api.nvim_win_get_config(0).relative ~= "" then
      vim.wo.conceallevel = 0 -- Shows raw markdown characters
      -- Optional: Clear highlights if they are distracting
      -- vim.cmd("syntax clear") 
    end
  end,
})

vim.lsp.config['gopls'] = Goplscfg
vim.lsp.config['lua_ls'] = Lualscfg
vim.lsp.config['pylsp'] = Pylspcfg
vim.lsp.config['clangd'] = Clangdcfg
vim.lsp.config['js'] = JSCfg
vim.lsp.config['terraform'] = TerraformCfg
vim.lsp.config['yaml'] = YamlCfg

vim.lsp.enable('gopls')
vim.lsp.enable('lua_ls')
vim.lsp.enable('pylsp')
vim.lsp.enable('clangd')
vim.lsp.enable('js')
vim.lsp.enable('terraform')
vim.lsp.enable('yaml')

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
vim.diagnostic.config({ update_in_insert = false })
