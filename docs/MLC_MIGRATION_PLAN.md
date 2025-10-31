# 🔄 Migration Plan: Aurora → MLC

## Новое название: **MLC** (Multi-Level Compiler)

### Причины выбора:
- ✅ 3 буквы (как gcc, clang, llc)
- ✅ Технически точное (Multi-Level Compiler)
- ✅ Фокус на multi-level IR architecture
- ✅ Легко произносить (em-el-see)

---

## Текущая структура:

```
cpp_ast_v3/                     # Старое название проекта
├── lib/aurora/                 # Aurora namespace
│   ├── ast/
│   ├── core_ir/
│   ├── mid_ir/
│   ├── backend/
│   └── ...
└── test/aurora/
```

---

## Целевая структура:

```
mlc/                            # Новое название проекта
├── lib/mlc/                    # MLC namespace
│   ├── ast/                   # Parser (Aurora syntax)
│   ├── high_ir/               # High IR (переименовать core_ir)
│   ├── mid_ir/                # Mid IR ✅ уже есть
│   ├── low_ir/                # Low IR (будущее)
│   ├── target/                # Target backends
│   │   ├── cpp/              # C++ backend (переименовать backend/)
│   │   ├── llvm/             # LLVM backend (будущее)
│   │   └── wasm/             # WASM backend (будущее)
│   ├── analysis/              # Analysis passes
│   ├── pass_manager.rb        # Pass manager
│   └── version.rb
├── test/mlc/
├── bin/mlc                     # CLI tool
└── README.md
```

---

## План миграции (5 фаз):

### Phase 1: Rename project directory ⏸️
```bash
# Переименовать директорию
mv cpp_ast_v3 mlc

# Обновить git remote (если нужно)
git remote set-url origin git@github.com:username/mlc.git
```

### Phase 2: Rename namespace (Ruby modules) ⏸️
```ruby
# Было:
module Aurora
  module CoreIR
  end
end

# Станет:
module MLC
  module HighIR
  end
end
```

**Файлы для изменения:**
```
lib/aurora/ → lib/mlc/
  - Все .rb файлы: module Aurora → module MLC
  - core_ir/ → high_ir/
  - backend/ → target/cpp/

test/aurora/ → test/mlc/
  - Все require_relative "aurora" → require_relative "mlc"
```

### Phase 3: Rename CLI and public API ⏸️
```ruby
# Было:
Aurora.parse(source)
Aurora.compile(source)

# Станет:
MLC.parse(source)
MLC.compile(source)
```

### Phase 4: Update documentation ⏸️
```markdown
# README.md
# MLC - Multi-Level Compiler

MLC is a multi-level intermediate representation compiler framework.

## Installation
gem install mlc-compiler

## Usage
mlc build app.aur
mlc --emit=high app.aur
mlc --emit=mid app.aur
```

### Phase 5: Publish ⏸️
```bash
# Gem name
gem build mlc.gemspec
gem push mlc-0.1.0.gem

# GitHub
# Repository: github.com/username/mlc
# Website: mlc-lang.org (или mlc.dev)
```

---

## Detailed Renaming (по модулям):

### 1. Core modules:
```
lib/aurora.rb → lib/mlc.rb
lib/aurora/ → lib/mlc/

Module Aurora → Module MLC
```

### 2. IR levels:
```
lib/aurora/core_ir/ → lib/mlc/high_ir/
  CoreIR::* → HighIR::*

lib/aurora/mid_ir/ → lib/mlc/mid_ir/
  (без изменений, уже правильное название)

lib/aurora/backend/ → lib/mlc/target/cpp/
  Aurora::Backend::CodeGen → MLC::Target::Cpp::CodeGen
```

### 3. Analysis:
```
lib/aurora/analysis/ → lib/mlc/analysis/
  Aurora::Analysis::* → MLC::Analysis::*
```

### 4. Tests:
```
test/aurora/ → test/mlc/
  require 'aurora' → require 'mlc'
```

---

## Обратная совместимость:

Если нужно сохранить старый API:

```ruby
# lib/aurora.rb (deprecated wrapper)
require_relative 'mlc'

module Aurora
  # Deprecated: Use MLC instead
  def self.method_missing(method, *args, &block)
    warn "DEPRECATION WARNING: Aurora.#{method} is deprecated. Use MLC.#{method} instead."
    MLC.send(method, *args, &block)
  end
end
```

---

## Команды для автоматической замены:

### 1. Переименовать namespace в файлах:
```bash
# Замена module Aurora → module MLC
find lib -name "*.rb" -exec sed -i 's/module Aurora/module MLC/g' {} \;

# Замена Aurora:: → MLC::
find lib -name "*.rb" -exec sed -i 's/Aurora::/MLC::/g' {} \;

# То же для тестов
find test -name "*.rb" -exec sed -i 's/module Aurora/module MLC/g' {} \;
find test -name "*.rb" -exec sed -i 's/Aurora::/MLC::/g' {} \;
```

### 2. Переименовать директории:
```bash
# Основной модуль
git mv lib/aurora lib/mlc
git mv test/aurora test/mlc

# Core IR → High IR
git mv lib/mlc/core_ir lib/mlc/high_ir

# Backend → Target/Cpp
mkdir -p lib/mlc/target
git mv lib/mlc/backend lib/mlc/target/cpp

# IRGen → High IR Gen
git mv lib/mlc/irgen.rb lib/mlc/high_ir/generator.rb
```

### 3. Обновить require statements:
```bash
# lib/aurora → lib/mlc
find . -name "*.rb" -exec sed -i 's|require.*aurora/|require_relative "mlc/|g' {} \;
find . -name "*.rb" -exec sed -i 's|lib/aurora/|lib/mlc/|g' {} \;

# core_ir → high_ir
find . -name "*.rb" -exec sed -i 's/core_ir/high_ir/g' {} \;
find . -name "*.rb" -exec sed -i 's/CoreIR/HighIR/g' {} \;
```

---

## Проверка после миграции:

```bash
# Запустить все тесты
ruby -Ilib:test -e 'Dir["test/mlc/**/*_test.rb"].each { |f| require_relative f }'

# Должно быть:
# XXX runs, XXX assertions, 0 failures, 0 errors
```

---

## Timeline (оценка):

### Вариант 1: Быстрая миграция (1-2 часа)
```
1. ✅ Автоматическая замена (sed/find)
2. ✅ Переименовать директории (git mv)
3. ✅ Запустить тесты
4. ✅ Исправить ошибки
5. ✅ Commit
```

### Вариант 2: Постепенная миграция (несколько сессий)
```
Session 1: Namespace (Aurora → MLC)
Session 2: Directories (aurora/ → mlc/)
Session 3: IR renaming (CoreIR → HighIR)
Session 4: Backend → Target
Session 5: Documentation & Polish
```

---

## Risks & Mitigation:

### Risk 1: Сломать тесты
**Mitigation:**
- Делать в отдельной ветке
- Запускать тесты после каждого шага
- Использовать git для rollback при проблемах

### Risk 2: Потерять git history
**Mitigation:**
- Использовать `git mv` вместо `mv + rm`
- Делать маленькие коммиты с понятными сообщениями

### Risk 3: Забыть какие-то файлы
**Mitigation:**
- Использовать grep для поиска всех упоминаний "Aurora"
- Проверить все require/require_relative

---

## После миграции:

### Обновить README:
```markdown
# MLC - Multi-Level Compiler

Multi-level IR compiler framework with support for:
- High IR (semantic preservation)
- Mid IR (control flow)
- Low IR (SSA, optimizations)
- Multiple backends (C++, LLVM, WASM)

## Installation
gem install mlc-compiler

## Usage
mlc build app.aur
mlc --emit=high app.aur    # Show High IR
mlc --emit=mid app.aur     # Show Mid IR
mlc --emit=cpp app.aur     # Generate C++
```

### Создать CHANGELOG:
```markdown
# Changelog

## [0.2.0] - 2025-10-31

### Changed
- 🎉 **BREAKING**: Renamed project from Aurora to MLC (Multi-Level Compiler)
- Renamed `Aurora::` namespace to `MLC::`
- Renamed `CoreIR` to `HighIR` (more accurate naming)
- Restructured backends: `backend/` → `target/cpp/`

### Added
- Full Mid IR implementation with basic blocks
- LowerToMidPass for High IR → Mid IR transformation
- Mid IR printer for debugging

### Migration Guide
See docs/MLC_MIGRATION_PLAN.md
```

---

## Status: ⏸️ READY TO START

**Рекомендация:** Начать с Phase 1 (rename directory) и Phase 2 (namespace).

**Вопрос:** Начинаем миграцию сейчас или сохраняем для следующей сессии?

---

## Quick Start Commands:

Если решим начать прямо сейчас:

```bash
# 1. Create migration branch
git checkout -b migrate-to-mlc

# 2. Rename namespace in files (preview)
grep -r "module Aurora" lib/ | head -5

# 3. Rename with sed (PREVIEW first!)
# DON'T RUN YET - just preview
find lib -name "*.rb" | head -3 | xargs sed -n 's/module Aurora/module MLC/p'
```
