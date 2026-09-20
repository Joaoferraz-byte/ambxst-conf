# Auditoria upstream do Ambxst

A implementação usa o upstream `https://github.com/Axenide/Ambxst` na revisão `7f0ac49b82497c6d273f7cd7e49d302904f440ed`, correspondente à release 1.3.7 observada em 20/09/2026. O upstream expõe `nixosModules.default`, `packages.default`, `packages.Ambxst` e `packages.backend` em `https://raw.githubusercontent.com/Axenide/Ambxst/main/flake.nix` e `https://raw.githubusercontent.com/Axenide/Ambxst/main/nix/modules/default.nix`.

O README upstream documenta suporte operacional a Niri e NixOS: `https://github.com/Axenide/Ambxst/blob/main/README.md`. O arquivo `~/.local/share/ambxst/niri.kdl` é gerado pelo `axctl` e não deve ser editado diretamente; overrides pertencem a `~/.config/niri/config.kdl`. A integração declarativa Home Manager upstream ainda não é um módulo merged; o README recomenda expor os arquivos gerados com `xdg.configFile` ou activation. O PR relacionado é `https://github.com/Axenide/Ambxst/pull/199`.

A paleta reativa do Ambxst é escrita em `~/.cache/ambxst/colors.json`, conforme `https://raw.githubusercontent.com/Axenide/Ambxst/main/modules/theme/Colors.qml`. `ambxst-conf` lê esse arquivo e converte apenas cores semânticas para `palette.dark.json`, usado pelos adapters do `shell-conf`. A ponte é atômica e não altera o estado do Ambxst.

A análise concluiu que Ambxst e Noctalia são shells completos e não devem ser executados simultaneamente: haveria duplicação de barra, launcher, wallpaper, rede, gravação, atalhos e processos. O `shell-conf` foi separado em `homeModules.support-core`, sem dependência de Noctalia, e `homeModules.support`, que preserva o adapter Noctalia.

O upstream também documenta o uso de `gpu-screen-recorder` e a exigência potencial do grupo `input` para monitoramento de teclas. A configuração do host continua sendo responsabilidade do `nix-conf`; `ambxst-conf` não inicia serviços de rede, altera o `config.kdl` do Niri nem cria um recorder concorrente.
