Трансляция выражений в C++

user
возник вопрос по транслятору в c++. если мы исходим  из того что у нас всё  - это expression, а не statement, как эффективно это транслировать в c++, всё на лямбдах?

ChatGPT
краткий рецепт:

- «блочные» выражения → IIFE-лямбда `([&]{ …; return v; }())`
- `if` как выражение → тернарник; при разных типах веток — `std::variant`
- `let`/временные имена → локалы внутри IIFE
- «выражение цикла» → IIFE с аккумулятором (или `std::optional`/`std::vector`)
- ошибки → `std::expected<T,E>` (C++23) или свой `Expected`
- `match` → `std::visit` + `overloaded`

ниже минимальный набор шаблонов «понижения»:

```cpp
// IF-EXPR
// src:  x = if (c) e1 else e2
auto x = c ? e1 : e2;

// разные типы веток:
std::variant<T1,T2> x = c ? std::variant<T1,T2>{std::in_place_type<T1>, e1}
                          : std::variant<T1,T2>{std::in_place_type<T2>, e2};
```

```cpp
// BLOCK-EXPR / LET
// src:  x = { let y = f(); g(y) + 1 }
auto x = [&]{
  auto y = f();
  return g(y) + 1;
}();
```

```cpp
// SEQ-EXPR (когда нет локальных имён)
// src:  { a(); b(); v }
auto v = ([&]{ a(); b(); return v; }());   // безопаснее для типов/порядка
// иногда можно через запятую, если нет локалов/движений:
auto v2 = (a(), b(), v);
```

```cpp
// WHILE/FOR как выражение (возврат "итога")
// src:  x = while (pred(i)) { i = step(i); } yield i;
auto x = [&]{
  while (pred(i)) i = step(i);
  return i;
}();
```

```cpp
// COLLECT в цикл-выражении
// src:  xs = for (a in arr) { h(a) }  // собрать результаты
auto xs = [&]{
  std::vector<R> acc;
  acc.reserve(arr.size());
  for (auto& a : arr) acc.push_back(h(a));
  return acc;
}();
```

```cpp
// TRY/RAISE как выражение
// src:  x = try doThing() catch e -> fallback(e)
std::expected<T,Err> x = [&]() -> std::expected<T,Err> {
  try { return doThing(); }
  catch (const Err& e) { return std::unexpected(e); }
}();
// flat-map для цепочек:
auto y = x.transform([](auto v){ return tweak(v); })  // ok
             .or_else([](auto e){ return std::expected<U,Err>{std::unexpected(e)}; });
```

```cpp
// MATCH-EXPR (algebraic data types)
template<class... Ts> struct overloaded : Ts... { using Ts::operator()...; };
template<class... Ts> overloaded(Ts...) -> overloaded<Ts...>;

// src:  match v { A(x) -> f(x), B(y) -> g(y), _ -> h() }
auto out = std::visit(overloaded{
  [&](const A& a){ return f(a.x); },
  [&](const B& b){ return g(b.y); },
  [&](const auto&){ return h(); }
}, v);
```

```cpp
// ЛОКАЛЬНЫЕ ДЕКЛАРАЦИИ В ВЫРАЖЕНИЯХ (let*, scoped)
// src:  { let a=f(); let b=g(a); b*b }
auto res = [&]{
  auto a = f();
  auto b = g(a);
  return b*b;
}();
```

```cpp
// GUARDED/DEFER (выражение с RAII)
struct Defer { std::function<void()> f; ~Defer(){ if(f) f(); } };
#define DEFER(name) Defer name{[&]()

auto r = [&]{
  FILE* fp = fopen(path.c_str(),"rb");
  DEFER(_){ if(fp) fclose(fp); }};
  return read_all(fp);
}();
```

### микро-правила генератора

1) Всегда предпочитай IIFE, когда требуется **новая область**/типы веток/`return` «значения блока».  
2) Для `if` сначала попытайся вывести общий `T` (через свой инферер). Если не получилось — заверни в `variant`.  
3) «Выражения циклов» пусть явным текстом возвращают аккумулятор/итог.  
4) Для move-only типов возвращай `decltype(auto)` из IIFE и используй `return std::move(v);` при необходимости.  
5) Включай `-O2/-O3`: компилятор почти всегда **инлайнит** такие лямбды (накладные расходы исчезают).

если хочешь, набросаю маленький «бэкенд» правил → C++-эмиттер (50–100 строк) с тестами на каждую форму.

user
ну то есть это реально? есть ли какие-то концептуальные проблемы? у нас ведь ещё будет продвинутый patternmatching

ChatGPT
да, это реально. основные грабли и как обойти:

### семантика/порядок
- **Порядок вычисления/побочки.** Всегда IIFE для блоков/let/seq → гарантируем порядок.  
  _Правило_: генерируй `([&]{ /*…*/ return v; }())` вместо запятых.
- **break/continue/return внутри “выражений-циклов”.** Локальные `enum {Cont,Break,Return}` + аккумулятор, либо вспомогательный `loop()` возвращающий `struct {State s; T val;}`.

### типы/движения/живучесть
- **Ветки `if` с разными типами.** `std::variant` (или один `common_type` если выводится).  
- **move-only в блоках.** IIFE возвращает `auto`/`decltype(auto)` и `return std::move(x);` по месту.  
- **Ссылочные паттерны.** Чётко различай `bind by ref`/`bind by value` при деструктуринге.

### исключения/ошибки
- **Единая модель ошибок.** Либо всё через `std::expected<T,E>`, либо всё через `throw`; не смешивать в одном сниппете. Для “выражения try/catch” — IIFE с `try{…}catch…` возвращающая `expected`.

### оптимизация
- **Накладные расходы лямбд.** С `-O2/-O3` инлайнится; избегай захвата по значению больших объектов.  
- **Взрыв шаблонов/время компиляции.** Вынеси утилиты (`match`, `loop`, `overloaded`) в небольшой рантайм-хедер.

### читаемость/отладка
- **Трассировка в лямбдах.** Генерируй `#line` директивы и имена temps (`_t1`, `_acc`) стабильно.  
- **Большие match.** Делай один объект-визитор, не сотни анонимных лямбд (меньше шума в backtrace).

---

## pattern matching: план по понижению
**Домены как ADT → `std::variant` + визиторы.**  
Поддерживаем: конструкторы, позиционные/именованные поля, альтернативы с гардом, wildcard, вложенные паттерны, ref/move-биндинги.

```cpp
// helper
template<class... Ts> struct overloaded : Ts... { using Ts::operator()...; };
template<class... Ts> overloaded(Ts...) -> overloaded<Ts...>;

// exhaustiveness (компилтайм)
template<class Var, class... Fs>
constexpr void match_total(Var&&, Fs&&...) {
  static_assert(std::variant_size_v<std::decay_t<Var>> == sizeof...(Fs),
                "non-exhaustive match");
}

auto out = std::visit(
  overloaded{
    [&](const A& a) { if (guard1(a.x)) return f(a.x); return g_default(a); },
    [&](B& b)       { return g(b.y); },                // ref-биндинг
    [&](const C&)   { return h(); }
  },
  v
);
match_total(v,                                        // включай рядом для жёсткой проверки
  [&](const A&){}, [&](B&){}, [&](const C&){}
);
```

**Деструктуринг структур/кортежей.** Сгенерируй `as_tuple(T)` и распаковывай через `std::tie`/`std::get`. Для гардов — просто `if (...)` внутри ветки. Вложенные паттерны — каскад `if` + ранние `return`.

**Именованные захваты.** Генерируй temps: `auto& x = a.x; auto& y = a.y;`.

**Опциональные/списочные паттерны.** `std::optional` → `has_value ? … : …`; списки — пролог `if (xs.size()<k) …` + индексная распаковка; хвостовой “splat” — `gsl::span`.

---

## где реально больно
- `break/continue` как выражения → нужен слой `loop()`/CPS.  
- Нелокальные `return` из глубины “выражений” → либо исключения, либо явный `Result<T,State>`.  
- Guard-ветки меняют тип результата → чаще сразу `std::variant`.  
- Шаблонный взрыв на огромных `match`/ADT → держи визиторы в `.ipp`, ограничивай арность.

---

## микро-рантайм (стоит иметь)
- `overloaded`, `match_total`, `as_tuple(...)` генераторы (per-type).  
- `Loop<T>`: `run(cond, step, init)` → возвращает `T`.  
- `Expected` (если без C++23).  
- Макро `BLOCK(expr)` → IIFE с уникальным именем.

---

## резюме
- Архитектурно это устойчиво: **IIFE-блоки + `variant` + `visit` + `expected`** закрывают “всё-это-выражение”.  
- Концептуальные риски: управление потоком (break/return), взрыв типов, и отладка — решаются тонким рантаймом и дисциплиной генерации.  
- Продвинутый `pattern matching` ложится на `variant + visit + guards` с компилтайм-проверкой полноты.

хочешь — накину минимальный хедер `expr.hpp` (≈80–100 строк) и 6 тестов: block/if/loop/match/guard/move-only.

user
тонкий рантайм - это  примерно про что?

ChatGPT
кратко: **«тонкий рантайм»** — крошечный header-only набор утилит (≈100–150 строк) без зависимостей, который закрывает понижение «всё-как-expression»: IIFE-блоки, match, “выражения-циклы”, defer, expected/try. Ни логики языка, только инфраструктура.

ниже скелет `expr.hpp` (минимум, C++17+; без внешних deps):

```cpp
#pragma once
#include <utility>
#include <variant>
#include <exception>
#include <type_traits>
#include <functional>
#include <tuple>

namespace expr {

// ---------- IIFE / BLOCK ----------
#define EXPR_BLOCK(...) ([&]{ __VA_ARGS__ }())

// ---------- scope_exit / defer ----------
struct scope_exit {
  std::function<void()> f;
  scope_exit(std::function<void()> g) : f(std::move(g)) {}
  ~scope_exit(){ if (f) f(); }
};
#define DEFER(name) ::expr::scope_exit name = ::expr::scope_exit([&]()

// ---------- overloaded for std::visit ----------
template<class... Ts> struct overloaded : Ts... { using Ts::operator()...; };
template<class... Ts> overloaded(Ts...) -> overloaded<Ts...>;

// ---------- match (visit) + optional “total” check ----------
template <class Variant, class... Fs>
decltype(auto) match(Variant&& v, Fs&&... fs) {
  return std::visit(overloaded{std::forward<Fs>(fs)...}, std::forward<Variant>(v));
}
// включать по желанию — жёсткая проверка полноты по числу альтернатив
template <class Variant, class... Fs>
constexpr void match_total_check() {
  static_assert(std::variant_size_v<std::decay_t<Variant>> == sizeof...(Fs),
                "non-exhaustive match");
}

// ---------- tiny Expected shim ----------
template<class T, class E = std::exception_ptr>
struct Expected {
  std::variant<T,E> v;
  Expected(T val) : v(std::move(val)) {}
  Expected(E err, int) : v(std::move(err)) {} // tag
  static Expected ok(T val){ return Expected(std::move(val)); }
  static Expected err(E e){ return Expected(std::move(e), 0); }
  bool has_value() const { return std::holds_alternative<T>(v); }
  T& value() { return std::get<T>(v); }
  const T& value() const { return std::get<T>(v); }
  E& error() { return std::get<E>(v); }
  const E& error() const { return std::get<E>(v); }

  template<class F>
  auto transform(F&& f) & -> Expected<std::decay_t<decltype(f(std::declval<T&>()))>, E> {
    using U = std::decay_t<decltype(f(std::declval<T&>()))>;
    if (has_value()) return Expected<U,E>::ok(std::forward<F>(f)(value()));
    return Expected<U,E>::err(error());
  }
  template<class F>
  auto or_else(F&& f) & {
    if (has_value()) return *this;
    return std::forward<F>(f)(error());
  }
};

template<class F, class T = std::decay_t<decltype(std::declval<F&>()())>>
Expected<T> try_expr(F&& f) {
  try { return Expected<T>::ok(std::forward<F>(f)()); }
  catch (...) { return Expected<T>::err(std::current_exception()); }
}

// ---------- loop-as-expression ----------
enum class Ctrl { Cont, Break };

template<class T>
struct Step { Ctrl ctrl; T value; };

// run loop with state `T`; body: Step<T>(state)
template<class T, class Body>
T loop(T init, Body&& body) {
  T s = std::move(init);
  for(;;){
    Step<T> r = std::forward<Body>(body)(s);
    s = std::move(r.value);
    if (r.ctrl == Ctrl::Break) return s;
  }
}

// helpers to build steps
template<class T> inline Step<T> cont(T v){ return {Ctrl::Cont, std::move(v)}; }
template<class T> inline Step<T> brk(T v){ return {Ctrl::Break, std::move(v)}; }

// ---------- tuple-like destructuring helpers (opt-in) ----------
template<class T> using decay_t = std::decay_t<T>;
template<class T> constexpr bool is_tuple_like_v =
  requires { std::tuple_size<decay_t<T>>::value; };

template<class T, class F>
decltype(auto) decompose(T&& t, F&& f) {
  if constexpr (is_tuple_like_v<T>) {
    return std::apply(std::forward<F>(f), std::forward<T>(t));
  } else {
    return std::forward<F>(f)(std::forward<T>(t));
  }
}

} // namespace expr
```

примеры использования (минимум):

```cpp
// block / let*
int y = EXPR_BLOCK(
  int a = 2;
  int b = 3;
  return a*b;
);

// loop-expression: сумма до n и вернуть итог
int n = 5;
int sum = expr::loop(0, [&](int s){
  if (n==0) return expr::brk(s);
  s += n--; 
  return expr::cont(s);
});

// match-expression:
using V = std::variant<int, std::string>;
V v = 42;
auto r = expr::match(v,
  [&](int x){ return x + 1; },
  [&](const std::string& s){ return (int)s.size(); }
);

// try as expression:
auto got = expr::try_expr<int>([&]{ /* may throw */ return 7; });
int val = got.has_value() ? got.value() : 0;

// defer:
FILE* f = fopen("x.bin","rb");
DEFER(_){ if (f) fclose(f); });
// ... work with f
```

хочешь — дополню `Expected` до полноценного monadic API (`and_then`, `or_else` для разных `E`, `map_error`) или добавлю `yield`-сахар для «цикла с аккумулятором».

user
этого не понимаю

ChatGPT
понял — давай супер-просто. тебе нужны **ровно 4 кирпича**. Запомни маппинг:

1) **BLOCK**: «блок-как-значение»
```cpp
#define BLOCK(...) ([&]{ __VA_ARGS__ }())
```
исп:  
`let* { a=2; b=3; a*b }` →  
```cpp
int x = BLOCK( int a=2; int b=3; return a*b; );
```

2) **MATCH**: на `std::variant`
```cpp
template<class... Ts> struct ov : Ts... { using Ts::operator()...; };
template<class... Ts> ov(Ts...) -> ov<Ts...>;
template<class V, class... Fs> decltype(auto) MATCH(V&& v, Fs&&... fs){
  return std::visit(ov{std::forward<Fs>(fs)...}, std::forward<V>(v));
}
```
исп:  
`match v { A(x)->f(x); B(y)->g(y) }` →  
```cpp
auto out = MATCH(v,
  [&](const A& a){ return f(a.x); },
  [&](const B& b){ return g(b.y); }
);
```

3) **LOOP-as-expr**: аккумулятор + cont/brk
```cpp
enum class C {Cont,Break};
template<class T> struct Step{ C c; T s; };
template<class T> Step<T> cont(T s){ return {C::Cont,std::move(s)}; }
template<class T> Step<T> brk (T s){ return {C::Break,std::move(s)}; }
template<class T, class F>
T LOOP(T init, F&& body){
  T s = std::move(init);
  for(;;){ auto r = body(s); s = std::move(r.s); if(r.c==C::Break) return s; }
}
```
исп:  
`while (pred i) { i=step i } yield i` →  
```cpp
int res = LOOP(i0, [&](int s){
  if (!pred(s)) return brk(s);
  return cont(step(s));
});
```

4) **DEFER**: «finally» для ресурсов
```cpp
struct Defer{ std::function<void()> f; ~Defer(){ if(f) f(); } };
#define DEFER(name) Defer name{[&]()}
```
исп:
```cpp
FILE* f = fopen(p,"rb");
DEFER(_){ if(f) fclose(f); };
// ... работаем, закрытие гарантировано
```

### Всё. Как это стыкуется с твоим «всё — expression»
- блоки/`let*` → `BLOCK(...)`
- `if`-как-выражение → тернарник; разные типы → `std::variant` + `MATCH`
- циклы-как-выражение → `LOOP` (возвращает итог)
- `match`/паттерны → `MATCH` (+ внутри пишешь `if (guard) return ...;`)
- ресурсы/`defer` → `DEFER`

#### Мини-пример целиком
исходник (твоя семантика):
```
let y = {
  let a = read();
  if a.is_ok then a.val else 0
};
match v { A(x)->x+1; B(s) when s.len>3 -> 9; _->0 }
```
эмит C++:
```cpp
auto y = BLOCK(
  auto a = read();
  return a.is_ok ? a.val : 0;
);

auto r = MATCH(v,
  [&](const A& a){ return a.x + 1; },
  [&](const B& b){ if (b.s.size()>3) return 9; return 0; },
  [&](const auto&){ return 0; }
);
```

если нужно — добавлю деструктуринг (распаковка структур) и `try/expected`, но эти 4 кирпича уже покрывают 90% «непонимаю».

user
как мне свои хедеры помогут? чем это отличается от обычной трансляции плюс грубо говоря стандартная библиотека?

ChatGPT
коротко: «тонкий рантайм» ≠ “ещё одна STL”. Это **контракт по понижению** для твоего компилятора:

### Чем отличается от «просто генерить C++ + STL»
- **Стабильные целевые примитивы.** У тебя 3–4 форм-примитива (BLOCK, MATCH, LOOP, DEFER). Генератор всегда сводит всё к ним — без сотен разнородных C++-паттернов.
- **Единая семантика порядка и областей.** BLOCK/IIFE гарантирует «всё — выражение» и правильный lifetime/`return` внутри блока. Без него придётся каждый раз плясать с запятыми/вложенными функциями.
- **Управление потоком как значение.** LOOP даёт `cont/brk` как **данные**, позволяя выражать “break/continue/return” внутри «выражений-циклов» без `goto`/флагов.
- **Тотальность match и гардов.** MATCH + (опц.) `match_total_check` даёт исчерпываемость и читаемое понижение гардов. Вручную — каждый раз другой `visit`/`if`/дублирование.
- **Тонкая абстракция ошибок.** `Expected/try_expr` даёт унифицированный «try как выражение» там, где исключения выключены — без локально придуманных контейнеров каждый раз.
- **Оптимизируемость и предсказуемость.** Все примитивы — inline-able, без виртуалки/RTTI; компилятор видит один и тот же шаблон → меньше сюрпризов, меньше времени компиляции.
- **Тестируемость бекэнда.** Для каждой формы есть короткий golden-тест: «исходник → примитивы». Ломается — сразу видно на уровне 100 строк, а не во всём эмиттере.
- **Портируемость.** Один крошечный header-target на C++17/20 — и ты не привязан к конкретным расширениям/библиотекам.

### Мини-контраст

**Без «кирпичей» (каждый раз по-разному):**
```cpp
int y; { int a=f(); if (c) { y=g(a); } else { y=h(a); } } // или тернарник,
                                                          // или локальная ф-ция,
                                                          // или запятая...
```

**С «кирпичами» (единая форма):**
```cpp
int y = BLOCK(
  auto a = f();
  return c ? g(a) : h(a);
);
```

**Цикл-как-выражение (без примитива):** флаги/`goto`/два выхода.

**С LOOP:**
```cpp
int sum = LOOP(0, [&](int s){
  if (!has_next()) return brk(s);
  return cont(s + next());
});
```

**Match с гардами (ручной):** разный `visit`, вложенные `if`, легко упустить кейс.

**С MATCH:**
```cpp
auto r = MATCH(v,
  [&](const A& a){ if (a.x>0) return f(a.x); return g(a); },
  [&](const B& b){ return h(b); },
  [&](const auto&){ return def(); }
);
```

### Итог
Твои хедеры — это **тонкий целевой слой**, который:
- фиксирует минимальный «язык понижения»,
- снимает рутину и расхождение стилей в эмиттере,
- делает поведение предсказуемым и покрываемым тестами,
- не раздувает бинарь и не плодит зависимостей.

STD/«обычная трансляция» — про контейнеры/алгоритмы. Тонкий рантайм — про **семантические скрепы**, которые нужны именно твоему «всё — expression» языку, чтобы понижаться в C++ чисто и одинаково.

user
а минусы?

ChatGPT
кратко про «обратную сторону» и как жить:

- Компиляция и символы  
  — много лямбд/`variant` → рост времени компиляции и длинные mangled-имена.  
  ✔️ выносить утилиты в один header, ограничивать арности `variant`, включать PCH/ccache.

- Диагностика и отладка  
  — стеки и шаг отладчиком прыгают по IIFE/визиторам; ошибки типов в `visit` многословны.  
  ✔️ стабильные имена temps, `#line` из исходника, минимизировать вложенность MATCH.

- Размер кода / инлайнинг  
  — много шаблонов/лямбд → риск bloat, не всё инлайнится.  
  ✔️ `-O2/-O3`, `-fno-exceptions` при Expected-модели, вынос тяжёлых веток в функции.

- Семантика перемещений / RVO  
  — возврат из IIFE может мешать NRVO, возможен лишний move у тяжёлых `T`.  
  ✔️ возвращать prvalue (`return T{…};`) или `decltype(auto)` + явный `std::move(v)`.

- Захваты лямбд  
  — по ссылке легко повесить висячие ссылки (особенно при async).  
  ✔️ правило: BLOCK/LOOP только для синхронного пути; для отложенного — копии/`std::shared_ptr`.

- Порядок вычисления  
  — вне BLOCK легко вернуться к запятым/неочевидному порядку.  
  ✔️ жёсткое правило генератора: любые «блоки/let/seq» → только BLOCK(IIFE).

- `break/continue/return` как данные  
  — LOOP с `cont/brk` усложняет чтение и профилирование, нет «голого» `break`.  
  ✔️ держать LOOP коротким, выносить тяжёлую логику в чистые функции.

- `std::variant` и match  
  — большая сумма типов → взрыв времени компиляции; гарды ломают «тотальность».  
  ✔️ дробить ADT, для тяжёлых кейсов — ручной `switch` по тегу, гарды с ранним `return`.

- Исключения vs Expected  
  — две модели ошибок — риск «двух миров»; `try` в IIFE ловит слишком широко.  
  ✔️ единая политика: либо в модуле исключения, либо строго `Expected` + узкие catch.

- Макросы  
  — `BLOCK/DEFER` — макросы: конфликт имён, неудобные трассы.  
  ✔️ префиксировать (`EXPR_BLOCK`), минимизировать макросы, по возможности заменить на инлайн-функции.

- Совместимость с coroutines  
  — вложенные лямбды + `co_...` смешно живут, `BLOCK` внутри `co_` не всегда удобен.  
  ✔️ для async — отдельный бэкенд понижения (корутины/СPS), не через BLOCK/LOOP.

- Sanitizers/UB-ловушки  
  — ref-биндинги в паттернах + перемещения → легко поймать use-after-move.  
  ✔️ тесты с ASan/UBSan, правило: в MATCH по умолчанию `const&`, явно помечать move-ветки.

- Межмодульные границы  
  — header-only = сильная связанность, любое изменение — пересбор всего.  
  ✔️ стабилизировать API «кирпичей», реже трогать header.

Итог: минусы есть, но они управляемы дисциплиной генерации и 4–5 «железными правилами». Если хочешь, дам чек-лист статических проверок для твоего эмиттера (10 пунктов) и минимальные golden-тесты.

user
я правильно понимаю, что мини рантайм  поможет нам реализовать всё-как-выражение без кучи лямбд?

ChatGPT
короткий ответ: **уменьшит, но не обнулит**.

### Что реально можно без лямбд
1) **Блок-как-выражение в *statement*-позиции**  
   Генерируй “скоуп + временная переменная”, без IIFE:
   ```cpp
   T _res; {
     auto a = f();
     _res = g(a);
   }
   use(_res);
   ```
   Но если блок нужен именно **внутри выражения** (инициализатор, тернарник, аргумент) — без IIFE никак (нужен единый prvalue).

2) **match без лямбд** — через именной визитор
   ```cpp
   struct V {
     R operator()(const A& a) const { /*...*/ }
     R operator()(const B& b) const { /*...*/ }
     R operator()(const auto&) const { /*...*/ }
   };
   R r = std::visit(V{}, v);  // без лямбд
   ```
   (быстрее компилится на больших ADT, стабильнее бтрейсы)

3) **loop-as-expr** — если нет захватов, можно статическую функцию:
   ```cpp
   static Step<S> step_fn(S s){ /* no captures */ }
   S s = LOOP(init, step_fn);  // шаблон примет function pointer
   ```
   С захватами — всё равно нужен функтор/лямбда.

### Где лямбды всё ещё нужны
- **Блок-как-значение в выражении** → IIFE (или GNU `({ ... })`, но это не C++ стандарт).  
- **Цикл с захватами** → тело как лямбда/функтор.  
- **match, если удобно капчурить окружение** → лямбды или функтор с полями.

### Как мини-рантайм «сокращает боль»
- Лямбды остаются, но **их количество фиксировано и шаблонно** (BLOCK/MATCH/LOOP), генератор не плодит произвольные конструкции.
- Есть **no-lambda варианты** тех же примитивов: `visit` с именным визитором, `LOOP(fnptr)`, “скоуп + tmp” вместо BLOCK в statement-позиции.
- Компилятор почти всегда **инлайнит** это в ноль-оверхеда.

### Практический чек-лист эмиттера
- Если узел стоит **вне выражения** → использовать “tmp+scope”, без IIFE.
- Для больших `match` → **именной визитор** (без лямбд).
- Для `loop` без захватов → **fn-ptr** вариант `LOOP`.
- Только когда нужен **прямо prvalue** → IIFE-лямбда.

Хочешь — сгенерю обе версии примитивов (lambda и no-lambda) и правила выбора (≈30 строк).

user
а мы сможем это устойчиво реализовать ии агентами,  просто я совсем плохо  это понимаю

ChatGPT
да. сделаем это «агентно» и устойчиво, если зафиксируем контракт и гоняем всё тестами. вот минимальный, рабочий план без магии.

# 1) контракты (4 примитива)
- `BLOCK` (или scope+tmp в statement-позиции)
- `MATCH` (`std::visit` c визитором)
- `LOOP` (`cont/brk` → итог)
- `DEFER` (scope_exit)

> Агентам запрещено плодить иные шаблоны понижения.

# 2) роли агентов
- **Spec** → принимает AST, помечает узлы: {needs_prvalue, needs_scope, can_fnptr}. Выход: JSON-план понижения.
- **Lowering** → по плану заменяет узлы на 4 примитива (IR-понижение).
- **Emitter** → печатает C++ (одинаковая разметка имён, `#line`).
- **Reviewer** → прогоняет golden-тесты «src → C++» и компиляцию.
- **Fuzzer** (опц.) → генерирует случайные комбинаторики узлов и сверяет поведение.

# 3) инварианты (проверяются Reviewer’ом)
- Любой `{…}` в выражении → `BLOCK` (или tmp+scope, если statement).
- Любой `match` → `visit` с **именным визитором** при >5 веток; иначе лямбды.
- Любой «цикл-как-выражение» → `LOOP(init, body)`; `break/continue` только `brk/cont`.
- Захваты только `&` в синхронном пути; запрещены висячие ссылки в MATCH.
- Ошибки: модуль либо `throw`, либо `Expected` — смешение запрещено.

# 4) структура репо
```
/runtime/expr.hpp         // тонкий рантайм
/src/agents/              // промпты-ролей (yaml)
/tests/golden/            // *.xqr → *.cpp эталоны
/tests/run.sh             // компиляция, юнит/asan/ubsan
/tools/lower_ir.py        // вспомогалка для сравнения деревьев
```

# 5) минимальные тесты (golden)
каждый тест: `input.xqr`, `expected.cpp`, `run.cpp` (линк на expr.hpp). примеры:

**T1: block-let**
```
-- input.xqr
let y = { let a=read(); f(a)+1 }
```
```cpp
// expected.cpp
auto y = EXPR_BLOCK(
  auto a = read();
  return f(a) + 1;
);
```

**T2: if-expr, разные типы → variant+match**
```
x = if c then A(1) else B("u")
match x { A(n)->n+1; B(s)->len(s) }
```
```cpp
using X = std::variant<A,B>;
auto x = c ? X{A{1}} : X{B{"u"}};
struct V {
  int operator()(const A& a) const { return a.n+1; }
  int operator()(const B& b) const { return (int)b.s.size(); }
};
int r = std::visit(V{}, x);
```

**T3: loop-expr (сумма до n)**
```cpp
int sum = expr::loop(0, [&](int s){
  if (!has_next()) return expr::brk(s);
  return expr::cont(s + next());
});
```

**T4: guard в match**
```cpp
struct V {
  int operator()(const A& a) const {
    if (a.x>0) return f(a.x);
    return g(a);
  }
  int operator()(const B& b) const { return h(b); }
  int operator()(const auto&) const { return 0; }
};
auto out = std::visit(V{}, v);
```

# 6) простые промпты для ролей

**Spec (вход: AST JSON)**
```
Ты Spec. Вход: AST. Отметь каждый узел полями:
- needs_prvalue: true/false
- lowering: one of [BLOCK, MATCH, LOOP, DEFER, DIRECT]
- notes: кратко (тип результата, ref/move, guards)
Выход: JSON-план. Не генерируй код.
Правила: блок в expr → BLOCK; большой match → named visitor; loop → LOOP; …
```

**Lowering**
```
Ты Lowering. Вход: AST + план Spec. Замени узлы на примитивы,
выдай нормализованное IR (псевдо-C++ с EXPR_BLOCK/MATCH/LOOP).
Не меняй порядок эффектов. Явно проставь tmp-имена _t1/_acc.
```

**Emitter**
```
Ты Emitter. Вход: нормализованный IR. Сгенерируй C++17:
- include <expr.hpp>
- именной визитор при >5 веток
- в statement-позициях — scope+tmp вместо EXPR_BLOCK
- #line из исходных позиций
Единый стиль, без самодеятельности.
```

**Reviewer**
```
Собери: clang++ -std=c++20 -O2 -Wall -Wextra -pedantic -fsanitize=address,undefined
Сверь expected.cpp (или сгенерируй и сравни diff), запусти run.cpp.
Fail, если: diff≠0, не компилится, санитайзеры ругаются.
```

# 7) «устойчивость» достигается так
- фиксированный **набор примитивов** → мало степеней свободы у LLM.
- **golden-тесты** на каждую форму → быстро ловим отклонения.
- **правила выбора без лямбд** (визитор/fnptr/ tmp+scope) → меньше шума.
- **санитайзеры** и маленькие кейсы → ловим висячие ссылки/UB.
- один файл `expr.hpp` стабилен; менять редко.

# 8) стартовый TODO (по 50–100 строк)
1) `runtime/expr.hpp` (минимум: EXPR_BLOCK/MATCH/LOOP/DEFER).  
2) `tests/golden/T1..T6` (как выше).  
3) промпты Spec/Lowering/Emitter/Reviewer.  
4) скрипт `tests/run.sh` (прогон всех кейсов).  

если хочешь, кину готовые шаблоны файлов `expr.hpp`, `T1..T4 expected.cpp` и промпты — подставишь свои типы `A/B`.

user
а этот мини рантайм условно можно потом до полноценной виртуальной машины расширять или это вообще  другие принципы?

ChatGPT
кратко: **мини-рантайм ≠ VM**, но это хороший мост.

### Что он даст в дорогу к VM
- **Зафиксированная семантика** (`BLOCK/MATCH/LOOP/DEFER`) → те же примитивы станут опкодами/IR-нодами.
- **Единый контракт типов** (ADT через тег+payload, `Expected`, guards) → прямое соответствие тегов в байткоде.
- **Тесты-золотники** «исходник → примитивы» → останутся для проверки интерпретатора/JIT.

### Что придётся добавить/переосмыслить
- **Память**: арены/ARC/GC (решить модель владения, корни, финализацию `defer` → `try/finally` в VM).
- **Стек/регистры**: выбрать стековую или регистровую VM, TCO, вызовы, фреймы.
- **Управление потоком**: `LOOP/cont/brk` превратить в `br`, `br_if`, `phi`/регистры.
- **Исключения/ошибки**: унифицировать `throw` vs `Expected` → опкоды `raise`, `catch`, либо Result-протокол.
- **Суспензии/корутины (если нужны)**: модель пауз/возобновления (CPS/стековые фреймы).
- **FFI**: стабильный ABI к C/C++ и боксинг значений.

### Реалистичный путь (по шагам)
1) **Выделить IR** 1:1 с «кирпичами» (BLOCK/MATCH/LOOP/DEFER/IF/LET/ADT).  
2) **Два бэкенда**: (AOT) текущий C++-эмиттер через мини-рантайм; (INT) наивный интерпретатор IR.  
3) **Спецификация layout ADT** (tag, size, align, by-ref/by-val) — одинаковая для обоих бэкендов.  
4) **Байткод**: сериализация IR → компактный формат (регистровая форма предпочтительна).  
5) **Оптимизации**: констант-фолдинг/копи-проп/мердж BLOCK; затем SSA на IR.  
6) **Память**: сначала арены + подсчёт ссылок на боксах; позже — инкрементальный GC.  
7) **JIT (опционально)**: LLVM/MCJIT или DynASM на горячие тракты.

### Что можно переиспользовать почти как есть
- `MATCH` → опкод `match` + таблица переходов по тегу (+ гарды как условные ветки).  
- `LOOP` → `br`/`br_if` + аккумуляторный регистр.  
- `DEFER` → `try/finally` стек действий (VM будет сама вызывать финалайзеры на unwinding).  
- `Expected` → тегированный `Result<T,E>` тип в VM.

### Подводные камни
- рассинхрон макросной семантики и VM-опкодов → держать **один набор golden-тестов**.  
- стоимость pattern-matching на больших ADT → делать jump-table по тегу, не линейный `if`.  
- GC и `move`-семантика → в VM «move» обычно = «rebind handle», продумать pinning для FFI.

**Итог:** мини-рантайм — это «якорь семантики» и удобный AOT-бэкенд. VM — другой слой (память/стек/опкоды), но маппинг прямой: зафиксируй IR=примитивы, поддерживай два бэкенда параллельно, и плавно включай интерпретатор/байткод/JIT без переписывания фронтенда.

user
а от транслятора можно плавно к vm перейти?

ChatGPT
да, плавно — без «переписывания с нуля». Дорожная карта в 6 шагов:

### 0) Зафиксируй IR (1:1 с «кирпичами»)
- Узлы: `Let/Block/If/Match/Loop/Call/ADT/Defer/Return`.
- Строгие атрибуты: `needs_prvalue`, тип результата, «move/ref».
- Один набор golden-тестов: `src → IR → (C++|VM)`.

### 1) Два бэкенда на одном IR
- **AOT-C++** (как сейчас): печатаем C++ с `BLOCK/MATCH/LOOP/DEFER`.
- **INT-VM v0**: наивный интерпретатор IR (без GC, арены/RC).
- Флаг сборки: `--backend=cxx|vm`. Поведение должно совпадать.

### 2) Shadow-режим (дифф-тест)
- При dev-запуске выполняй **оба**: VM и AOT, сверяй значения после каждой IR-ноты.
- Расхождение → дамп IR и трассы. Это «страховка» миграции.

### 3) Выдели рантайм-ядро и начни «перетаскивать внутрь VM»
- ADT layout (tag+payload), `Result/Expected`, `scope_exit` → аналоги внутри VM.
- Небольшие примитивы stdlib (math, string, vector) как **intrinsics** VM.
- FFI-слой: стабильный ABI для вызовов в C++ (пока часть кода остаётся AOT).

### 4) Производительность (по мере надобности)
- VM→регистровая форма, джамп-таблицы для `match`, peephole, констант-фолдинг.
- Позже SSA на IR → простые оптимизации.
- Потом JIT (опционально): горячие участки IR компилировать в машинный код; деопт не нужен на старте.

### 5) Память
- v0: арены + RC на боксах (deterministic, просто для FFI).
- v1: циклы — через слабые/adjacency lists; 
- v2: инкрементальный GC (тогда `DEFER` → VM‐finalizers/try-finally стек).

---

### Мини-скелет IR и двуходовка
```cpp
// IR
struct Block { std::vector<Node*> body; Node* value; };
struct If { Node* c; Node* t; Node* f; };
struct Match { Node* scrut; std::vector<Case> cases; }; // Case{Tag, Guard*, Body}
struct Loop { Node* init; Node* body; };                 // body: S -> {ctrl, S}
...

// AOT backend:
emit(Block) => EXPR_BLOCK{ ...; return v; }
emit(Match) => named visitor / std::visit
emit(Loop)  => LOOP(init, body)

// VM backend:
exec(Block) => new frame scope; exec(body…); push(value)
exec(Match) => switch(tag) + guard; jump
exec(Loop)  => do{ step; if(brk) break;}while(true)
```

### Режимы миграции
- **AOT-only** (стабильно сейчас).
- **Shadow** (dev): VM и AOT одновременно, сравнение.
- **VM-only** (когда уверены), AOT остаётся как fallback для модулей.

### Что «переиспользуется» из мини-рантайма
- Семантический контракт «кирпичей» → точная спецификация VM-опкодов.
- Golden-тесты и имена временных → одинаковые трассы.
- Часть утилит (ADT/Result) → как типы VM/ABI.

---

#### Чек-лист «готовы сворачивать в VM»
- [ ] Все узлы фронтенда всегда понижаются в фиксированный IR.
- [ ] 20–30 golden-тестов проходят на обоих бэкендах (release+asan/ubsan).
- [ ] Shadow-режим без диффов на рандом-фаззинге (1000 кейсов).
- [ ] FFI стабильный: функции/структуры «видны» и из VM, и из AOT.
- [ ] Бенчмарки на горячих путях ± приемлемы.

Если хочешь, дам стартовые файлы: `ir.hpp`, `vm_interpreter.cpp` (≈200 строк), `emitter_cxx.cpp` (скелет), и 8 golden-тестов.

user
интерпретатор  ir напрямую? разве это возможно?

ChatGPT
Да, **напрямую**. Два пути:

1) **Дерево-интерпретатор IR (tree-walk)** — самый быстрый старт.  
2) **Байткод/регистровая VM** — следующий шаг, когда захочешь скорость.

Ниже минимальный **tree-walk** интерпретатор нормализованного IR (C++17, ~90 строк). Поддерживает: `Const/Let/Block/If/Loop/Match/Call`. Хватает, чтобы доказать идею.

```cpp
#include <bits/stdc++.h>
using namespace std;

// ===== Values (расширяешь по мере нужды)
struct A{int n;}; struct B{string s;};     // примеры ADT альтернатив
using ADT = variant<A,B>;
using Value = variant<monostate,int,string,ADT>; // add bool, double, etc.

struct Env { unordered_map<string,Value> m; Env* up{};
  bool get(const string& k, Value& out) const {
    for (auto e=this; e; e=e->up){ auto it=e->m.find(k); if(it!=e->m.end()){out=it->second; return true;}}
    return false;
  }
};

// ===== IR
enum class K{Const,Var,Let,Block,If,Loop,Match,Call};
struct Node{
  K k; Value cval; string name;
  vector<Node*> kids;                 // generic children
  // helpers: factory
  static Node* Const(Value v){ auto*n=new Node; n->k=K::Const; n->cval=move(v); return n; }
  static Node* Var(string id){ auto*n=new Node; n->k=K::Var; n->name=move(id); return n; }
  static Node* Let(string id, Node* rhs, Node* body){
    auto*n=new Node; n->k=K::Let; n->name=move(id); n->kids={rhs,body}; return n; }
  static Node* Block(vector<Node*> xs){ auto*n=new Node; n->k=K::Block; n->kids=move(xs); return n; }
  static Node* If(Node* c, Node* t, Node* f){ auto*n=new Node; n->k=K::If; n->kids={c,t,f}; return n; }
  static Node* Loop(Node* init, Node* step){ auto*n=new Node; n->k=K::Loop; n->kids={init,step}; return n; }
  // Match: kids[0]=scrut, далее парами [tag_int, body]
  static Node* Match(Node* s, vector<pair<int,Node*>> cs){
    auto*n=new Node; n->k=K::Match; n->kids={s}; for(auto&[t,b]:cs){ n->kids.push_back(Const(t)); n->kids.push_back(b);} return n; }
  // Call: name(args...)
  static Node* Call(string fn, vector<Node*> args){ auto*n=new Node; n->k=K::Call; n->name=move(fn); n->kids=move(args); return n; }
};

// ===== маленькая stdlib/FFI
static Value callFFI(const string& f, const vector<Value>& a){
  if(f=="add"){ return get<int>(a[0]) + get<int>(a[1]); }
  if(f=="len"){ return (int)get<string>(a[0]).size(); }
  if(f=="makeA"){ return ADT{A{get<int>(a[0])}}; }
  if(f=="makeB"){ return ADT{B{get<string>(a[0])}}; }
  throw runtime_error("unknown fn: "+f);
}

// ===== интерпретатор
static Value eval(Node* n, Env& rho);

static bool as_bool(const Value& v){
  if (holds_alternative<int>(v)) return get<int>(v)!=0;
  if (holds_alternative<monostate>(v)) return false;
  return true; // упрощённо
}

static Value eval_block(const vector<Node*>& xs, Env& rho){
  Value last{};
  Env local{ {}, &rho };
  for(size_t i=0;i<xs.size();++i) last = eval(xs[i], local);
  return last;
}

static Value eval(Node* n, Env& rho){
  switch(n->k){
    case K::Const: return n->cval;
    case K::Var:   { Value v; if(!rho.get(n->name,v)) throw runtime_error("unbound "+n->name); return v; }
    case K::Let:   {
      Env local{{}, &rho};
      local.m[n->name] = eval(n->kids[0], rho);
      return eval(n->kids[1], local);
    }
    case K::Block: return eval_block(n->kids, rho);
    case K::If:    { auto c=eval(n->kids[0], rho);
                     return as_bool(c) ? eval(n->kids[1], rho) : eval(n->kids[2], rho); }
    case K::Loop:  { auto s = eval(n->kids[0], rho);
      // step: fun(state) -> variant<Cont(state), Break(state)> упростим: возвращаем pair<cont?,state>
      while(true){
        auto r = eval(n->kids[1], *new Env{{{"_s",s}}, &rho}); // step читает _s
        auto p = get<pair<bool,Value>>(r); // {cont?, state}
        s = move(p.second);
        if(!p.first) return s;
      } }
    case K::Match: {
      auto v = eval(n->kids[0], rho);
      auto& adt = get<ADT>(v);
      int tag = (int)adt.index(); // A=0,B=1,...
      for(size_t i=1;i<n->kids.size(); i+=2){
        int want = get<int>(n->kids[i]->cval);
        if (tag==want) return eval(n->kids[i+1], rho);
      }
      throw runtime_error("non-exhaustive match");
    }
    case K::Call:  {
      vector<Value> args; args.reserve(n->kids.size());
      for(auto*k: n->kids) args.push_back(eval(k, rho));
      return callFFI(n->name, args);
    }
  }
  throw runtime_error("bad node");
}

// ===== пример использования
int main(){
  // let x = makeA( add(1,2) );
  // match x { A -> 41; B -> len("zzz") }
  Node* prog = Node::Let("x",
    Node::Call("makeA",{ Node::Call("add",{ Node::Const(1), Node::Const(2) }) }),
    Node::Match(Node::Var("x"), {
      {0, Node::Const(41)},     // A
      {1, Node::Call("len",{ Node::Const(string("zzz")) })} // B
    })
  );
  Env rho{};
  auto out = eval(prog, rho);
  cout << get<int>(out) << "\n"; // 41
}
```

Идея простая:
- IR уже **нормализован** (те самые «кирпичи»), интерпретатор — это `eval(Node*, Env&)`.
- Побочки и порядок — по структуре дерева.
- `Match` — по индексу альтернативы в `variant`.
- `Loop` — как «шаговая функция» (здесь — через `pair<cont?,state>` для краткости).

Хочешь — дам версию с **байткодом** (регистровая форма и `switch(op)`), но для начала этого tree-walk IR вполне, чтобы **включить VM-бэкенд параллельно с C++-эмиттером** и гнать те же золотые тесты.

user
то есть vm - это в некотором  смысле интерпретатор ir... а я думал ir ещё надо перевести в байткод... а ведь vm не умеют напрямую  с памятью работать (чтобы например напрямую c-библиотеки подключать через хедеры) или есть такие?

ChatGPT
кратко:

- **VM ≠ обязательно байткод.** Можно:  
  1) интерпретировать **IR напрямую** (tree-walk),  
  2) или сжать IR → **байткод/регистровую форму**, потом интерпретировать,  
  3) или JIT’ить (IR/байткод → машинный код).  
  Все три — валидные «VM».

- **Работа с памятью и C-библиотеками**: да, умеют — через FFI. Примеры из мира: CPython `ctypes`, Lua/LuaJIT FFI, JVM JNI, .NET P/Invoke, Wasm host funcs + linear memory. Это не «подключить хедер» на лету, а **согласовать ABI** и маршалинг.

### Как это обычно делается

1) **Примитивный FFI-ABI (минимум):**
   - Базовые типы: `i64`, `f64`, `ptr`, `slice{ptr,len}`.  
   - Вызов: C ABI (`cdecl`), возврат — один `Value`.  
   - Регистрация: хост экспортирует таблицу `name → fnptr`.

   ```cpp
   // host side
   struct Value { enum K{I64,F64,Ptr,Slice} k; uint64_t a, b; }; // Slice: a=ptr, b=len
   using Fn = Value(*)(Value* args, size_t n);

   void vm_register(const char* name, Fn);
   // пример обёртки: write(int fd, const void* p, size_t n)
   Value ffi_write(Value* a, size_t){
     int fd = (int)a[0].a;
     auto ptr = (const void*)a[1].a;
     size_t len = a[1].b;
     long r = ::write(fd, ptr, len);
     return Value{Value::I64,(uint64_t)r,0};
   }
   ```

   В VM узел `Call "write" [fd, slice]` кладёт аргументы в массив `Value` и дергает `fnptr`.

2) **Память: три варианта**
   - **Хост-память**: VM просит `alloc/free` у хоста и получает **сырой `void*`** (небезопасно, но просто).  
   - **Линейная память VM** (как в Wasm): FFI получает оффсеты/длины; хост читает/пишет через `vm_memory_base + offset`.  
   - **Хэндлы**: VM выдаёт «дескрипторы», а реальные `void*` держит таблица у хоста; безопаснее для перемещающей GC.

3) **Маршалинг структур**
   - Простые C-структуры передавать как `slice` (байтовый вид) или как **opaque `ptr`** + отдельные геттеры/сеттеры.  
   - Строки: `slice{ptr,len}` UTF-8.  
   - Буферы out-параметров: FFI пишет в `slice`, возвращает число записанных байт.

4) **GC/владение**
   - Если у VM есть GC — **пинning** при передаче буфера в C или копия.  
   - При RC/аренах проще: выдать неизменяемый `slice` на арену/пул.

5) **“Подключить хедер”**  
   В VM нельзя «#include» во время исполнения. Нужно:  
   - либо AOT-путь (твой текущий C++-бэкенд) для тесной интеграции,  
   - либо заранее собрать **тонкие C-шимы** и зарегистрировать их в FFI.  
   Это стандартный путь для Python/Lua/JS движков.

### Когда нужен байткод
- Чтобы уменьшить накладные и сделать interpreter tight-loop (`switch(op)`),  
- чтобы отделить «форму хранения» от «дерева» (кэширование, быстрый старт),  
- чтобы проще делать JIT. Но это **эволюционный** шаг, не новая архитектура.

### Практический старт для тебя
- Оставь AOT-C++ бэкенд как сейчас.  
- Добавь tree-walk VM на твоём IR + FFI с `Value / Fn` как выше.  
- Договорись о 4–5 типах и маршалинге (`i64, f64, ptr, slice, result`).  
- Оберни нужные C-библиотеки в маленькие шими (`name → fnptr`).  
- Позже — линейная память/хэндлы, регистровый байткод и (опционально) JIT.

Итого: VM — это действительно интерпретатор твоего IR (с возможной компрессией в байткод), а работа «напрямую с памятью» и C — решается FFI/ABI-слоем.

user
ладно, допустим  я с нуля пишу интерпретатор ir, пусть даже на руби. для нас ir - это что в общем случае, команды виртуальной машине?

ChatGPT
кратко: **IR — это ваш «язык ядра»**, на котором фронтенд понижает всё (if/let/match/loop/ADT) в пару **универсальных узлов/инструкций**. VM/интерпретатор исполняет уже **IR**, а не исходник.

### Что должно быть в IR (минимум)
- **Виды узлов**: `Const, Var, Let, Block, If, Loop, Match, Call` (+ при желании `Tuple, ADT, Try, Defer`).
- **Значения/типы**: скаляры (`i64,f64,bool,str`), `Tuple`, `ADT(tag,payload)`, `Result(ok/err)`, `Slice{ptr,len}`.
- **Управление потоком**: `If`, `Match(tag+guards)`, `Loop(state→{cont/brk,state})`.
- **Окружение**: `Env` для `let` (лексическая область).
- **FFI-протокол**: унифицированные вызовы в хост (`name → lambda(args)`) и простые представления памяти (`ptr/slice/handle`).

ниже — **минимальный tree-walk интерпретатор IR на Ruby** (≈70 строк), демонстрирующий идею:

```ruby
# === Value model (упрощённо)
ADT = Struct.new(:tag, :payload)      # tag: Symbol, payload: any
Result = Struct.new(:ok, :val)        # ok? true/false, val: any

# === IR nodes
Node = Struct.new(:k, :a, :kids)      # k: :Const/:Var/..., a: payload, kids: [nodes]

def Const(v)  = Node.new(:Const, v, [])
def Var(n)    = Node.new(:Var, n, [])
def Let(n,r,b)= Node.new(:Let, n, [r,b])
def Block(xs) = Node.new(:Block, nil, xs)
def If(c,t,f) = Node.new(:If,nil,[c,t,f])
def Loop(init, step) = Node.new(:Loop,nil,[init,step]) # step: (_s) -> [cont?, state]
def Match(scrut, cases) # cases: [ [tag_sym, body_node], ... ]
  Node.new(:Match, nil, [scrut] + cases.flat_map{|t,b| [Const(t), b]})
end
def Call(name, args)= Node.new(:Call, name, args)

# === Env (лексические области)
class Env
  def initialize(parent=nil); @p=parent; @m={}; end
  def set(k,v) = (@m[k]=v)
  def get(k)
    e=self
    while e
      return e.@m[k] if e.@m.key?(k)
      e=e.@p
    end
    raise "unbound #{k}"
  end
end

# === FFI: имя → лямбда
FFI = {
  "add"   => ->(a,b){ a + b },
  "len"   => ->(s){ s.size },
  "makeA" => ->(n){ ADT.new(:A, n) },
  "makeB" => ->(s){ ADT.new(:B, s) }
}

def eval_ir(n, env)
  case n.k
  when :Const then n.a
  when :Var   then env.get(n.a)
  when :Let   then
    v = eval_ir(n.kids[0], env)
    e2 = Env.new(env); e2.set(n.a, v)
    eval_ir(n.kids[1], e2)
  when :Block then
    e2 = Env.new(env); last = nil
    n.kids.each { |k| last = eval_ir(k, e2) }
    last
  when :If    then eval_ir(n.kids[0], env) ? eval_ir(n.kids[1], env) : eval_ir(n.kids[2], env)
  when :Loop  then
    s = eval_ir(n.kids[0], env)
    loop do
      e2 = Env.new(env); e2.set("_s", s)
      cont, s = eval_ir(n.kids[1], e2) # ожидаем [bool, state]
      break s unless cont
    end
  when :Match then
    v = eval_ir(n.kids[0], env)   # ADT(tag,payload)
    raise "not ADT" unless v.is_a?(ADT)
    i = 1
    while i < n.kids.length
      tag = n.kids[i].a
      body = n.kids[i+1]
      return eval_ir(body, env) if v.tag == tag
      i += 2
    end
    raise "non-exhaustive match"
  when :Call  then
    args = n.kids.map { |k| eval_ir(k, env) }
    fn = FFI[n.a] or raise "unknown fn #{n.a}"
    fn.call(*args)
  else
    raise "bad node #{n.k}"
  end
end

# === пример: let + match + loop
prog =
  Let("x",
      Call("makeA", [ Call("add", [Const(1), Const(2)]) ]),
      Block([
        # match x { A(n)->n+1; B(s)->len(s) }
        Let("r",
            Match(Var("x"), [
              [:A, Call("add", [Var("x").then{ |_| Const(0) }, Const(0)])] # заглушка; реально тут бы раскладку payload
            ]),
            # сумма 1..5 через Loop: state: [i,sum]
            Let("sum",
                Loop(Const([1,0]),
                     Block([
                       # step читаем _s -> [i,sum]
                       Let("st", Var("_s"),
                         If(->(st){ st[0] > 5 }.call(Var("_s")) rescue false, # простая булева проверка
                            Const([false, Var("_s")]),                         # brk
                            Const([true,  [Var("_s")[0]+1, Var("_s")[1]+Var("_s")[0]]]) # cont
                         )
                       )
                     ])
                ),
                Const(nil)
            )
        )
      ])
  )

puts eval_ir(prog, Env.new).inspect
```

> В этом скелете идея важнее деталей: IR — это **фиксированный набор узлов** с явным управлением потоком и значениями. Интерпретатор — это просто `case` по виду узла + окружение, FFI — таблица Ruby-лямбд.

Если хочешь, дам чистую версию без «костылей» в примере: нормальную распаковку `ADT.payload` в `Match` (в т.ч. гарды), аккуратный `Loop` (`_s` как кортеж состояния), и пару мини-тестов.

user
почему  набор узлов именно  такой?  наверное мы можем говорить про эффективные наборы?  а байткод нам разве не нужен как в jvm?

ChatGPT
кратко:

### Почему такой набор узлов
Он минимально покрывает твою семантику «всё — expression» без потерь:
- **Let / Block** — лексическая область и порядок (последовательность эффектов).
- **If / Match** — разветвление по булю и по тегу (ADT).
- **Loop(state)** — единственная примитивная итерация (всё остальное сводится к ней).
- **Call** — вызовы (и в VM, и в FFI).
- (+ **Const / Var**) — листья.

Это “HIR” (высокоуровневый IR): читаемо, легко понижать в C++ и в VM.

---

### Можно ли “эффективнее”? Да — сделай 2–3 уровня IR

**1) HIR (как выше) — удобно фронтенду.**  
узлы: `Const, Var, Let, Block, If, Match, Loop, Call, Defer/Try?`

**2) MIR (нормализованный): ANF/SSA-подобный, меньше форм.**  
цель — простая интерпретация и оптимизации.
- `Let x = Prim(...)` (арифметика, сравнения, конструкторы ADT, tuple ops)
- `If c then bb1 else bb2` (CFG-блоки, `phi`-эквиваленты через параметры блоков)
- `Switch tag on bbA, bbB, …` (match → switch)
- `Goto bb(args)` / хвостовые `Call`/`Return`
- `MakeSum(tag, payload)` / `Unpack(tag, v) -> fields`
- (если есть мутация) `Alloc, Load, Store`
- (ошибки) `Raise/Catch` **или** единый `Result`

**3) LIR/Bytecode (для интерпретатора) — ещё компактнее.**  
регистровая форма или стековая, без лексических областей, только номера регистров/смещения.

---

### Нужен ли байткод «как в JVM»?
Не обязательно **сразу**. Байткод — это форма хранения/исполнения MIR:
- **Когда точно нужен:** быстрый старт, маленький размер, стабильная загрузка модулей, песочница, JIT-готовность.
- **Когда можно без него:** прототип, shadow-режим с AOT C++, быстрые итерации.

Рабочий путь: **HIR → MIR (ANF/SSA) → (A) C++ эмиттер, (B) интерпретатор MIR**. Потом, при необходимости, добавляешь **байткодный** бэкенд: MIR → опкоды.

---

### Рекомендованный “эффективный” набор (MIR)
- **Значения:** `i64, f64, bool, ptr, slice, tuple, sum(tag,payload), result(ok/err)`.
- **Операции:**
  - `Prim`: `add, sub, cmp, not, …`
  - `MakeTuple/Proj`, `MakeSum/Unpack`
  - `If, Switch(tag)`, `Goto`, `Return`, `Call`
  - (опц.) `Alloc/Load/Store` для кучи
  - (опц.) `DeferEnter/DeferExit` либо свести к `TryFinally`
- **Управление потоком:** только *блоки и переходы*. Любой `Loop` разворачивается в CFG с `Goto`.

Это даёт:
- простые оптимизации (CSE, copy-prop, DCE),
- прямую компиляцию в байткод,
- быструю интерпретацию (без лексических Env и вложенных структур).

---

### Если/когда делаешь байткод
Выбери модель:
- **стековая** (проще декодинг, тяжелее оптимизация): `PUSH k`, `ADD`, `JMP ifz`
- **регистровая (рекомендую)**: быстрее интерпретируется и проще JIT.
  - Пример опкодов:  
    `MOV r1, k`, `ADD r2, r3, r4`, `MAKE_SUM r5, tag, r6`,  
    `UNPACK r7, r8, tag`, `SWITCH r9 -> bb0,bb1`,  
    `CALL r10, fn, r11..rN`, `RET rX`, `JMP bb`, `CJMP rC, bbT, bbF`.

Констант-пул: строки, числа, таблица Fn/FFI.

---

### Где окажется pattern matching
HIR: `Match` с гард-ветками →  
MIR: `Switch(tag)` + (опциональные) `If guard` + `Unpack` →  
Bytecode: `SWITCH` + `CMP/JMP` + `UNPACK`.

---

### FFI и память
- В MIR/LIR: `CALL host_fn(args)` с сигнатурой через простые типы (`i64, f64, ptr, slice`).
- Память: либо линейная (offset), либо хэндлы таблицей. Это не требует AST/HIR — это уровень VM.

---

### Итог
- Твой “базовый” набор узлов — это **HIR** (удобство и ясность).  
- Для эффективности введи **MIR (ANF/SSA)** с ~10 примитивами и CFG.  
- **Байткод** — это уже форма MIR для интерпретатора; внедряй, когда понадобится размер/скорость загрузки/JIT.  
- Переход происходит без смены фронтенда: `AST → HIR → MIR → {C++ | VM(IR) | VM(Bytecode)}`.

user
ну по сути ведь обычный процессор - это и есть регистровая машина?

ChatGPT
кратко: **да, почти все современные CPU — регистровые load–store машины.**

- **Модель:** операции идут над **архитектурными регистрами** (GP/FPU/SIMD), доступ к памяти — отдельными `load/store`.  
- **Не стековая:** в отличие от JVM/Wasm-байткода, где ALU берёт операнды со стека, у CPU источники — регистры.  
- **x86 “CISC”, но внутри RISC-подобный регистр:** декод превращает сложные инструкции в микро-опы над регистровым ядром.  
- **Физические vs архитектурные:** out-of-order, **register renaming** → больше **физических** регистров, чем видимых (для устранения зависимостей).  
- **SIMD/GPU:** векторные регистры (SSE/AVX) и у GPU — тысячи регистров на поток; всё равно регистровая модель.  
- **Адресация/IO:** сложные addressing modes, memory-mapped IO — это про доступ к памяти, не отменяет регистровость.

### что это значит для твоей VM/байткода
- **Регистровый байткод** обычно быстрее в интерпретации (меньше push/pop, меньше decode) и ближе к CPU/JIT.  
- **Стековый байткод** компактнее и проще генерить, но чаще проигрывает по интерпретаторской скорости.  
- Практика: фронтенд → HIR → **MIR в регистровой форме** →  
  — интерпретатор регистрового байткода,  
  — или JIT/АOT на реальные регистры CPU.

user
что  даёт нам слой  виртуальной vm и какой её стоит делать

ChatGPT
кратко:

## Зачем свой VM-слой
- **Единая семантика**: один бэкенд для всего (интерпретатор/байткод/JIT) вместо «C++-эмиттера с костылями».
- **Портируемость**: один рантайм → Linux/Windows/macOS/WebAssembly.
- **Безопасность/песочница**: лимиты, таймауты, запрет сырого `ptr`, контролируемый FFI.
- **Инструменты**: детерминированные трассы, профайлер, пошаговая отладка, снимки состояния.
- **Производительность по шагам**: сначала интерпретируем, затем включаем peephole/SSA/JIT без смены фронтенда.
- **Реактивность/“горячие” обновления**: можно грузить/обновлять модули без пересборки C++.
- **Равномерные абстракции**: pattern matching/ADT/Result — родные, не через STL-трюки.

## Какую VM делать
**Рекомендация**: регистровая VM на MIR (SSA-дружелюбный), с FFI и простой моделью памяти.

### Мини-спека (v1)
- **Значения**: `i64, f64, bool, ref(handle), slice{base,len}, tuple, sum{tag,payload}, result{ok,err}`.
- **Память**: линейная память VM *или* хэндлы (таблица объектов). Начать с хэндлов — безопаснее.
- **FFI**: `call_host name(args…) → result` с простыми типами (`i64/f64/slice/ref`). Регистрация таблицей.
- **Управление потоком**: только блоки и переходы:
  - `br bb`, `cbr rCond, bbT, bbF`, `switch rTag → bb…`, `ret r`.
- **Операции**:
  - арифм/логика: `add/sub/mul/div/mod/cmp`.
  - кортежи/суммы: `mk_tuple, proj, mk_sum, is_tag, unpack`.
  - результат/ошибки: `mk_ok, mk_err, is_ok, unwrap_ok/err`.
  - память (если нужны буферы): `alloc(size) → ref`, `load/store` по смещению для «плоских» POD.
- **Вызовы**:
  - `call rDst, fnId, rA…rN` (внутренние функции VM),
  - `call_host rDst, nameId, rA…rN` (FFI).
- **Дебаг**: таблицы `bb -> source span`, map регистров, event-хуки `on_call/on_ret/on_alloc`.

### Формат кода
- **Регистровая форма** (номера `r0..rN`, без стеков).
- Модуль: констант-пул (строки, числа), функции (арность, количество регистров, блоки).
- Сериализация: простая TLV/CBOR/MsgPack — грузится без парсинга AST.

### Интерпретатор
- tight-loop `switch(op)` по инструкциям, без аллокаций.
- быстрая ветка для арифметики/ветвлений; `switch` для `match` — jump table по тегу.
- «песочница» по умолчанию: лимит шагов/памяти/FFI.

### Политика FFI
- На старте только «чистые» функции и операции над `slice/ref`.
- Сырые `void*` запрещены; если нужно — заверни в `ref` и выдавай набор геттеров/сеттеров/операций.
- Для C-библиотек — тонкие шымы: сигнатуры → маршалинг `i64/f64/slice/ref`.

### Память/владение (по этапам)
1. **v0**: арены + хэндлы (нет перемещений, дёшево, детерминировано).
2. **v1**: RC для общих объектов (строки/векторы).
3. **v2**: инкрементальный GC (pin для FFI), если понадобится.

### Оптимизации позже
- Peephole (копи-проп, DCE).
- SSA на MIR (параметры блоков как φ).
- Tracing/JIT горячих путей (по профайлеру VM).

## Переход от транслятора — план на 3 шага
1) Зафиксируй **HIR → MIR** (те же «кирпичи», но CFG/регистры).  
2) Сделай **AOT-C++** и **VM** как два бэкенда MIR (golden-тесты + shadow-режим).  
3) Включай FFI/линейную память по мере нужды; позже — байткод-сериализацию и JIT.

## TL;DR
- Да, слой VM даёт контроль, переносимость, отладку и постепенную производительность.
- Делаем **регистровую, MIR-центричную VM** с хэндлами и простым FFI.  
- Байткод — это форма MIR; нужен для загрузки/скорости, но не обязателен на первом шаге.

user
но вот я делаю свою вм, там ведь обращение к памяти  - это не та же память, что в реальном процессоре, то есть не могу напрямую c++ код использовать?

ChatGPT
коротко: **“память ВМ” ≠ автоматически “память C++”**, но сделать прямую работу можно. Есть три модели — от самой быстрой (но опасной) до самой безопасной.

# 0) Можно ли “просто подключить заголовок C++”?
Нет. Хедер нужен на этапе компиляции. В рантайме ВМ вызывает **скомпилированные** функции через FFI (фиксированный ABI).

# 1) Модели памяти/FFI

**A. raw-ptr (быстро, небезопасно)**  
ВМ аллоцирует через `malloc/new`, хранит **сырые `void*`** в своих значениях. Хостовые C/C++ функции видят те же адреса.
- плюсы: ноль копий, ноль маршалинга
- минусы: никакой песочницы, нужен `pin` при GC
```cpp
struct Slice { void* ptr; size_t len; };
using Fn = Value(*)(Value*, size_t);
```

**B. linear-mem + offset (как WebAssembly)**  
У ВМ своя линейная память (`std::vector<uint8_t>`/`mmap`). В FFI передаёте **смещение+длину**; хост читает через `base+offset`.
- плюсы: безопасно, можно менять базу, снапшоты, песочница
- минусы: нужен маршалинг адресов, иногда копии
```cpp
struct Slice { uint32_t off; uint32_t len; }; // оффсет в линейной памяти VM
auto* p = vm.memory_base() + slice.off;
```

**C. handles/descriptor table (самое безопасное)**  
ВМ выдаёт целочисленные **хэндлы**; у хоста таблица `{handle -> {ptr, len, meta}}`.
- плюсы: контроль владения, легко валидировать/логировать, удобно с GC/RC
- минусы: тонкий слой диспетчеризации на каждом вызове
```cpp
struct Ref { uint32_t id; }; // хэндл
auto buf = host_table.lookup(ref.id); // {void* ptr, size_t len}
```

> Практика: начните с **handles** (C) или **linear-mem** (B). Для “внутренних” быстрых путей можно добавить **capability** на raw-ptr (A).

# 2) Как “передавать” в C/C++
Определите **микро-ABI** значений: `i64, f64, bool, slice, ref, result{ok,err}`. Регистрируйте функции хоста.

```cpp
// ВМ → Хост
enum class K { I64, F64, Slice, Ref, Bool, Result };
struct Val { K k; uint64_t a, b; }; // Slice: a=ptr/off/handle, b=len

using HostFn = Val(*)(const Val* args, size_t n, VM* vm);

Val ffi_write(const Val* a, size_t, VM* vm){
  int fd = (int)a[0].a;
  // B) linear-mem
  uint8_t* p = vm->mem_base() + a[1].a; size_t nbytes = a[1].b;
  auto r = ::write(fd, p, nbytes);
  return Val{K::I64, (uint64_t)r, 0};
}
```

# 3) Что с GC/владением
- **Арены/RC (старт)**: просто; при FFI отдавайте `slice` на неизменяемые буферы из арен.  
- **GC (позже)**: вводите **pin** (запрет перемещения) на объекты, чьи адреса видит C. Для B/C pin не нужен (адрес хоста не меняется).

# 4) Как “плавно” сделать C++ доступным
- Собираете нужные C/C++ библиотеки вместе с хостом.
- Пишете **тонкие шимы**: плоские аргументы (`i64/f64/slice/ref`) ⇄ реальные типы.
- Регистрируете их в таблице FFI: `name → HostFn`.
- В языке даёте модуль `ffi`: `extern fun write(fd: i64, buf: slice<u8>) -> i64`.

# 5) Когда нужен байткод/JIT
- Не для FFI, а для скорости/размера/быстрого старта. FFI одинаков для tree-walk, байткода и JIT.

# 6) Резюме
- Нельзя “инклюдить” C++ **во время исполнения**; зовём скомпилированные функции через FFI.  
- Память ВМ может **совпадать** с реальной (модель A) или быть изолированной (B/C).  
- Рекомендация: **handles или linear-memory** + фиксированный микро-ABI.  
- Хотите нулевые копии — добавьте “unsafe raw-ptr” как опцию под флагом.

user
ну шимы это  всё не то. вот как условно я буду xcb или opengl использовать без обвязок  или gtk как раз хочется без обвязок. а если я как мы раньше обсуждали добавляю лишь рантайм, чтобы всё как выражение сделать, я ведь всё равно могу ещё c++ код напрямую использовать, так где граница с настоящей  vm?

ChatGPT
краткий ответ:

- **С тонким рантаймом (AOT→C++)** — ты продолжаешь писать/генерить **чистый C++**, инклюдишь `xcb`, `OpenGL`, `GTK` как обычно, зовёшь их API напрямую. «Всё-как-выражение» тут — просто сахар понижения (BLOCK/MATCH/LOOP), никакой изоляции памяти нет.
- **С настоящей VM** — твой код исполняет **движок** (интерпретатор/байткод/JIT) с **своей** моделью памяти/вызовов. Заголовки C/C++ внутри VM-кода «подключить» нельзя: наружу только через FFI/нативные модули (то есть граница есть всегда, даже если «шим» тонкий).

# Где ровно проходит граница

**AOT + тонкий рантайм (это не VM):**
- `#include <xcb/xcb.h>`, `#include <GL/gl.h>` — работают напрямую.
- Любые шаблоны/инлайны/RAII из C++ — доступны.
- Адреса/указатели — те же, что у процесса; можно передавать «сырые» `xcb_connection_t*`, `GLuint`, `GtkWidget*`.
- «Рантайм» = 100–150 строк утилит (BLOCK/MATCH/LOOP/DEFER) для понижения; он **ничего не эмулирует**.

**VM (даже минимальная):**
- Код языка бежит **не как C++**, а как IR/байткод → нужны вызовы «наружу».
- Память VM ≠ автоматически память хоста → нужен протокол (raw ptr / linear memory / handles).
- Нужен **стабильный ABI** для вызовов `xcb_*`, `gl*`, `gtk_*` → либо FFI, либо заранее собранные «нативные модули».
- Шим можно сделать **ультра-тонким** (по сути объявление сигнатур и маршалинг плоских аргументов), но граница всё равно есть.

# Как работать «без обвязок» на практике

### Если тебе важен прямой доступ к XCB/OpenGL/GTK
Выбирай **AOT + тонкий рантайм** как основной таргет системного кода. Пример эмита — как обычно:

```cpp
#include <xcb/xcb.h>
#include <GL/gl.h>
#include "expr.hpp" // твои BLOCK/MATCH/...

int main() {
  auto conn = xcb_connect(nullptr, nullptr);
  auto ok = EXPR_BLOCK( glClear(GL_COLOR_BUFFER_BIT); return 0; );
  // ... обычный C++ вокруг
}
```

Это **нативно**, без FFI, без «шимов».

### Если VM всё же нужна
Делай **гибрид**:
- «Тяжёлое»/системное (XCB/GL/GTK) — в **нативных модулях**, которые ты компилишь как C/C++ библиотеку и регистрируешь в VM (тонкий слой связывания сигнатур).
- Логика/скрипты/правила — в твоём языке поверх VM.
- Когда очень надо «почти без шима» — выбери FFI-модель **raw-ptr** под флагом (небезопасно, но быстрый путь: VM хранит `void*`, хост видит тот же адрес).

# Нормальная архитектура для тебя
- **По умолчанию:** AOT→C++ + тонкий рантайм (прямой XCB/GL/GTK).
- **Позже:** добавить VM для скриптов/плагинов/“горячих” обновлений.
- **Мост:** стабилизированный FFI (микро-ABI: `i64/f64/ptr/slice`), и «нативные модули» с декларациями функций. Шим — это 5–10 строк на функцию (сигнатура + преобразование аргументов), и он пишется один раз.

# TL;DR
- Хотишь **никаких обвязок** с XCB/OpenGL/GTK → оставайся в **AOT C++ с тонким рантаймом**: это по сути «C++ с удобным понижением», а не VM.
- **VM** = другой слой (движок + память + вызовы). Без минимального FFI-контракта к нативным API не подлезть. Делай гибрид: нативные модули для системного, VM — для логики.

user
хорошо, если я хочу максимально продвинутый рантайм, но с возможностью  подключения c++ библиотек напрямую. что туда можно включить? 

ChatGPT
если остаёмся в **AOT C++** (прямые инклюды XCB/GL/GTK без FFI), «продвинутый» рантайм = компактный header-only набор, который закрывает семантику «всё—expression», ошибки, ресурсы, аллокаторы, профайлинг и отладку — и не мешает нативным API.

ниже — что имеет смысл включить.

# 1) Ядро выражений
- `EXPR_BLOCK` / вариант «scope+tmp» (для statement-позиции)
- `MATCH`:
  - `overloaded`, именной визитор, `match_total_check`
  - деструктуринг через `as_tuple(T)` (ADL)
- `LOOP` с `cont/brk`, no-lambda вариант (fnptr/functor)
- `DEFER/scope_exit` (+ `scope_fail/scope_success`)

# 2) Ошибки/контракты
- `Expected<T,E>` (если нет C++23) + `and_then/map/map_error/or_else`
- `TRY(expr)` (разворачивает в `Expected`)
- `panic(fmt, ...)` с стеком (backtrace) и `#line`
- Политики ошибок: `throw` | `expected` (compile-time флаг)

# 3) Память/аллокаторы
- Аренный аллокатор (bump) + `pmr::memory_resource` адаптер
- Кольцевой буфер для краткоживущих объектов
- Маленькие контейнеры: `small_vec<T,N>`, `stable_vec` (не инвалидирует ptr)
- Обёртки над внешними аллокаторами (jemalloc/mimalloc) через PMR

# 4) Ресурсы/RAII
- Универсальный `unique_handle<T, Deleter>` (для `xcb_connection_t*`, `FILE*`, `GL objects`)
- `finally_on_unwind` (детект через `std::uncaught_exceptions`)
- `fd`, `mmap`, таймеры — тонкие RAII-обёртки (без скрытого потока)

# 5) Диагностика/инструменты
- Трассировка: `TRACE_SCOPE(name)`, `TRACE_EVENT(...)`
- Счётчики/метрики: `counter(name).inc(n)`
- Логгер без аллокаций (ring buffer, printf-like)
- Санитайзеры: макросы для ASan/UBSan hooks
- `ASSERT/EXPECT` с печатью значений и срезов

# 6) Время/конкурентность (опционально)
- Лёгкий `thread_pool` + `work_stealing` очередь (без futures)
- Короутины (если C++20): `task<T>` только для **внутренней** асинхры (никаких await на внешние API)
- `deadline_timer`, `co_timeout`

# 7) Ranges/утилиты
- `defer_range(f_begin, f_end)` (ресурс в качестве диапазона)
- `generator<T>` (iterable короутина) — удобно в `MATCH/LOOP`
- Малый форматтер (в духе `{}`) без RTTI

# 8) Интеграции с нативом (XCB/GL/GTK)
- Нулевые «шипы-помощники», **без FFI**:
  - `GL_CHECK(expr)` (glGetError loop)
  - `XCB_CHECK(expr)` (проверка `xcb_generic_error_t*`)
  - `unique_handle<GLBuffer, glDeleteBuffers>`
  - `unique_handle<XcbConn, xcb_disconnect>`
- Вспом. конверторы: `span<u8> ↔ slice`, `string_view` everywhere
- Никаких «прослоек» над самими API — только RAII и проверки

# 9) Конфигурация/политики
- Флаги: `EXPR_USE_EXCEPTIONS`, `EXPR_SMALLVEC_INLINE=32`, `EXPR_TRACE`, `EXPR_PMR`
- `#line` из исходника языка (для читаемых стеков)
- Строгие warning-флаги и `[[nodiscard]]` на критичных функциях

# 10) Мини-пример склейки

```cpp
// expr_core.hpp
#define EXPR_BLOCK(...) ([&]{ __VA_ARGS__ }())

template<class... Ts> struct overloaded : Ts... { using Ts::operator()...; };
template<class... Ts> overloaded(Ts...) -> overloaded<Ts...>;

template<class V, class... Fs>
decltype(auto) MATCH(V&& v, Fs&&... fs) {
  return std::visit(overloaded{std::forward<Fs>(fs)...}, std::forward<V>(v));
}

struct scope_exit {
  std::function<void()> f;
  ~scope_exit(){ if(f) f(); }
};
#define DEFER(name) ::scope_exit name{[&]()}
```

```cpp
// handles.hpp
template<class T, class D>
struct unique_handle {
  T h{}; D d{};
  unique_handle() = default;
  explicit unique_handle(T h_, D d_ = {}) : h(h_), d(d_) {}
  ~unique_handle(){ reset(); }
  unique_handle(unique_handle&& o) noexcept : h(o.h), d(o.d){ o.h={}; }
  unique_handle& operator=(unique_handle&& o) noexcept { if(this!=&o){ reset(); h=o.h; d=o.d; o.h={}; } return *this; }
  void reset(T nh = {}){ if(h) d(h); h = nh; }
  T get() const { return h; }
  explicit operator bool() const { return h!=T{}; }
};

// примеры:
struct GLBufDel { void operator()(GLuint id) const { if(id) glDeleteBuffers(1,&id); } };
using gl_buffer = unique_handle<GLuint, GLBufDel>;

struct XcbConnDel { void operator()(xcb_connection_t* c) const { if(c) xcb_disconnect(c); } };
using xcb_conn = unique_handle<xcb_connection_t*, XcbConnDel>;
```

```cpp
// usage (нативно, без FFI)
#include <xcb/xcb.h>
#include <GL/gl.h>
#include "expr_core.hpp"
#include "handles.hpp"

int main(){
  xcb_conn conn{xcb_connect(nullptr,nullptr)};
  gl_buffer vbo; glGenBuffers(1, &vbo.reset(), /*hack: можно сделать метод emplace*/);
  auto result = EXPR_BLOCK(
    glBindBuffer(GL_ARRAY_BUFFER, vbo.get());
    // … ваш код …
    return 0;
  );
}
```

# 11) Структура каталога
```
/expr/
  expr_core.hpp        // BLOCK, MATCH, LOOP, DEFER
  expected.hpp         // Expected + TRY/AND_THEN
  handles.hpp          // unique_handle, fd/mmap/GL/XCB делетеры
  alloc.hpp            // arena, small_vec, pmr adapters
  trace.hpp            // TRACE/metrics/log
  ranges.hpp           // generator, small utils
  config.hpp           // флаги/атрибуты
/tests/ …              // golden-тесты по формам и интеграции с XCB/GL
```

# 12) Правила применения
- нативные API — **напрямую**; рантайм только помогает с формами/RAII/контролем.
- никаких фоновых потоков внутри рантайма «по умолчанию».
- всё header-only, без глобальных синглтонов.

хочешь — сгенерю стартовый каркас (`expr_core.hpp`, `handles.hpp`, `expected.hpp`) + 6 коротких тестов (block/if/match/loop + XCB connect + GL error guard).

user
а условно если идти тем путём что мы шли парсер c++ на руби, потом  наоборот генератор (даже с сохранением пробелов)  потом ir и ast уже своего языка. вот этот рантайм чтобы описать не на c++ как  лучше сделать? не хочется c++ напрямую писать

ChatGPT
да — C++ руками не обязательно. Сделай **декларативную спецификацию рантайма** и генерируй целевые файлы (C++-header для AOT, реф-интерпретатор на Ruby, доку) из одной схемы.

### Мини-путь (практично)

1) **Runtime-IDL (YAML/JSON)**
- описывает примитивы: `BLOCK/MATCH/LOOP/DEFER`, `Expected`, `unique_handle`, политики ошибок, флаги.
- параметры: имена макросов, нужны ли no-lambda варианты, тип `Error`, включать ли `std::expected`, и т. п.

```yaml
runtime:
  macros:
    block: EXPR_BLOCK
    defer: EXPR_DEFER
  features:
    match:
      style: overloaded         # or named_visitor_if_over_N
      named_visitor_threshold: 5
    loop:
      cont_name: cont
      break_name: brk
      fnptr_variant: true
    expected:
      enabled: true
      error_type: std::exception_ptr
    handles:
      gl: true
      xcb: true
  policies:
    errors: expected            # or exceptions
    capture: by_ref             # default for BLOCK/MATCH lambdas
```

2) **Генератор на Ruby**
- читает IDL → рендерит `expr_core.hpp`, `expected.hpp`, `handles.hpp` (и, при желании, Ruby-версию для реф-рантайма).
- шаблоны ERB/tilt + «preserve whitespace»: ты как раз уже умеешь.

```ruby
# tools/gen_runtime.rb
require 'yaml'; require 'erb'
cfg = YAML.load_file(ARGV[0])

def render(tpl, b) = ERB.new(File.read(tpl), trim_mode: '-').result(b)

File.write('include/expr_core.hpp',  render('templates/expr_core.hpp.erb', binding))
File.write('include/expected.hpp',   render('templates/expected.hpp.erb',  binding)) if cfg.dig('runtime','features','expected','enabled')
File.write('include/handles.hpp',    render('templates/handles.hpp.erb',   binding))
File.write('ruby/expr_runtime.rb',   render('templates/expr_runtime.rb.erb',binding)) # опционально
```

3) **Три выхода из одной спецификации**
- **AOT**: `include/*.hpp` — подключаешь в сгенерированный C++ (прямые XCB/OpenGL/GTK **без обвязок**).
- **REF**: `ruby/expr_runtime.rb` — эталон «поведения» примитивов для быстрых тестов.
- **DOC**: из IDL собери markdown со сводкой API (ERB шаблон).

4) **Правила генерации (жёстко зафиксируй)**
- `BLOCK`: макрос + «scope+tmp» вариант.  
- `MATCH`: `overloaded` лямбды; если кейсов > N — именованный визитор-класс (меньше лямбд).  
- `LOOP`: структура `Step{Ctrl,T}` + helpers `cont/brk` + перегрузка под `F(T)->Step<T>` **и** `Step<T>(*fn)(T)` (без лямбд).  
- `DEFER`: `scope_exit` + `scope_success/fail` (через `std::uncaught_exceptions`).  
- `Expected`: `map/and_then/or_else/map_error` (или `std::expected` при C++23).  
- `Handles`: шаблон `unique_handle<T,Deleter>` + готовые делитеры (GL/XCB/FILE).  

5) **Примеры шаблонов (фрагменты)**
```erb
// templates/expr_core.hpp.erb
#pragma once
#include <utility> <variant> <functional> <type_traits>
#define <%= cfg['runtime']['macros']['block'] %>(...) ([&]{ __VA_ARGS__ }())
namespace expr {
template<class... Ts> struct overloaded : Ts... { using Ts::operator()...; };
template<class... Ts> overloaded(Ts...) -> overloaded<Ts...>;
template<class V, class... Fs>
decltype(auto) match(V&& v, Fs&&... fs){
  return std::visit(overloaded{std::forward<Fs>(fs)...}, std::forward<V>(v));
}
// loop
enum class ctrl { Cont, Break };
template<class T> struct step { ctrl c; T s; };
template<class T> inline step<T> <%= cfg.dig('runtime','features','loop','cont_name') %>(T v){ return {ctrl::Cont, std::move(v)}; }
template<class T> inline step<T> <%= cfg.dig('runtime','features','loop','break_name') %>(T v){ return {ctrl::Break, std::move(v)}; }
template<class T, class F> T loop(T init, F&& f){
  T s = std::move(init);
  for(;;){ auto r = std::forward<F>(f)(s); s = std::move(r.s); if(r.c==ctrl::Break) return s; }
}
} // namespace expr
```

```erb
// templates/expected.hpp.erb
#pragma once
#include <variant> <exception>
namespace expr {
template<class T, class E = <%= cfg.dig('runtime','features','expected','error_type') %>>
struct Expected { /* ... map/and_then/or_else ... */ };
template<class F, class T = std::decay_t<decltype(std::declval<F&>()())>>
Expected<T> try_expr(F&& f){ try{ return Expected<T>::ok(std::forward<F>(f)()); } catch(...){ return Expected<T>::err(std::current_exception()); } }
}
```

6) **Тесты (golden)**
- тестируешь **генератор** (YAML → *.hpp) и затем «поведение» (мини-C++ файлы, линк против сгенерённого рантайма).  
- параллельно гоняешь Ruby-референс теми же кейсами.

```
/tests/golden/T1_block.input.xqr  → T1_block.cpp.expected
make test → gen → compile (clang++ -std=c++20 -O2 -Wall) → run
```

7) **Переход дальше**
- Когда появится VM, этот же IDL дополняешь «опкодами» и генерируешь:
  - C++-рантайм (как сейчас),
  - **байткод-дефы** (enum опкодов, диспетчер),
  - таблицу соответствий HIR→MIR/BC для документации.

---

### Итог
- Пишешь **не C++**, а **YAML-спеку** + **шаблоны на Ruby**.  
- Из одной точки генерируешь: C++ headers (AOT без FFI), Ruby-референс, доки.  
- Примитивы/поведение фиксированы → фронтенд и агенты опираются на стабильный контракт.

user
зачем yaml. у нас уже есть ведь dsl и  c++ ast. пусть будет спец dsl для рантайма в самом руби

ChatGPT
ок, без yaml. Делаем **рубишный DSL** + генератор, который из одной спеки выдаёт:
- `include/expr_core.hpp`, `include/expected.hpp`, `include/handles.hpp`
- (опц.) `ruby/expr_ref.rb` — референс-поведение для тестов

ниже — минимально рабочий каркас.

---

### 1) DSL (описание рантайма)

```ruby
# tools/runtime_dsl.rb
module RuntimeDSL
  class Cfg
    attr_accessor :macros, :match, :loop, :expected, :handles, :policies
    def initialize
      @macros   = { block: "EXPR_BLOCK", defer: "EXPR_DEFER" }
      @match    = { style: :overloaded, named_visitor_threshold: 6 }
      @loop     = { cont: "cont", brk: "brk", fnptr_variant: true }
      @expected = { enabled: true, error_type: "std::exception_ptr" }
      @handles  = { gl: true, xcb: true, file: true }
      @policies = { errors: :expected, capture: :by_ref }
    end
  end

  def runtime(&blk)
    @cfg = Cfg.new
    instance_eval(&blk)
    @cfg
  end

  def macros(block:, defer:)
    @cfg.macros[:block] = block
    @cfg.macros[:defer] = defer
  end

  def match(style: :overloaded, named_visitor_threshold: 6)
    @cfg.match[:style] = style
    @cfg.match[:named_visitor_threshold] = named_visitor_threshold
  end

  def loop(cont: "cont", brk: "brk", fnptr_variant: true)
    @cfg.loop[:cont] = cont; @cfg.loop[:brk] = brk
    @cfg.loop[:fnptr_variant] = fnptr_variant
  end

  def expected(enabled: true, error_type: "std::exception_ptr")
    @cfg.expected[:enabled] = enabled
    @cfg.expected[:error_type] = error_type
  end

  def handles(gl: true, xcb: true, file: true)
    @cfg.handles[:gl] = gl; @cfg.handles[:xcb] = xcb; @cfg.handles[:file] = file
  end

  def policies(errors: :expected, capture: :by_ref)
    @cfg.policies[:errors] = errors; @cfg.policies[:capture] = capture
  end
end
```

---

### 2) Спека рантайма (в самом Ruby)

```ruby
# runtime_spec.rb
require_relative "tools/runtime_dsl"
include RuntimeDSL

CFG = runtime do
  macros  block: "EXPR_BLOCK", defer: "EXPR_DEFER"
  match   style: :overloaded, named_visitor_threshold: 5
  loop    cont: "cont", brk: "brk", fnptr_variant: true
  expected enabled: true, error_type: "std::exception_ptr"
  handles gl: true, xcb: true, file: true
  policies errors: :expected, capture: :by_ref
end
```

---

### 3) Генератор (без ERB, всё строками)

```ruby
# tools/gen_runtime.rb
require_relative "runtime_dsl"
require_relative "../runtime_spec"

cfg = CFG

core_hpp = <<~CPP
#pragma once
#include <utility>
#include <variant>
#include <functional>
#include <type_traits>

#define #{cfg.macros[:block]}(...) ([&]{ __VA_ARGS__ }())

namespace expr {
template<class... Ts> struct overloaded : Ts... { using Ts::operator()...; };
template<class... Ts> overloaded(Ts...) -> overloaded<Ts...>;

template<class V, class... Fs>
decltype(auto) match(V&& v, Fs&&... fs){
  return std::visit(overloaded{std::forward<Fs>(fs)...}, std::forward<V>(v));
}

enum class ctrl { Cont, Break };
template<class T> struct step { ctrl c; T s; };

template<class T> inline step<T> #{cfg.loop[:cont]}(T v){ return {ctrl::Cont, std::move(v)}; }
template<class T> inline step<T> #{cfg.loop[:brk]}(T v){ return {ctrl::Break, std::move(v)}; }

template<class T, class F>
T loop(T init, F&& fn){
  T s = std::move(init);
  for(;;){
    auto r = std::forward<F>(fn)(s);
    s = std::move(r.s);
    if (r.c == ctrl::Break) return s;
  }
}
} // namespace expr
CPP

expected_hpp =
  if cfg.expected[:enabled]
    <<~CPP
#pragma once
#include <variant>
#include <exception>
namespace expr {
template<class T, class E = #{cfg.expected[:error_type]}>
struct Expected {
  std::variant<T,E> v;
  Expected(T val): v(std::move(val)) {}
  Expected(E err, int): v(std::move(err)) {}
  static Expected ok(T v){ return Expected(std::move(v)); }
  static Expected err(E e){ return Expected(std::move(e), 0); }
  bool has_value() const { return std::holds_alternative<T>(v); }
  T& value(){ return std::get<T>(v); }
  const T& value() const { return std::get<T>(v); }
  E& error(){ return std::get<E>(v); }
  const E& error() const { return std::get<E>(v); }
  template<class F>
  auto map(F&& f) & {
    using U = std::decay_t<decltype(f(std::declval<T&>()))>;
    if (has_value()) return Expected<U,E>::ok(std::forward<F>(f)(value()));
    return Expected<U,E>::err(error());
  }
  template<class F>
  auto and_then(F&& f) & {
    if (has_value()) return std::forward<F>(f)(value());
    return Expected<std::decay_t<T>,E>::err(error());
  }
  template<class F>
  auto map_error(F&& f) & {
    if (!has_value()) return Expected<T, std::decay_t<decltype(f(error()))>>::err(std::forward<F>(f)(error()));
    return Expected<T,E>::ok(value());
  }
};
template<class F, class T = std::decay_t<decltype(std::declval<F&>()())>>
Expected<T> try_expr(F&& f){ try{ return Expected<T>::ok(std::forward<F>(f)()); } catch(...) { return Expected<T>::err(std::current_exception()); } }
} // namespace expr
CPP
  else
    ""

handles_hpp = <<~CPP
#pragma once
namespace expr {
template<class T, class D>
struct unique_handle {
  T h{}; D d{};
  unique_handle() = default;
  explicit unique_handle(T nh, D del = {}): h(nh), d(del) {}
  ~unique_handle(){ reset(); }
  unique_handle(unique_handle&& o) noexcept : h(o.h), d(o.d){ o.h = T{}; }
  unique_handle& operator=(unique_handle&& o) noexcept {
    if (this!=&o){ reset(); h=o.h; d=o.d; o.h = T{}; }
    return *this;
  }
  void reset(T nh = T{}){ if (h != T{}) d(h); h = nh; }
  T get() const { return h; }
  explicit operator bool() const { return h != T{}; }
};
} // namespace expr
CPP

Dir.mkdir("include") unless Dir.exist?("include")
File.write("include/expr_core.hpp", core_hpp)
File.write("include/expected.hpp", expected_hpp) if !expected_hpp.empty?
File.write("include/handles.hpp", handles_hpp)
puts "generated: include/expr_core.hpp, expected.hpp, handles.hpp"
```

---

### 4) Референс на Ruby (для быстрых тестов)

```ruby
# ruby/expr_ref.rb
module ExprRef
  Ctrl = Struct.new(:tag, :val) # :cont/:brk
  def self.cont(v) = Ctrl.new(:cont, v)
  def self.brk(v)  = Ctrl.new(:brk,  v)

  def self.loop(init)
    s = init
    loop do
      r = yield s
      s = r.val
      return s if r.tag == :brk
    end
  end

  module Match
    def self.match(val, *clauses)
      clauses.each do |(klass, fn)|
        return fn.call(val) if val.is_a?(klass)
      end
      raise "non-exhaustive"
    end
  end
end
```

---

### 5) Пример использования (нативный C++, без FFI)

```cpp
// main.cpp
#include "include/expr_core.hpp"
#include "include/expected.hpp"
#include "include/handles.hpp"
#include <variant>
#include <cstdio>

struct A{int x;}; struct B{int y;};

int main(){
  // BLOCK
  int v = EXPR_BLOCK( int a=2; int b=3; return a*b; );

  // MATCH
  using V = std::variant<A,B>;
  V vx = A{7};
  int r = std::visit(expr::overloaded{
    [](const A& a){ return a.x+1; },
    [](const B& b){ return b.y*2; }
  }, vx);

  // LOOP
  int sum = expr::loop(0, [&](int s){
    if (s >= 5) return expr::brk(s);
    return expr::cont(s+1);
  });

  // Expected
  auto e = expr::try_expr<int>([]{ if (false) throw 1; return 42; });
  std::printf("%d %d %d\n", v, r, sum + (e.has_value()?e.value():0));
}
```

---

### 6) Тест-скрипт

```bash
# tests/run.sh
set -e
ruby tools/gen_runtime.rb
c++ -std=c++20 -O2 -Wall -Wextra main.cpp -o demo
./demo
```

---

#### Идея:
- Всё описывается **в вашем Ruby DSL** (`runtime_spec.rb`).
- Генератор делает header-only рантайм; вы продолжаете **использовать C++ API напрямую** (XCB/GL/GTK).
- Позже добавите новые фичи (например, `named_visitor` при N>5, `scope_success/fail`, `pmr`-арены) — меняете DSL → реген.

Хочешь — добавлю шаблон `named_visitor` и «scope+tmp вместо BLOCK в statement-позиции», плюс мини-тесты под `ASan/UBSan`.

user
и в итоге у нас всё как выражение нормально пойдёт  в реализации без перегруза  лямбдами?

ChatGPT
да. если держаться дисциплины — лямбды сведутся к минимуму.

### рецепт без перегруза
- **Блоки**  
  *statement-позиция* → «scope+tmp», без лямбды  
  *expr-позиция* → IIFE только когда реально нужно prvalue
  ```cpp
  T _t; { auto a=f(); _t=g(a); } use(_t);     // stmt
  auto v = ([&]{ auto a=f(); return g(a); }()); // expr
  ```

- **if-выражения**  
  общий тип → тернарник; разные типы → `std::variant`
  ```cpp
  auto x = c ? e1() : e2();
  using X=std::variant<A,B>; X x = c ? X{A{}} : X{B{}};
  ```

- **match**  
  до N веток — `overloaded` лямбды; >N — **именной визитор** (без лямбд)
  ```cpp
  struct V{ R operator()(const A&)const; R operator()(const B&)const; /*...*/ };
  R r = std::visit(V{}, v);
  ```

- **loop-как-выражение**  
  без захватов — **fnptr** (нет лямбды); с захватами — короткая лямбда
  ```cpp
  using S=int; static expr::step<S> step_fn(S s){ return s>=n? expr::brk(s):expr::cont(s+1); }
  int sum = expr::loop(0, step_fn);
  ```

- **defer/RAII**  
  без лямбд не обойтись, но это 1 короткая капча на ресурс.

- **try/expected**  
  через `expr::try_expr` без лямбд в пользовательском коде, если оборачиваешь внешние вызовы.

### правила понижения (фиксируй в бэкенде)
1) `{…}` в *stmt* → scope+tmp; в *expr* → IIFE.  
2) `if` → тернарник; при `T1≠T2` → `variant` (+ `visit`).  
3) `match`: `named_visitor`, если веток >N (например, 5).  
4) `loop`: если тело без захватов → `fnptr`; иначе лямбда.  
5) Запрещено генерить произвольные лямбды вне этих случаев.

### мини-пример «всё выражения», без лишних лямбд
```cpp
// let y = { let a=f(); if(c) g(a) else h(a) }
T y; { auto a=f(); y = c ? g(a) : h(a); }

// match v { A(x)->p(x); B(y)->q(y); _->r() }
struct V {
  R operator()(const A& a) const { return p(a.x); }
  R operator()(const B& b) const { return q(b.y); }
  R operator()(const auto&) const { return r(); }
};
R out = std::visit(V{}, v);

// loop sum 1..n
using S=int; static expr::step<S> step_fn(S s){ return s>=n? expr::brk(s):expr::cont(s+1); }
int sum = expr::loop(0, step_fn);
```

Итог: с этими правилами лямбды остаются только там, где **неизбежно** (IIFE в expr-позиции, маленькие `match`/захваты в `loop`). Остальное — `scope+tmp`, `ternary`, `named visitor`, `fnptr`.

user
вот у нас ir уже есть, мы  генерим c++ ast через pass manager, как грамотно использование рантайма включить в архитектуру, ведь тут  тоже всякие эвристики, какой-то rule engine или что?

ChatGPT
ниже — «как вшить рантайм» без магии и без хаоса:

# Архитектура

**Пайплайн PassManager (IR → C++ AST):**
1) `AnalyzePositions` — где *expr*-позиция, где *stmt*.
2) `Type/Unify` — общий тип веток `if`, результ. тип `match`.
3) `EffectScope` — есть ли побочки/локалы → нужен ли новый скоуп.
4) `LoopCapture` — тело цикла захватывает окружение?
5) `MatchSizing` — количество веток (порог N).
6) `LoweringPlan` — решить: `BLOCK|VISITOR|OVERLOADED|LOOP_FN|LOOP_LAMBDA|TERNARY|VARIANT`.
7) `EmitCxx` — печать C++ AST с примитивами рантайма.

# Политики (правила в одном месте)

**Policy (конфиг из вашего Ruby-DSL):**
```ruby
RuntimePolicy.new(
  block_stmt: :scope_tmp,       # stmt → { T _t; { ... _t=...; } }
  block_expr: :iife,            # expr → EXPR_BLOCK / IIFE
  if_join:    :common_or_variant, # сначала common_type, иначе variant
  match_threshold: 5,           # >5 веток → named visitor
  loop_fnptr_ok: true,          # если нет захватов → fn-ptr
  error_model: :expected        # или :exceptions
)
```

# Правила (детерминированные, без «эвристик»)

- **Block**:  
  `stmt` → `scope+tmp`; `expr` → `EXPR_BLOCK{… return v; }`.
- **If**:  
  `T1==T2` → тернарник; иначе `using X=variant<T1,T2>; X{…}`.  
  последующий `match` по `X`.
- **Match**:  
  `cases <= N` → `std::visit(overloaded{...})`; `>N` → `struct Visitor{…}; visit(Visitor{}, v)`.
- **Loop**:  
  `no captures` → `loop(init, &step_fn)`; `captures` → `loop(init, [&](S s){…})`.
- **Try/Errors**:  
  `:expected` → `try_expr`/`Expected`; `:exceptions` → `try{…}catch`.
- **Defer**: всегда `scope_exit` (одна короткая лямбда).

Это **rule engine = таблица решений** (pure函数 от фактов анализа). Никаких «угадываний».

# Данные для решений (Facts)

```json
{
  "node_id": 42,
  "pos": "expr|stmt",
  "has_side_effects": true,
  "result_type": "T",
  "if_types": ["T1","T2"],
  "match_arms": 7,
  "loop_has_captures": false
}
```

# Реализация LoweringPlan (псевдо)

```cpp
Plan plan(Node n, Facts f, Policy p) {
  switch(n.kind){
    case Block: return f.pos==Stmt ? Plan::ScopeTmp : Plan::BlockIIFE;
    case If:
      return unify(f.if_types) ? Plan::IfTernary : Plan::IfVariant;
    case Match:
      return f.match_arms <= p.match_threshold ? Plan::MatchOverloaded : Plan::MatchVisitor;
    case Loop:
      return (!f.loop_has_captures && p.loop_fnptr_ok) ? Plan::LoopFnPtr : Plan::LoopLambda;
    default: return Plan::Direct;
  }
}
```

# Эмит C++ AST (образцы)

**Block(stmt) → scope+tmp:**
```cpp
// T _t; { auto a=f(); _t = g(a); } use(_t);
```

**Block(expr) → EXPR_BLOCK:**
```cpp
auto v = EXPR_BLOCK( auto a=f(); return g(a); );
```

**If(variant):**
```cpp
using X = std::variant<T1,T2>;
X x = c ? X{T1{/*...*/}} : X{T2{/*...*/}};
int r = std::visit(overloaded{
  [](const T1& v){ return f(v); },
  [](const T2& v){ return g(v); },
}, x);
```

**Match(>N) → Visitor:**
```cpp
struct V {
  R operator()(const A& a) const { /*...*/ }
  R operator()(const B& b) const { /*...*/ }
  R operator()(const auto&) const { return def(); }
};
R out = std::visit(V{}, v);
```

**Loop(fnptr):**
```cpp
using S=int;
static expr::step<S> step_fn(S s){ return s>=n ? expr::brk(s) : expr::cont(s+1); }
int sum = expr::loop(0, &step_fn);
```

# Тесты (golden + метрики)

- Golden: `IR → Plan → C++` (diff по ожидаемому), затем компиляция.  
- В счётчиках PassManager: `#blocks_iife`, `#blocks_scope_tmp`, `#match_visitor`, `#loop_fnptr` — видно «ползёт ли» стратегия.
- Флаги для сборки: `-DEXPR_USE_EXPECTED`, `-DEXPR_MATCH_THRESHOLD=5`.

# Где хранить правила

- **Один модуль** `LoweringPolicy` (загружается из вашего Ruby-DSL).  
- Pass `LoweringPlan` чисто-функционален: вход = Facts+Policy, выход = Plan (enum + детали).  
- Никаких «размазанных» `if` по эмиттеру; только исполнение плана.

# Когда «эвристики» понадобятся

Редко. Пример — **большие `match` с тяжёлыми ветками**: правило «если суммарная AST-масса > M → именной визитор». Но это **тоже** детерминируемое правило (порог M из конфигурации).

---

**Итог:**  
Никакого сложного «rule engine» не нужно. Достаточно:
- анализ-пассы → факты,  
- один `LoweringPolicy` из вашего DSL,  
- детерминированный маппинг `Facts × Policy → Plan`,  
- один эмиттер, который реализует **ровно** эти планы.  

Это стабильно, прозрачно, тестопригодно — и даёт «всё-как-выражение» с минимальными лямбдами.