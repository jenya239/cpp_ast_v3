require 'cpp_ast'

gtk_project = "/home/jenya/workspaces/experimental/gtk-gl-cpp-2025"
files = Dir["#{gtk_project}/include/**/*.hpp"] + Dir["#{gtk_project}/src/**/*.cpp"]

puts "Всего файлов: #{files.size}"
puts "\nПроверка парсинга...\n"

success = []
failures = []

files.sort.each do |file|
  name = file.sub("#{gtk_project}/", "")
  begin
    source = File.read(file)
    program = CppAst.parse(source)
    output = program.to_source
    
    if source == output
      puts "✅ #{name}"
      success << name
    else
      puts "⚠️  #{name} (roundtrip mismatch)"
      failures << {file: name, reason: "roundtrip"}
    end
  rescue => e
    puts "❌ #{name}: #{e.class.name}"
    failures << {file: name, reason: e.class.name}
  end
end

puts "\n" + "="*60
puts "Результаты:"
puts "✅ Успешно: #{success.size}/#{files.size}"
puts "❌ Ошибки: #{failures.size}/#{files.size}"
puts "Покрытие: #{(success.size.to_f / files.size * 100).round(1)}%"

if failures.any?
  puts "\nНе парсятся:"
  failures.each { |f| puts "  - #{f[:file]} (#{f[:reason]})" }
end
