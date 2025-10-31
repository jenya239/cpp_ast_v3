# 📦 GitHub Repository Rename Guide

## Переименование репозитория cpp_ast_v3 → mlc

### 🎯 Цель
Переименовать GitHub репозиторий для соответствия новому названию проекта **MLC** (Multi-Level Compiler).

---

## 📋 Шаги по переименованию

### 1. Переименовать на GitHub

#### Через Web UI:
1. Открой репозиторий на GitHub
2. Перейди в **Settings** (настройки)
3. В разделе **General** найди **Repository name**
4. Измени `cpp_ast_v3` на `mlc`
5. Нажми **Rename**

#### Важно:
- ✅ GitHub автоматически создаст редиректы со старого URL
- ✅ Все issues, pull requests, ссылки будут работать
- ✅ Клоны будут продолжать работать (через redirect)

---

### 2. Обновить локальный remote

После переименования на GitHub обнови локальный remote URL:

```bash
# Проверь текущий remote
git remote -v

# Обнови origin URL
git remote set-url origin git@github.com:USERNAME/mlc.git

# Или для HTTPS:
git remote set-url origin https://github.com/USERNAME/mlc.git

# Проверь что обновилось
git remote -v
```

---

### 3. Рекомендуемые названия

#### Варианты для GitHub:

**Вариант 1 (Рекомендуем):**
```
mlc
```
- ✅ Короткое
- ✅ Техническое
- ✅ Запоминается

**Вариант 2:**
```
mlc-compiler
```
- ✅ Более понятное
- ⚠️ Длиннее

**Вариант 3:**
```
mlc-lang
```
- ✅ Указывает что это язык
- ⚠️ Может быть путаница с "language"

**Наша рекомендация:** Используй просто **`mlc`**

---

### 4. После переименования

#### 4.1 Обнови документацию

Обнови ссылки в:
- README.md (если есть badge'ы или ссылки)
- CONTRIBUTING.md
- .github/workflows/*.yml (если используешь GitHub Actions)

#### 4.2 Обнови package managers (если есть)

Если публикуешь gem:
```ruby
# mlc.gemspec
Gem::Specification.new do |spec|
  spec.name          = "mlc-compiler"
  spec.homepage      = "https://github.com/USERNAME/mlc"
  spec.metadata["source_code_uri"] = "https://github.com/USERNAME/mlc"
end
```

#### 4.3 Проверь CI/CD

Если используешь GitHub Actions или другие CI:
- Проверь что все workflow'ы запускаются
- Обнови любые хардкоженные URL

---

### 5. Дополнительные настройки (опционально)

#### 5.1 Обнови описание репозитория

**Description:**
```
MLC - Multi-Level Compiler. Modern language with multi-level IR architecture.
```

**Topics (tags):**
```
compiler
programming-language
mlc
multi-level-ir
cpp-codegen
static-typing
pattern-matching
```

#### 5.2 Обнови README badge'ы

Если есть CI badge:
```markdown
![CI](https://github.com/USERNAME/mlc/workflows/CI/badge.svg)
```

#### 5.3 Создай GitHub Pages (опционально)

Можешь создать `mlc-lang.github.io` или использовать `USERNAME.github.io/mlc`:

```bash
# В настройках репозитория → Pages
# Source: Deploy from a branch
# Branch: main / docs
```

---

## 🔄 Для других разработчиков

Если другие люди склонировали репозиторий, им нужно обновить URL:

```bash
# Автоматически обновить (работает благодаря GitHub redirect):
git pull

# Или вручную обновить remote:
git remote set-url origin git@github.com:USERNAME/mlc.git
```

---

## ⚠️ Что НЕ сломается

✅ **Работает автоматически:**
- Старые клоны (через GitHub redirect)
- Issues и Pull Requests
- Commit history
- Contributors
- Stars и Watchers
- Wiki (если есть)
- Releases

---

## 📝 Checklist после переименования

- [ ] Репозиторий переименован на GitHub
- [ ] Локальный remote обновлён
- [ ] README.md обновлён (если были ссылки)
- [ ] CI/CD проверен
- [ ] Описание репозитория обновлено
- [ ] Topics/tags обновлены
- [ ] Gem/package manager обновлён (если публикуешь)

---

## 🎉 Готово!

После выполнения всех шагов у тебя будет:

- 🔹 URL: `github.com/USERNAME/mlc`
- 🔹 Clone: `git clone git@github.com:USERNAME/mlc.git`
- 🔹 Единый бренд: **MLC**

Старые ссылки будут автоматически перенаправляться!
