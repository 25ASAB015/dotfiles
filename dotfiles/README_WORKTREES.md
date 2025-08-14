# Git Worktrees Manager - Guía Completa

## 📚 Tabla de Contenidos
1. [¿Qué es esto y por qué me importa?](#qué-es-esto-y-por-qué-me-importa)
2. [Conceptos Básicos](#conceptos-básicos)
3. [Instalación y Configuración](#instalación-y-configuración)
4. [Flujos de Trabajo Diarios](#flujos-de-trabajo-diarios)
5. [Comandos y Características](#comandos-y-características)
6. [Escenarios Comunes](#escenarios-comunes)
7. [Solución de Problemas](#solución-de-problemas)
8. [Referencia Rápida](#referencia-rápida)

## 🎯 ¿Qué es esto y por qué me importa?

### Para No Técnicos
Imagina que estás escribiendo un libro con varios capítulos. Normalmente tendrías que:
1. Terminar el capítulo 1 antes de empezar el 2
2. Si alguien te pide un cambio en el capítulo 1 mientras escribes el 3, debes guardar todo, volver, hacer el cambio, y luego intentar recordar dónde estabas

**Con worktrees es como tener múltiples escritorios**, uno para cada capítulo. Puedes saltar entre ellos sin perder tu progreso.

### Para Desarrolladores
Los worktrees de git te permiten tener múltiples ramas checked out simultáneamente en diferentes directorios. Este script automatiza y mejora ese flujo con:
- Gestión automática de worktrees
- Validaciones pre-push
- Convenciones enforced
- Integración con herramientas modernas (fzf, dotbare, commitlint)

## 📖 Conceptos Básicos

### ¿Qué es un Worktree?
- **Analogía simple**: Es como tener copias separadas de tu proyecto, cada una en un estado diferente
- **Técnicamente**: Permite tener múltiples ramas de git activas simultáneamente en carpetas separadas

### ¿Por qué usar Worktrees?
1. **Sin cambios de contexto**: No pierdes cambios no guardados al cambiar de rama
2. **Trabajo paralelo**: Puedes compilar en una rama mientras editas otra
3. **Comparación fácil**: Abre dos ramas lado a lado en tu editor
4. **Sin conflictos**: Cada rama tiene su propio espacio

### Estructura de Carpetas
```
dotfiles/                 # Tu repositorio principal
├── worktrees/           # Aquí viven todos tus worktrees
│   ├── feat/nueva-ui/   # Trabajando en nueva interfaz
│   ├── fix/bug-login/   # Arreglando bug de login
│   └── docs/readme/     # Actualizando documentación
├── dotfiles/            # Tu código
└── .worktrees.env       # Tu configuración personal
```

## 🚀 Instalación y Configuración

### Requisitos Previos
```bash
# Esenciales
git --version           # Necesitas git 2.5+
bash --version          # Bash 4.0+

# Recomendados
npm --version           # Para commitizen y validaciones
fzf --version          # Para selección interactiva
lazygit --version      # O dotbare para TUI

# En Arch Linux
sudo pacman -S git bash fzf lazygit nodejs npm
paru -S  tree bat highlight ruby-coderay git-delta diff-so-fancy
yay -S dotbare         # Opcional, desde AUR
```

### Configuración Inicial

#### 1. Configuración Básica
```bash
# Crear tu archivo de configuración
cp dotfiles/.worktrees.env.example .worktrees.env

# Editar según tus necesidades
nano .worktrees.env
```

#### 2. Configuración Recomendada para Principiantes
```bash
# .worktrees.env
WORKTREES_ROOT="${HOME}/proyectos/worktrees"  # Dónde guardar worktrees
ENFORCE_PRE_PUSH="true"                        # Validar antes de publicar
RUN_COMMITLINT="true"                          # Validar mensajes de commit
ENFORCE_BRANCH_CONVENTION="true"               # Forzar nombres correctos
ENABLE_PARALLEL="false"                        # Desactivar paralelismo al inicio
```

#### 3. Instalar Herramientas de Validación
```bash
# En la raíz del repositorio
npm install  # Instala commitlint, husky, commitizen
```

## 📅 Flujos de Trabajo Diarios

### 🌅 Inicio del Día

#### 1. Actualizar Todo
```bash
# Ver qué tienes activo
dotfiles/scripts/worktrees.sh list

# Actualizar todos tus worktrees con los últimos cambios
dotfiles/scripts/worktrees.sh update -i

# O actualizar todo automáticamente
dotfiles/scripts/worktrees.sh update
```

#### 2. Revisar Estado
```bash
# Ver estado de todos los worktrees
dotfiles/scripts/worktrees.sh status

# Ver cambios pendientes
dotfiles/scripts/worktrees.sh diff --stat
```

### 💼 Trabajando en una Nueva Funcionalidad

#### Escenario: "Necesito agregar autenticación con Google"

```bash
# 1. Crear la rama con nombre correcto automáticamente
dotfiles/scripts/worktrees.sh mkbranch \
  --prefix feat \
  --title "google auth integration" \
  --base main \
  --push

# Esto crea: feat/google-auth-integration

# 2. El script automáticamente:
# - Crea la rama
# - Prepara el worktree en worktrees/feat/google-auth-integration
# - Hace push inicial a GitHub
# - Te deja listo para trabajar

# 3. Ir al nuevo worktree
cd worktrees/feat/google-auth-integration

# 4. Trabajar normalmente
# ... hacer cambios ...

# 5. Commitear con el asistente
npm run commit
# Selecciona: feat
# Scope: auth
# Mensaje: add Google OAuth2 integration
# Descripción larga: explica los detalles

# 6. Publicar cambios
dotfiles/scripts/worktrees.sh push --changed
```

### 🐛 Arreglando un Bug Urgente

#### Escenario: "El login está roto en producción"

```bash
# 1. Crear rama de fix rápidamente
dotfiles/scripts/worktrees.sh mkbranch \
  --prefix fix \
  --title "login validation error" \
  --base main \
  --push

# 2. Ir al worktree del fix
cd worktrees/fix/login-validation-error

# 3. Hacer el arreglo
# ... editar código ...

# 4. Commit rápido pero correcto
npm run commit
# Tipo: fix
# Scope: auth
# Mensaje: correct validation logic for email field

# 5. Push con validaciones
dotfiles/scripts/worktrees.sh push

# 6. Promover a main rápidamente
dotfiles/scripts/worktrees.sh promote \
  --branch fix/login-validation-error \
  --base main \
  --no-ff
```

### 📝 Actualizando Documentación

```bash
# 1. Crear rama de docs
dotfiles/scripts/worktrees.sh mkbranch \
  --prefix docs \
  --title "api endpoints guide" \
  --base main

# 2. Trabajar en la documentación
cd worktrees/docs/api-endpoints-guide
# ... editar archivos .md ...

# 3. Vista previa mientras trabajas
# Abre otro terminal y sirve los docs localmente

# 4. Commits descriptivos
npm run commit
# docs: add REST API endpoint documentation
# docs: include authentication examples
# docs: add error response codes

# 5. Push cuando esté listo
dotfiles/scripts/worktrees.sh push
```

### 🔄 Cambio Rápido Entre Tareas

#### Escenario: "Estoy en feature A pero necesito revisar feature B"

```bash
# Opción 1: Usar TUI interactivo
dotfiles/scripts/worktrees.sh tui

# Opción 2: Cambio directo
cd worktrees/feat/feature-b

# Opción 3: Abrir en nueva ventana de VS Code
code worktrees/feat/feature-b

# Tu trabajo en feature A sigue intacto en su worktree
```

### 🎯 Fin del Día

```bash
# 1. Revisar qué tienes pendiente
dotfiles/scripts/worktrees.sh status

# 2. Hacer push de cambios importantes
dotfiles/scripts/worktrees.sh push --changed -i

# 3. Ver resumen de diferencias
dotfiles/scripts/worktrees.sh diff --stat

# 4. Opcionalmente, dejar nota para mañana
echo "TODO: Terminar validación de formulario" > worktrees/feat/mi-feature/TODO.txt
```

## 🛠️ Comandos y Características

### Comandos Principales

#### `create` - Crear worktrees para ramas existentes
```bash
# Interactivo (recomendado)
dotfiles/scripts/worktrees.sh create -i

# Para ramas específicas
dotfiles/scripts/worktrees.sh create --branches "dev feature-x"

# Crear todos (excepto main)
dotfiles/scripts/worktrees.sh create
```

#### `new` - Crear nuevas ramas + worktrees
```bash
# Básico
dotfiles/scripts/worktrees.sh new --branches "feat/mi-idea"

# Con push automático
dotfiles/scripts/worktrees.sh new --branches "feat/mi-idea" --push

# Múltiples ramas
dotfiles/scripts/worktrees.sh new \
  --branches "feat/ui feat/api" \
  --base develop \
  --push
```

#### `mkbranch` - Crear rama con convención automática ⭐
```bash
# La forma más fácil de crear ramas correctas
dotfiles/scripts/worktrees.sh mkbranch \
  --prefix feat \
  --title "amazing new feature" \
  --base main \
  --push

# Crea: feat/amazing-new-feature
```

#### `update` - Actualizar worktrees
```bash
# Fast-forward (seguro, por defecto)
dotfiles/scripts/worktrees.sh update

# Con rebase (reescribe historia local)
dotfiles/scripts/worktrees.sh update --rebase

# Interactivo
dotfiles/scripts/worktrees.sh update -i
```

#### `diff` - Ver cambios
```bash
# Resumen de cambios
dotfiles/scripts/worktrees.sh diff --stat

# Solo nombres de archivos
dotfiles/scripts/worktrees.sh diff --name-only

# Diff completo
dotfiles/scripts/worktrees.sh diff

# Interactivo
dotfiles/scripts/worktrees.sh diff --stat -i
```

#### `push` - Publicar cambios
```bash
# Push solo ramas con cambios
dotfiles/scripts/worktrees.sh push --changed

# Push todas
dotfiles/scripts/worktrees.sh push

# Con --force-with-lease (seguro)
dotfiles/scripts/worktrees.sh push --force-with-lease

# Interactivo
dotfiles/scripts/worktrees.sh push --changed -i
```

#### `exec` - Ejecutar comando en cada worktree
```bash
# Instalar dependencias en todos
dotfiles/scripts/worktrees.sh exec -- "npm install"

# Correr tests
dotfiles/scripts/worktrees.sh exec -- "npm test"

# Limpiar archivos temporales
dotfiles/scripts/worktrees.sh exec -- "rm -rf node_modules"
```

#### `tui` - Interfaz visual
```bash
# Abrir dotbare o lazygit
dotfiles/scripts/worktrees.sh tui

# En rama específica
dotfiles/scripts/worktrees.sh tui --branch feat/mi-feature
```

#### `promote` - Integrar rama a base
```bash
# Merge normal
dotfiles/scripts/worktrees.sh promote \
  --branch feat/mi-feature \
  --base main

# No fast-forward (preserva historia)
dotfiles/scripts/worktrees.sh promote \
  --branch feat/mi-feature \
  --base main \
  --no-ff

# Squash (un solo commit)
dotfiles/scripts/worktrees.sh promote \
  --branch feat/mi-feature \
  --base main \
  --squash

# Eliminar rama remota después
dotfiles/scripts/worktrees.sh promote \
  --branch feat/mi-feature \
  --base main \
  --delete-remote
```

#### `archive` - Archivar ramas completadas
```bash
# Archivar con tag
dotfiles/scripts/worktrees.sh archive \
  --branches "feat/old-feature" \
  --tag "v1.0-archived" \
  --message "Archived after v1.0 release"

# Archivar y eliminar remoto
dotfiles/scripts/worktrees.sh archive \
  --branches "feat/deprecated" \
  --delete-remote
```

### Variables de Configuración

#### Básicas
- `WORKTREES_ROOT`: Dónde crear los worktrees
- `EXCLUDE_BRANCHES`: Ramas a ignorar (default: "main")
- `DEFAULT_BASE_BRANCH`: Base para nuevas ramas (default: "main")

#### Comportamiento
- `AUTO_PUSH_NEW_BRANCHES`: Push automático al crear
- `ENABLE_PARALLEL`: Ejecutar operaciones en paralelo
- `PARALLEL_JOBS`: Número de jobs paralelos

#### Validaciones
- `ENFORCE_PRE_PUSH`: Forzar validaciones antes de push
- `HALT_ON_VALIDATION_FAIL`: Parar todo si falla validación
- `RUN_PRE_COMMIT`: Ejecutar pre-commit hooks
- `RUN_COMMITLINT`: Validar mensajes de commit
- `COMMITLINT_RANGE_MODE`: "last" o "range"

#### Convenciones
- `BRANCH_NAME_REGEX`: Regex para validar nombres
- `ENFORCE_BRANCH_CONVENTION`: Forzar convención

#### Integraciones
- `ENABLE_DOTBARE`: Habilitar dotbare
- `DOTBARE_CMD`: Comando dotbare
- `FZF_CMD`: Comando fzf

#### Tareas Personalizadas
- `PRE_CREATE_TASKS`: Antes de crear worktree
- `POST_CREATE_TASKS`: Después de crear
- `PRE_UPDATE_TASKS`: Antes de actualizar
- `POST_UPDATE_TASKS`: Después de actualizar
- `PRE_PUSH_TASKS`: Antes de push
- `POST_PUSH_TASKS`: Después de push

### Ejemplo de .worktrees.env Completo
```bash
# Ubicación de worktrees
WORKTREES_ROOT="${HOME}/desarrollo/worktrees"

# Ramas a excluir
EXCLUDE_BRANCHES="main master production"

# Base por defecto
DEFAULT_BASE_BRANCH="develop"

# Comportamiento automático
AUTO_PUSH_NEW_BRANCHES="true"
ENABLE_PARALLEL="true"
PARALLEL_JOBS="4"

# Validaciones estrictas
ENFORCE_PRE_PUSH="true"
HALT_ON_VALIDATION_FAIL="true"
RUN_PRE_COMMIT="true"
RUN_COMMITLINT="true"
COMMITLINT_RANGE_MODE="last"

# Convenciones
BRANCH_NAME_REGEX="^(feat|fix|chore|docs|refactor|test|build|ci|perf|style)\/[a-z0-9._-]+$"
ENFORCE_BRANCH_CONVENTION="true"

# Herramientas
ENABLE_DOTBARE="true"
DOTBARE_CMD="dotbare"
FZF_CMD="fzf"

# Tareas automatizadas
PRE_CREATE_TASKS="npm ci && npm run prepare"
POST_CREATE_TASKS="echo 'Worktree listo en $(pwd)'"
PRE_UPDATE_TASKS="npm ci"
POST_UPDATE_TASKS="npm run lint:fix"
PRE_PUSH_TASKS="npm test && npm run build"
POST_PUSH_TASKS="echo 'Push completado'"
```

## 🎬 Escenarios Comunes

### Escenario 1: Desarrollador Full-Stack Solo

**Contexto**: Trabajas solo en una aplicación web

```bash
# Lunes: Nueva feature de dashboard
dotfiles/scripts/worktrees.sh mkbranch \
  --prefix feat \
  --title "admin dashboard" \
  --push

# Trabajar en frontend
cd worktrees/feat/admin-dashboard
npm run dev
# ... desarrollo ...

# Martes: Bug urgente aparece
# No necesitas detener tu trabajo en el dashboard
dotfiles/scripts/worktrees.sh mkbranch \
  --prefix fix \
  --title "user session timeout" \
  --push

# Arreglar en paralelo
cd worktrees/fix/user-session-timeout
# ... fix rápido ...
npm run commit  # "fix: correct session timeout calculation"
dotfiles/scripts/worktrees.sh push

# Volver al dashboard sin perder nada
cd worktrees/feat/admin-dashboard
# Todo sigue exactamente donde lo dejaste
```

### Escenario 2: Equipo Colaborativo

**Contexto**: Trabajas con 3 personas más

```bash
# Actualizar todo antes de empezar
dotfiles/scripts/worktrees.sh update --rebase

# Ver en qué está trabajando el equipo
dotfiles/scripts/worktrees.sh list
dotfiles/scripts/worktrees.sh status

# Crear tu parte del proyecto
dotfiles/scripts/worktrees.sh mkbranch \
  --prefix feat \
  --title "payment integration" \
  --base develop \
  --push

# Trabajar...
cd worktrees/feat/payment-integration

# Antes de push, actualizar y validar
dotfiles/scripts/worktrees.sh update --rebase
dotfiles/scripts/worktrees.sh push --changed

# Revisar el trabajo de un compañero
dotfiles/scripts/worktrees.sh create --branches "feat/alice-oauth"
cd worktrees/feat/alice-oauth
# Revisar código...
```

### Escenario 3: Hotfix en Producción

**Contexto**: Cliente reporta bug crítico, necesitas fix inmediato

```bash
# 1. Crear branch de hotfix desde production
dotfiles/scripts/worktrees.sh mkbranch \
  --prefix fix \
  --title "critical payment bug" \
  --base production \
  --push

# 2. Fix rápido
cd worktrees/fix/critical-payment-bug
# ... arreglar ...

# 3. Test local
npm test

# 4. Commit y push
npm run commit  # "fix: prevent double charging on payment retry"
dotfiles/scripts/worktrees.sh push

# 5. Promover a production inmediatamente
dotfiles/scripts/worktrees.sh promote \
  --branch fix/critical-payment-bug \
  --base production \
  --no-ff

# 6. También aplicar a develop
dotfiles/scripts/worktrees.sh promote \
  --branch fix/critical-payment-bug \
  --base develop \
  --no-ff
```

### Escenario 4: Revisión de Código

**Contexto**: Necesitas revisar 3 PRs diferentes

```bash
# Crear worktrees para los PRs
dotfiles/scripts/worktrees.sh create --branches \
  "feat/new-api feat/ui-redesign fix/memory-leak"

# Abrir cada uno en una ventana separada
code worktrees/feat/new-api
code worktrees/feat/ui-redesign
code worktrees/fix/memory-leak

# Ejecutar tests en paralelo
dotfiles/scripts/worktrees.sh exec \
  --branches "feat/new-api feat/ui-redesign fix/memory-leak" \
  -- "npm test"

# Aprobar y promover los buenos
dotfiles/scripts/worktrees.sh promote \
  --branch feat/new-api \
  --base develop \
  --no-ff
```

### Escenario 5: Experimentación

**Contexto**: Quieres probar 3 enfoques diferentes

```bash
# Crear ramas experimentales
for approach in "websockets" "polling" "sse"; do
  dotfiles/scripts/worktrees.sh mkbranch \
    --prefix exp \
    --title "realtime-$approach" \
    --base develop
done

# Trabajar en paralelo
cd worktrees/exp/realtime-websockets
# implementar...

cd ../exp/realtime-polling
# implementar...

cd ../exp/realtime-sse
# implementar...

# Comparar rendimiento
dotfiles/scripts/worktrees.sh exec \
  --branches "exp/realtime-websockets exp/realtime-polling exp/realtime-sse" \
  -- "npm run benchmark"

# Promover el ganador
dotfiles/scripts/worktrees.sh promote \
  --branch exp/realtime-websockets \
  --base develop \
  --squash

# Archivar los otros
dotfiles/scripts/worktrees.sh archive \
  --branches "exp/realtime-polling exp/realtime-sse" \
  --tag "experiment-realtime-alternatives"
```

## 🔧 Solución de Problemas

### Problema: "No puedo hacer push"

#### Síntoma
```
Pre-push validations failed for feat/mi-feature
```

#### Solución
```bash
# 1. Ver qué falló exactamente
cd worktrees/feat/mi-feature
npm test  # ¿Fallan los tests?
npm run lint  # ¿Errores de lint?

# 2. Arreglar los problemas
npm run lint:fix  # Arreglo automático
# Corregir tests manualmente...

# 3. Verificar commits
git log --oneline -n 5
# ¿Siguen el formato conventional?

# 4. Si un commit está mal, arreglarlo
git commit --amend  # Para el último
# O usar rebase interactivo para anteriores

# 5. Intentar de nuevo
dotfiles/scripts/worktrees.sh push
```

### Problema: "Tengo conflictos al actualizar"

#### Síntoma
```
CONFLICT (content): Merge conflict in src/app.js
```

#### Solución
```bash
# 1. Identificar dónde estás
pwd  # worktrees/feat/mi-feature

# 2. Ver el conflicto
git status
git diff

# 3. Resolver en tu editor
code .  # Abrir VS Code
# Buscar <<<<<<< y resolver

# 4. Marcar como resuelto
git add src/app.js
git rebase --continue  # Si era rebase
# o
git commit  # Si era merge

# 5. Push cuando esté listo
dotfiles/scripts/worktrees.sh push
```

### Problema: "Perdí mi trabajo"

#### Síntoma
"Hice cambios pero no están"

#### Solución
```bash
# 1. Verificar en qué worktree estás
pwd

# 2. Revisar el reflog
git reflog

# 3. Buscar en todos los worktrees
dotfiles/scripts/worktrees.sh exec -- "git status"

# 4. Recuperar commits perdidos
git cherry-pick <commit-hash>

# 5. Prevención futura
# Commitear frecuentemente
# Usar el TUI para visualizar
dotfiles/scripts/worktrees.sh tui
```

### Problema: "El script no funciona"

#### Diagnóstico
```bash
# 1. Verificar permisos
ls -la dotfiles/scripts/worktrees.sh
# Debe tener permisos de ejecución (x)

# 2. Verificar bash
bash --version
# Necesitas 4.0+

# 3. Verificar git
git --version
# Necesitas 2.5+

# 4. Debug mode
bash -x dotfiles/scripts/worktrees.sh list

# 5. Verificar configuración
cat .worktrees.env
```

### Problema: "No entiendo qué rama usar"

#### Guía de Decisión
```
¿Qué vas a hacer?
├─ ¿Nueva funcionalidad? → feat/
├─ ¿Arreglar bug? → fix/
├─ ¿Documentación? → docs/
├─ ¿Mantenimiento? → chore/
├─ ¿Mejorar código? → refactor/
├─ ¿Agregar tests? → test/
├─ ¿Cambios de build? → build/
├─ ¿CI/CD? → ci/
├─ ¿Optimización? → perf/
└─ ¿Formato/estilo? → style/
```

## 📊 Métricas y Reportes

### Ver Estado General
```bash
# Resumen de todos los worktrees
dotfiles/scripts/worktrees.sh list | column -t

# Estado detallado
dotfiles/scripts/worktrees.sh status > status-report.txt

# Cambios pendientes
dotfiles/scripts/worktrees.sh diff --stat > pending-changes.txt
```

### Generar Reporte Semanal
```bash
#!/bin/bash
# weekly-report.sh
echo "=== Reporte Semanal $(date) ===" > weekly-report.md
echo "" >> weekly-report.md

echo "## Worktrees Activos" >> weekly-report.md
dotfiles/scripts/worktrees.sh list >> weekly-report.md

echo -e "\n## Cambios Pendientes" >> weekly-report.md
dotfiles/scripts/worktrees.sh diff --stat >> weekly-report.md

echo -e "\n## Estado por Rama" >> weekly-report.md
dotfiles/scripts/worktrees.sh status >> weekly-report.md
```

## 🎯 Tips Pro

### 1. Alias Útiles
```bash
# Agregar a ~/.bashrc o ~/.zshrc
alias wt='dotfiles/scripts/worktrees.sh'
alias wtnew='dotfiles/scripts/worktrees.sh mkbranch'
alias wtup='dotfiles/scripts/worktrees.sh update -i'
alias wtpush='dotfiles/scripts/worktrees.sh push --changed -i'
alias wts='dotfiles/scripts/worktrees.sh status'
alias wttui='dotfiles/scripts/worktrees.sh tui'
```

### 2. Integración con IDE

#### VS Code
```json
// .vscode/settings.json
{
  "git.defaultCloneDirectory": "${workspaceFolder}/worktrees",
  "terminal.integrated.cwd": "${workspaceFolder}/worktrees",
  "search.exclude": {
    "**/worktrees": true
  }
}
```

#### Script para abrir worktree en VS Code
```bash
#!/bin/bash
# open-worktree.sh
BRANCH=$(dotfiles/scripts/worktrees.sh list | fzf | awk '{print $1}')
if [ -n "$BRANCH" ]; then
  code "worktrees/$BRANCH"
fi
```

### 3. Automatización con Cron
```bash
# Actualizar worktrees cada mañana
0 9 * * * cd ~/projects/dotfiles && dotfiles/scripts/worktrees.sh update --ff-only
```

### 4. Git Hooks Personalizados
```bash
# .git/hooks/pre-push
#!/bin/bash
dotfiles/scripts/worktrees.sh push --changed --dry-run
```

## 🚀 Siguiente Nivel

### Integraciones Avanzadas

#### 1. CI/CD Pipeline
```yaml
# .github/workflows/worktree-ci.yml
name: Worktree CI
on:
  push:
    branches: ['feat/*', 'fix/*']
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - run: npm ci
      - run: npm test
      - run: npm run lint
```

#### 2. Notificaciones
```bash
# Agregar a POST_PUSH_TASKS
POST_PUSH_TASKS="notify-send 'Push Completado' 'Rama: \$(git branch --show-current)'"
```

#### 3. Métricas de Productividad
```bash
# Tiempo en cada worktree
POST_UPDATE_TASKS="echo \$(date): Updated \$(git branch --show-current) >> ~/.worktree-log"
```

## 📚 Recursos Adicionales

### Documentación
- [Git Worktree Docs](https://git-scm.com/docs/git-worktree)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Commitizen](http://commitizen.github.io/cz-cli/)

### Herramientas Relacionadas
- [fzf](https://github.com/junegunn/fzf) - Fuzzy finder
- [dotbare](https://github.com/kazhala/dotbare) - Dotfiles manager
- [lazygit](https://github.com/jesseduffield/lazygit) - Terminal UI for git

### Comunidad
- Issues: Reporta problemas en GitHub
- PRs: Contribuciones bienvenidas
- Discussions: Comparte tus flujos de trabajo

## 🎉 Conclusión

Con este sistema tienes:
- ✅ Múltiples contextos de trabajo sin fricción
- ✅ Validaciones automáticas
- ✅ Convenciones enforced
- ✅ Flujo de trabajo optimizado
- ✅ Menos errores, más productividad

¡Feliz coding con worktrees! 🚀
