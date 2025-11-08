local api_keys = dofile("/home/ovandriyanov/github/ovandriyanov/util/dotfiles/nvim/api_keys.lua")

local code_companion = require("codecompanion")
code_companion.setup({
    default = 'yandex-anthropic',

    strategies = {
        chat = {
            adapter = "yandex-anthropic",
            model = "claude-sonnet-4-20250514",
        },
        inline = {
            adapter = "yandex-anthropic",
            model = "claude-sonnet-4-20250514",
        },
        agent = {
            adapter = "yandex-anthropic",
            model = "claude-sonnet-4-20250514",
        },
    },
    display = {
        diff = {
            provider = "mini_diff",
        },
    },
    prompt_library = {
        ["buffer"] = {
            strategy = "chat",
            description = "Send buffer to AI with Telescope picker",
            opts = {
                provider = "telescope", -- Enable Telescope provider
            },
        },
    },
    adapters = {
        http = {
            ['yandex-anthropic'] = function()
                return require('codecompanion.adapters').extend('anthropic', {
                    name = 'yandex-claude',
                    formatted_name = 'Claude (Yandex)',
                    url = 'https://api.eliza.yandex.net/raw/anthropic/v1/messages',
                    env = {
                        api_key = api_keys.eliza_api_key,
                    },
                })
            end,

            ['yandex-openrouter'] = function()
                return require('codecompanion.adapters').extend('openai_compatible', {
                    name = 'yandex-openrouter',
                    formatted_name = 'OpenRouter (Yandex)',
                    env = {
                        api_key = api_keys.eliza_api_key,
                        url = 'https://api.eliza.yandex.net/raw/openrouter',
                    },
                    schema = {
                        model = {
                            default = 'anthropic/claude-3.7-sonnet',
                        },
                    },
                })
            end,

            ['yandex-deepseek-r1'] = function()
                return require('codecompanion.adapters').extend('openai_compatible', {
                    name = 'yandex-deepseek-r1',
                    formatted_name = 'DeepSeek R1 (Yandex)',
                    opts = {
                        stream = true,
                        tools = false,
                    },
                    env = {
                        url = 'http://zeliboba.yandex-team.ru/balance/deepseek_r1',
                        api_key = 'AI_API_KEY_ZELIB',
                        chat_url = '/v1/chat/completions',
                        models_endpoint = '/v1/models',
                    },
                    schema = {
                        temperature = {
                            default = 0.8,
                        },
                    },
                })
            end,

            ['yandex-deepseek-v3'] = function()
                return require('codecompanion.adapters').extend('openai', {
                    name = 'yandex-deepseek-v3',
                    formatted_name = 'DeepSeek V3 (Yandex)',
                    opts = {
                        stream = true,
                        tools = false,
                    },
                    url = 'http://deepseek-openai.yandex-team.ru/deepseek-v3/v1/chat/completions',
                    env = {
                        api_key = api_keys.eliza_api_key,
                    },
                    schema = {
                        model = {
                            default = 'DeepSeek-V3',
                            choices = { 'DeepSeek-V3' },
                        },
                    },
                })
            end,
        },
    },
})
