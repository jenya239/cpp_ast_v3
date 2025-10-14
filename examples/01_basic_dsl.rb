#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/cpp_ast"

include CppAst::Builder::DSL

# Пример 1: Простая функция main
puts "=== Пример 1: main() ==="
ast = program(
  function_decl(
    "int",
    "main",
    [],
    block(return_stmt(int(0)))
  )
)
puts ast.to_source
puts

# Пример 2: Функция с вычислениями
puts "=== Пример 2: Функция add ==="
ast = program(
  function_decl(
    "int",
    "add",
    ["int a", "int b"],
    block(
      return_stmt(binary("+", id("a"), id("b")))
    )
  )
)
puts ast.to_source
puts

# Пример 3: Факториал
puts "=== Пример 3: Факториал ==="
ast = program(
  function_decl(
    "int",
    "factorial",
    ["int n"],
    block(
      if_stmt(
        binary("<=", id("n"), int(1)),
        block(return_stmt(int(1))),
        block(
          return_stmt(
            binary("*",
              id("n"),
              call(id("factorial"), binary("-", id("n"), int(1)))
            )
          )
        )
      )
    )
  )
)
puts ast.to_source
puts

# Пример 4: For loop
puts "=== Пример 4: For loop ==="
ast = program(
  function_decl(
    "void",
    "count",
    [],
    block(
      for_stmt(
        binary("=", id("i"), int(0)),
        binary("<", id("i"), int(10)),
        unary_post("++", id("i")),
        block(
          expr_stmt(
            call(id("printf"), string('"i = %d\\n"'), id("i"))
          )
        )
      )
    )
  )
)
puts ast.to_source
puts

# Пример 5: Roundtrip тест
puts "=== Пример 5: Roundtrip test ==="
original_ast = program(
  var_decl("int", "x = 42"),
  expr_stmt(call(id("foo"), id("x")))
)

cpp_code = original_ast.to_source
puts "Generated C++:"
puts cpp_code
puts

parsed_ast = CppAst.parse(cpp_code)
roundtrip_code = parsed_ast.to_source

puts "After roundtrip:"
puts roundtrip_code

if cpp_code == roundtrip_code
  puts "✓ Roundtrip успешен!"
else
  puts "✗ Roundtrip failed"
end

