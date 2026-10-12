# claude-plugins

Marketplace `cloudfroghq` de plugins de Claude Code. Solo contiene manifiestos: el código de cada plugin vive en su propio repositorio o en un archivo de release.

## Plugins

| Plugin | Id | Qué hace | Estado |
|---|---|---|---|
| `knowledge-remote` | `knowledge-remote@cloudfroghq` | Conecta Claude Code a un servidor de conocimiento por HTTP con tu bearer personal | Disponible |

El catálogo crece por PR. Cada plugin se identifica como `<plugin>@cloudfroghq`.

## Instalación

Requiere Claude Code 2.1.275 o posterior.

```bash
# Sin llave SSH de GitHub: obligatorio para instalar desde /plugin y para actualizar
export CLAUDE_CODE_PLUGIN_PREFER_HTTPS=1

claude plugin marketplace add cloudfroghq/claude-plugins
claude plugin install knowledge-remote@cloudfroghq --scope user
```

Dentro de una sesión, la forma equivalente en un solo paso es:

```text
/plugin install knowledge-remote --marketplace cloudfroghq/claude-plugins
```

### Configurar `knowledge-remote`

El plugin pide dos valores y no trae ninguno por omisión:

| Opción | Qué poner |
|---|---|
| `knowledge_url` | `https://<host-de-tu-organización>/mcp` |
| `knowledge_token` | Tu bearer personal de alcance `read` (se guarda como valor sensible) |

Para guardarlos, abre `/plugin`, entra en Installed, elige `knowledge-remote` y usa Configure. También sirve `claude plugin configure knowledge-remote@cloudfroghq --values-stdin < valores.json`. No pases el bearer con `--config`: queda en el historial del shell. Después reinicia Claude Code.

Sin argumentos, `claude plugin configure` solo lista las opciones; no las guarda.

### Herramientas que expone

El servidor se llama `knowledge`, así que las tools llegan con el prefijo `mcp__plugin_knowledge-remote_knowledge__` (por ejemplo `mcp__plugin_knowledge-remote_knowledge__search`).

### Un solo plugin de conocimiento

No instales `knowledge-remote` junto con otro plugin que sirva el mismo catálogo de tools: el agente vería el catálogo duplicado. Elige uno.

## Seguridad

- El bearer es personal y solo lo guarda tu configuración local de Claude Code. Nunca va en este repositorio.
- El plugin envía el bearer en cada petición: usa solo URLs `https://`. Un servidor por `http://` expone el token en la red.
- Si el administrador de tu organización aún no te entregó una URL con TLS y un bearer personal, no hay nada que configurar todavía.

## Actualizar

```bash
claude plugin marketplace update cloudfroghq
claude plugin update knowledge-remote@cloudfroghq
```

Luego ejecuta `/reload-plugins`. La actualización automática del marketplace viene apagada; se recomienda dejarla así. Para congelar el catálogo en un estado exacto, agrega el marketplace con una referencia: `claude plugin marketplace add cloudfroghq/claude-plugins#<sha>`.

## Contribuir

Todo cambio entra por pull request a `main` (el ruleset `protect-main` exige PR). El workflow `validate` corre en cada PR y también a mano (`workflow_dispatch`):

1. `claude plugin validate --strict` sobre el marketplace y sobre cada plugin local.
2. `scripts/check-entries.sh`: sha256 de los archivos de release, pines de `git-subdir`, y que ningún `.mcp.json` use `http://` ni un bearer literal.
3. gitleaks sobre el historial.

En local:

```bash
claude plugin validate --strict .
claude plugin validate --strict plugins/knowledge-remote
bash scripts/check-entries.sh
```

El `version` de un plugin lo fija su `plugin.json`; las entradas del marketplace no llevan `version`.
