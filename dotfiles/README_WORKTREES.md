## Git Worktrees Manager

Script: `dotfiles/scripts/worktrees.sh`

### Características

- **create**: crea worktrees para ramas existentes (excluye `main` por defecto).
- **new**: crea rama(s) nuevas desde una rama base y levanta su worktree, con opción de push.
- **update**: actualiza cada worktree (`git pull`), soporta `--ff-only` (por defecto) o `--rebase`.
- **diff**: muestra cambios vs upstream (`origin/<branch>`).
- **push**: empuja todas o solo las que tienen cambios (`--changed`).
- **exec**: ejecuta un comando arbitrario en cada worktree.
- **tui**: abre una TUI por worktree con `dotbare` si está instalado (o `lazygit` como fallback).
  - Soporta selección interactiva con `fzf` con preview (rama, upstream, último commit, status del worktree).
- **list**: lista ramas y ruta de worktree.
- **status**: `git status --short` de cada worktree.
- **prune**: `git worktree prune` y verificación.

### Configuración

Variables de entorno (pueden persistirse en `.worktrees.env` en la raíz del repo):

- `WORKTREES_ROOT`: carpeta donde se crean los worktrees. Por defecto `<repo>/worktrees`.
- `EXCLUDE_BRANCHES`: ramas a excluir en operaciones implícitas. Por defecto `main`.
- `DEFAULT_BASE_BRANCH`: base para crear nuevas ramas. Por defecto `main`.
- `AUTO_PUSH_NEW_BRANCHES`: si `true`, hace push de ramas nuevas automáticamente.
- `RUN_PRE_COMMIT`: si `true`, ejecuta `pre-commit run -a` si hay configuración.
- `ENABLE_DOTBARE`, `DOTBARE_CMD`, `FZF_CMD`: integración con `dotbare` y `fzf`.
- `ENABLE_PARALLEL`, `PARALLEL_JOBS`: ejecutar `update/diff/push/exec` en paralelo.
- Validaciones y convenciones:
  - `ENFORCE_PRE_PUSH`, `HALT_ON_VALIDATION_FAIL`
  - `RUN_COMMITLINT`, `COMMITLINT_CMD`, `COMMITLINT_RANGE_MODE`
  - `BRANCH_NAME_REGEX`, `ENFORCE_BRANCH_CONVENTION`
- `PRE_CREATE_TASKS`, `POST_CREATE_TASKS`, `PRE_UPDATE_TASKS`, `POST_UPDATE_TASKS`, `PRE_PUSH_TASKS`, `POST_PUSH_TASKS`, `PRE_DIFF_TASKS`, `POST_DIFF_TASKS`: comandos a ejecutar por fase, en el contexto de cada worktree.

Ejemplo: ver `.worktrees.env.example`.

### Uso

Todos los comandos se ejecutan desde la raíz del repo o via ruta relativa `scripts/worktrees.sh`.

#### Crear worktrees para todas las ramas (excepto `main`):

```bash
dotfiles/scripts/worktrees.sh create
```

#### Crear ramas nuevas desde `main` y su worktree, y hacer push upstream:

```bash
dotfiles/scripts/worktrees.sh new --branches "feature-x feature-y" --base main --push
```

#### Actualizar todos los worktrees con rebase:

```bash
dotfiles/scripts/worktrees.sh update --rebase
```

#### Diff resumido por archivos:

```bash
dotfiles/scripts/worktrees.sh diff --name-only
```

#### Push solo de ramas con cambios:
Validaciones pre-push: si alguna tarea de fase `PRE_PUSH_TASKS`, `pre-commit` (si habilitado) o `commitlint` (si habilitado) falla, el push se aborta cuando `ENFORCE_PRE_PUSH=true`. Controla el comportamiento global con `HALT_ON_VALIDATION_FAIL`.


```bash
dotfiles/scripts/worktrees.sh push --changed
```

#### Ejecutar un comando (tests) en cada worktree:

```bash
dotfiles/scripts/worktrees.sh exec -- "npm ci && npm test"
```

#### Listar y ver status:

```bash
dotfiles/scripts/worktrees.sh list
dotfiles/scripts/worktrees.sh status
```

#### Prune:
#### Ejecutar en paralelo

```bash
dotfiles/scripts/worktrees.sh update --parallel
dotfiles/scripts/worktrees.sh diff --parallel --name-only
dotfiles/scripts/worktrees.sh push --changed --parallel
```

Controla el grado de paralelismo con `PARALLEL_JOBS` en `.worktrees.env`.

#### Archivar ramas y limpiar worktrees

```bash
dotfiles/scripts/worktrees.sh archive --branches "feat/x" --tag archived-$(date +%Y%m%d) --message "Archive feat/x"
```

Opciones: `--delete-remote`, `--keep-local`.
#### TUI por worktree (dotbare / lazygit)

```bash
dotfiles/scripts/worktrees.sh tui
```

Variables de entorno relevantes:

- `ENABLE_DOTBARE=true` para habilitar dotbare
- `DOTBARE_CMD=dotbare` para indicar el binario
- `FZF_CMD=fzf` para selección interactiva

dotbare: consulta la documentación oficial en [kazhala/dotbare](https://github.com/kazhala/dotbare)

### Promover rama (merge a base + prune worktree)

Nuevo comando `promote`:

```bash
dotfiles/scripts/worktrees.sh promote --branch feat/x --base main --no-ff
```

Opciones:
- `--branches` o `--branch`: una o varias ramas
- `--base`: rama base (por defecto `DEFAULT_BASE_BRANCH`)
- `--no-ff` o `--squash`
- `--delete-remote`: elimina la rama remota tras promover
- `--keep-worktree`: conserva el worktree local


```bash
dotfiles/scripts/worktrees.sh prune
```

### Sugerencias para el flujo de trabajo con worktrees

- **Convenciones de nombres**: prefijos por tipo (`feat/`, `fix/`, `chore/`, `exp/`).
- **Plantilla de hooks**: integrar `pre-commit` y `commitlint` para estandarizar calidad.
- **Tareas por fase**: instalar deps tras `create`, correr linters/tests en `update` y antes de `push`.
- **Integración CI**: pipeline que descubra worktrees/branches y ejecute validaciones por rama.
- **Sincronización automática**: cron local que ejecute `update --ff-only` periódicamente.
- **Locks**: evitar ejecuciones concurrentes peligrosas (futuro: archivo lock en `WORKTREES_ROOT`).
- **Selección interactiva**: añadir modo `fzf` para elegir ramas (futuro `--interactive`).
- **Matrices por entorno**: variables en `.worktrees.env` para tasks por proyecto/monorepo.
- **Compatibilidad Nix/ASDF**: preparar entorno por worktree (`direnv`, `.tool-versions`).
- **GC de worktrees**: comando `archive` (futuro) que empuje, taggee y borre worktree local.
