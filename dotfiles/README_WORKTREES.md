## Git Worktrees Manager

Script: `dotfiles/scripts/worktrees.sh`

### Características

- **create**: crea worktrees para ramas existentes (excluye `main` por defecto).
- **new**: crea rama(s) nuevas desde una rama base y levanta su worktree, con opción de push.
- **update**: actualiza cada worktree (`git pull`), soporta `--ff-only` (por defecto) o `--rebase`.
- **diff**: muestra cambios vs upstream (`origin/<branch>`).
- **push**: empuja todas o solo las que tienen cambios (`--changed`).
- **exec**: ejecuta un comando arbitrario en cada worktree.
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


