# ambxst-conf

Integração declarativa do Ambxst 1.3.7 com Niri, NixOS, Home Manager e os adapters de aplicações do Livara.

## Ownership

| Responsabilidade | Owner |
| --- | --- |
| Ambxst, Quickshell, `axctl`, barra, launcher, overview, wallpaper e rede visual | `ambxst-conf` e upstream Ambxst |
| Adapters GTK, Qt, Kitty, WezTerm, Xournal++, IntelliJ, Fastfetch e aplicações | `shell-conf` |
| Niri, hardware, NetworkManager, PipeWire, serviços e capacidades do host | `nix-conf` |
| Configuração de Niri e include do shell | `nix-conf` |

Ambxst e Noctalia são shells completos. Apenas um deles deve ser ativado na sessão. Este módulo não inicia um segundo shell, não altera `config.kdl`, não inicia NetworkManager, não cria recorder concorrente e não escreve os diretórios de estado do Noctalia.

## Pinning

O upstream é consumido no commit `7f0ac49b82497c6d273f7cd7e49d302904f440ed`, correspondente à release 1.3.7. O repositório usa o flake upstream e não mantém um fork do shell. Alterações de comportamento devem ser implementadas como configuração declarativa ou mod upstream revisado, não por edição do checkout em runtime.

## Niri

O Ambxst gera `~/.local/share/ambxst/niri.kdl` através do `axctl`. Esse arquivo não deve ser editado diretamente. O `nix-conf` deve manter o include no `~/.config/niri/config.kdl`:

```kdl
include optional=true "~/.local/share/ambxst/niri.kdl"
```

Overrides locais continuam no `config.kdl`, depois do include. Não use `ambxst install niri` em uma configuração administrada pelo Nix, porque o instalador é imperativo.

## Tema

O módulo instala uma ponte de leitura que observa `~/.cache/ambxst/colors.json` e produz `palette.dark.json` e `palette.json` em `$XDG_STATE_HOME/livara/theme`. A ponte preserva os campos Material do Ambxst e acrescenta aliases semânticos validados para os adapters Livara. O serviço fixa `HOME` e os diretórios XDG, rejeita JSON incompleto ou cores inválidas e mantém o último estado válido por meio de replace atômico.

O `shell-conf` é o único owner do `browser/firefox.css` e dos demais adapters de aplicações. O bridge do Ambxst permanece owner do `wezterm/colors/Ambxst.toml`, porque o módulo WezTerm apenas seleciona e observa esse arquivo. O Ambxst continua sendo o único escritor de `colors.json`; o shell-conf não altera a configuração do Ambxst.

A ponte não mascara campos obrigatórios ausentes com uma cor fixa. Se `colors.json` ainda não existir, o serviço aguarda a fonte; se o documento for inválido, preserva o último output válido e registra a falha.

## Ativação

O flake expõe `packages.default`, `nixosModules.default` e `homeModules.default`. Importe `homeModules.default` em um perfil Home Manager que substitua o módulo Noctalia, ou `nixosModules.default` em uma composição NixOS que escolha Ambxst como shell. Não importe os dois módulos na mesma sessão. O host continua responsável por Niri e pelos serviços de sistema. Em NixOS, adicione o grupo `input` ao usuário quando a versão upstream exigir o monitoramento de teclas de modificador.

## Validação

A configuração deve ser validada com `nix flake check --no-build --no-update-lock-file --all-systems` em ambiente com Nix, `bash -n` nos scripts, `niri validate` para o arquivo final e verificação de processo único para Ambxst/Noctalia. Este repositório não executa build Nix automaticamente durante alterações locais.
