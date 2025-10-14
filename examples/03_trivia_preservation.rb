#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/cpp_ast"

puts "=" * 80
puts "Демонстрация: Trivia в токенах"
puts "=" * 80
puts

# Пример 1: Простой код с пробелами
puts "=== Пример 1: Базовые trivia ==="
code1 = "int x = 42;"
puts "Код: #{code1.inspect}"
puts

lexer1 = CppAst::Lexer.new(code1)
tokens1 = lexer1.tokenize

puts "Токены с trivia:"
tokens1[0..-2].each do |token|
  puts "  #{token.kind}: '#{token.lexeme}'"
  puts "    leading:  #{token.leading_trivia.inspect}"
  puts "    trailing: #{token.trailing_trivia.inspect}"
end
puts

# Пример 2: Комментарии
puts "=== Пример 2: Комментарии ==="
code2 = "x = 42; // ответ\n"
puts "Код: #{code2.inspect}"
puts

lexer2 = CppAst::Lexer.new(code2)
tokens2 = lexer2.tokenize

puts "Токены с trivia:"
tokens2[0..-2].each do |token|
  puts "  #{token.kind}: '#{token.lexeme}'"
  puts "    leading:  #{token.leading_trivia.inspect}"
  puts "    trailing: #{token.trailing_trivia.inspect}"
end
puts

# Пример 3: Preprocessor директивы
puts "=== Пример 3: Preprocessor ==="
code3 = "#include <iostream>\nint main(){}"
puts "Код: #{code3.inspect}"
puts

lexer3 = CppAst::Lexer.new(code3)
tokens3 = lexer3.tokenize

puts "Токены с trivia:"
tokens3[0..-2].each do |token|
  puts "  #{token.kind}: '#{token.lexeme}'"
  puts "    leading:  #{token.leading_trivia.inspect}"
  puts "    trailing: #{token.trailing_trivia.inspect}"
end
puts

# Пример 4: Проверка roundtrip
puts "=== Пример 4: Roundtrip проверка ==="
code4 = "  int x = 42; // comment\n"
puts "Оригинал: #{code4.inspect}"
puts

# Reconstruct from tokens
lexer4 = CppAst::Lexer.new(code4)
tokens4 = lexer4.tokenize

reconstructed = tokens4[0..-2].map do |token|
  token.leading_trivia + token.lexeme + token.trailing_trivia
end.join
reconstructed += tokens4[-1].leading_trivia  # EOF leading

puts "Восстановлен из токенов: #{reconstructed.inspect}"
puts "Идентичны: #{code4 == reconstructed ? '✓ Да' : '✗ Нет'}"
puts

# Пример 5: Сложный пример с вложенными триvia
puts "=== Пример 5: Сложный случай ==="
code5 = <<~CPP
  // Header
  int factorial(int n){
    return n <= 1 ? 1 : n * factorial(n - 1);
  }
CPP

puts "Код:"
puts code5
puts

program = CppAst.parse(code5)
output = program.to_source

puts "Roundtrip:"
puts output
puts

puts "Результат: #{code5 == output ? '✓ Perfect roundtrip!' : '✗ Mismatch'}"
puts

puts "=" * 80
puts "Ключевые преимущества \"Trivia в токенах\":"
puts "✓ Токены самодостаточны - содержат всю информацию о whitespace"
puts "✓ Упрощение парсера - не нужно вручную собирать trivia"
puts "✓ Lossless parsing - 100% точное восстановление исходного кода"
puts "✓ Подготовка к AST редактированию и трансформациям"
puts "=" * 80

