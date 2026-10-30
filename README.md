# claude-plugins

Marketplace `cloudfroghq` de plugins de Claude Code. Solo contiene manifiestos: el código de cada plugin vive en su propio repositorio o en un archivo de release.

## Plugins

| Plugin | Id | Qué hace | Estado |
|---|---|---|---|
| `knowledge` | `knowledge@cloudfroghq` | Corre el servidor de conocimiento en tu máquina por stdio, con `uvx`, sobre tus vaults locales | Disponible (código en el repositorio público `cloudfroghq/knowledge`) |
| `knowledge-remote` | `knowledge-remote@cloudfroghq` | Conecta Claude Code a un servidor de conocimiento por HTTP con tu bearer personal | Disponible |

El catálogo crece por PR. Cada plugin se identifica como `<plugin>@cloudfroghq`. Elige uno de los dos de conocimiento: `knowledge` si tienes tus vaults en disco, `knowledge-remote` si usas el servidor HTTP de tu organización.

## Instalación

Requiere Claude Code 2.1.275 o posterior.

### Instalar `knowledge` (stdio)

```bash
claude plugin marketplace add cloudfroghq/claude-plugins
claude plugin install knowledge@cloudfroghq --scope user
```

Dentro de una sesión: `/plugin install knowledge --marketplace cloudfroghq/claude-plugins`.

Requisitos:

- Acceso a `github.com` por HTTPS. La entrada del marketplace usa la URL HTTPS del repositorio público `cloudfroghq/knowledge`: Claude Code clona el plugin sin llave SSH ni credenciales, y `uvx` trae el tag del servidor por `git+https` en cada arranque.
- `uv`, con `uvx` resoluble desde el entorno con el que arranca Claude Code. El plugin corre `uvx --managed-python --python 3.12`, que descarga un Python 3.12 gestionado por `uv` la primera vez. Si no hereda tu `PATH` (por ejemplo, al abrirlo desde el Dock), define `UVX_BIN` con la ruta absoluta.
- Un registro de vaults en `~/.config/knowledge/vaults.yaml`, o el archivo que indiques en la opción `vaults_config`.
- `OPENAI_API_KEY` en el entorno de la sesión si algún vault usa el proveedor `openai`. La clave no es una opción del plugin: se hereda del entorno.

El primer arranque clona el tag, descarga unas dependencias con `uv` (y, si hace falta, el Python gestionado) y puede superar los 30 s que Claude Code espera a un servidor MCP. Precalienta la caché ejecutando el `doctor` del mismo paquete, con el tag que indica el campo `ref` de la entrada `knowledge` en `.claude-plugin/marketplace.json`:

```bash
uvx --managed-python --python 3.12 --from 'git+https://github.com/cloudfroghq/knowledge.git@<ref>' cloudfrog-knowledge doctor
```

Si aun así el servidor aparece como `failed` en `/mcp`, sube `MCP_TIMEOUT` (por ejemplo `60000`) en el bloque `env` de `~/.claude/settings.json`.

#### Opciones de `knowledge`

Las dos son opcionales; sin valor, el plugin usa los valores por omisión del servidor.

| Opción | Qué poner |
|---|---|
| `vaults_config` | Ruta a un `vaults.yaml` con los vaults a servir. Vacío: `~/.config/knowledge/vaults.yaml` |
| `embeddings_provider` | `openai`, `none` o `bag-of-words`. Vacío: el que declare `vaults.yaml` (por omisión `openai`) |

Para cambiarlas, abre `/plugin`, entra en Installed, elige `knowledge` y usa Configure, o ejecuta `claude plugin configure knowledge@cloudfroghq --values-stdin < valores.json`. Sin argumentos, `claude plugin configure knowledge@cloudfroghq` solo lista las opciones. Después reinicia Claude Code.

### Instalar `knowledge-remote` (HTTP)

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

#### Opciones de `knowledge-remote`

El plugin pide dos valores y no trae ninguno por omisión:

| Opción | Qué poner |
|---|---|
| `knowledge_url` | `https://<host-de-tu-organización>/mcp` |
| `knowledge_token` | Tu bearer personal de alcance `read` (se guarda como valor sensible) |

Para guardarlos, abre `/plugin`, entra en Installed, elige `knowledge-remote` y usa Configure. También sirve `claude plugin configure knowledge-remote@cloudfroghq --values-stdin < valores.json`. No pases el bearer con `--config`: queda en el historial del shell. Después reinicia Claude Code.

Sin argumentos, `claude plugin configure` solo lista las opciones; no las guarda.

### Herramientas que expone

El servidor se llama `knowledge` en los dos plugins y el prefijo de las tools lo da el plugin:

| Plugin | Prefijo | Ejemplo |
|---|---|---|
| `knowledge` | `mcp__plugin_knowledge_knowledge__` | `mcp__plugin_knowledge_knowledge__search` |
| `knowledge-remote` | `mcp__plugin_knowledge-remote_knowledge__` | `mcp__plugin_knowledge-remote_knowledge__search` |

### Un solo plugin de conocimiento

No instales `knowledge` junto con `knowledge-remote` ni con otro plugin que sirva el mismo catálogo de tools: el agente vería el catálogo duplicado. Elige uno.

## Seguridad

- `knowledge-remote`: el bearer es personal y solo lo guarda tu configuración local de Claude Code. Nunca va en este repositorio.
- `knowledge-remote` envía el bearer en cada petición: usa solo URLs `https://`. Un servidor por `http://` expone el token en la red.
- Si el administrador de tu organización aún no te entregó una URL con TLS y un bearer personal, no hay nada que configurar en `knowledge-remote` todavía.
- `knowledge` no maneja bearers ni claves en sus opciones: `OPENAI_API_KEY` se hereda del entorno de la sesión y el plugin no la guarda.
- La entrada de `knowledge` fija el plugin a un tag (`ref`) y al commit exacto de ese tag (`sha`): Claude Code hace checkout del commit, así que mover o borrar el tag no cambia lo que se instala.

## Actualizar

```bash
claude plugin marketplace update cloudfroghq
claude plugin update knowledge@cloudfroghq          # o knowledge-remote@cloudfroghq
```

Luego ejecuta `/reload-plugins`. La actualización automática del marketplace viene apagada; se recomienda dejarla así. Para congelar el catálogo en un estado exacto, agrega el marketplace con una referencia: `claude plugin marketplace add cloudfroghq/claude-plugins#<sha>`.

Una versión nueva de `knowledge` llega al catálogo cuando un PR cambia `ref` y `sha` de su entrada; mientras ese PR no se mergee, `claude plugin update` no la ve.

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

Al subir la versión de una entrada `git-subdir`, `sha` es el commit al que apunta el tag, no el objeto del tag: con un tag anotado, `git rev-parse <tag>` devuelve el id del objeto del tag. Obtén el commit con `git rev-parse '<tag>^{commit}'` (o `gh api repos/<owner>/<repo>/commits/<tag> --jq .sha`).
