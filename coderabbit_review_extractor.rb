#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'sqlite3'
require 'fileutils'

class CodeRabbitReviewExtractor
  def initialize
    @cursor_config_path = File.expand_path('~/.config/Cursor')
    @output_dir = './coderabbit_reviews'
    @project_path = File.expand_path('.')
  end

  def extract_current_reviews
    puts "🔍 Поиск ревью CodeRabbit для проекта cpp_ast_v3..."
    
    ensure_output_dir
    
    # Находим workspace с данными для этого проекта
    workspace_data = find_project_workspace
    return unless workspace_data
    
    puts "📁 Найден workspace: #{workspace_data[:workspace]}"
    
    # Извлекаем ревью
    reviews = extract_reviews_from_workspace(workspace_data)
    
    if reviews.empty?
      puts "❌ Ревью не найдены"
      return
    end
    
    # Сохраняем данные
    save_reviews(reviews)
    
    puts "✅ Извлечено #{reviews.length} ревью"
    puts "📊 Файлов с комментариями: #{reviews.sum { |r| r[:files].length }}"
    puts "💾 Данные сохранены в: #{@output_dir}"
  end

  private

  def ensure_output_dir
    FileUtils.mkdir_p(@output_dir)
  end

  def find_project_workspace
    workspace_storage_path = File.join(@cursor_config_path, 'User/workspaceStorage')
    return unless Dir.exist?(workspace_storage_path)
    
    puts "🔍 Проверяем workspace..."
    
    # Сначала ищем workspace с ревью
    target_workspace = '957963f823d0a5e29d83475bf997e5d3'
    db_path = File.join(workspace_storage_path, target_workspace, 'state.vscdb')
    
    if File.exist?(db_path)
      puts "  Проверяем целевой workspace: #{target_workspace}"
      if workspace_contains_project?(db_path)
        puts "✅ Найден подходящий workspace: #{target_workspace}"
        return {
          workspace: target_workspace,
          db_path: db_path,
          workspace_path: File.join(workspace_storage_path, target_workspace)
        }
      end
    end
    
    # Если целевой workspace не найден, ищем в других
    Dir.entries(workspace_storage_path).each do |entry|
      next if entry.start_with?('.')
      next if entry == target_workspace # Уже проверили
      
      db_path = File.join(workspace_storage_path, entry, 'state.vscdb')
      next unless File.exist?(db_path)
      
      puts "  Проверяем workspace: #{entry}"
      
      # Проверяем, содержит ли база данные для нашего проекта
      if workspace_contains_project?(db_path)
        puts "✅ Найден подходящий workspace: #{entry}"
        return {
          workspace: entry,
          db_path: db_path,
          workspace_path: File.join(workspace_storage_path, entry)
        }
      end
    end
    
    puts "❌ Подходящий workspace не найден"
    nil
  end

  def workspace_contains_project?(db_path)
    begin
      db = SQLite3::Database.new(db_path)
      
      # Получаем данные CodeRabbit
      result = db.execute(
        "SELECT value FROM ItemTable WHERE key = 'coderabbit.coderabbit-vscode'"
      )
      
      db.close
      
      if result.length > 0
        data = JSON.parse(result.first.first)
        # Ищем ключи, связанные с нашим проектом
        project_keys = data.keys.select { |key| key.include?('cpp_ast_v3') }
        
        if !project_keys.empty?
          puts "    Найдены ключи проекта: #{project_keys.join(', ')}"
          return true
        end
      end
      
      false
    rescue => e
      puts "⚠️  Ошибка при проверке базы #{db_path}: #{e.message}"
      false
    end
  end

  def extract_reviews_from_workspace(workspace_data)
    begin
      db = SQLite3::Database.new(workspace_data[:db_path])
      
      # Получаем данные CodeRabbit
      result = db.execute(
        "SELECT value FROM ItemTable WHERE key = 'coderabbit.coderabbit-vscode'"
      )
      
      db.close
      
      return [] if result.empty?
      
      data = JSON.parse(result.first.first)
      
      # Ищем ревью для нашего проекта
      project_reviews = find_project_reviews(data)
      
      project_reviews.map do |review|
        {
          id: review['id'],
          status: review['status'],
          started_at: review['startedAt'],
          ended_at: review['endedAt'],
          title: review['title'],
          files: extract_file_comments(review['fileReviewMap'] || {})
        }
      end
    rescue => e
      puts "⚠️  Ошибка при извлечении ревью: #{e.message}"
      []
    end
  end

  def find_project_reviews(data)
    reviews = []
    
    # Ищем ключи с ревью для нашего проекта
    data.each do |key, value|
      if key.include?('cpp_ast_v3') && key.include?('reviews') && value.is_a?(Array)
        puts "📋 Найдены ревью в ключе: #{key} (#{value.length} ревью)"
        reviews.concat(value)
      end
    end
    
    puts "📊 Всего найдено ревью: #{reviews.length}"
    reviews
  end

  def extract_file_comments(file_review_map)
    file_comments = []
    
    file_review_map.each do |filename, file_data|
      next unless file_data['comments']
      
      comments = file_data['comments'].map do |comment|
        {
          filename: comment['filename'],
          start_line: comment['startLine'],
          end_line: comment['endLine'],
          type: comment['type'],
          severity: comment['severity'],
          comment: comment['comment'],
          codegen_instructions: comment['codegenInstructions'],
          suggestions: comment['suggestions'] || [],
          analysis: comment['analysis'],
          tool_outputs: comment['toolOutputs'] || {}
        }
      end
      
      file_comments << {
        filename: filename,
        comments: comments,
        comment_count: comments.length
      }
    end
    
    file_comments
  end

  def save_reviews(reviews)
    # Сохраняем полные данные
    File.write(
      File.join(@output_dir, 'full_reviews.json'),
      JSON.pretty_generate(reviews)
    )
    
    # Создаем сводку для агента
    summary = create_agent_summary(reviews)
    File.write(
      File.join(@output_dir, 'agent_summary.json'),
      JSON.pretty_generate(summary)
    )
    
    # Создаем читаемый отчет
    create_readable_report(reviews)
  end

  def create_agent_summary(reviews)
    {
      project: 'cpp_ast_v3',
      total_reviews: reviews.length,
      total_files: reviews.sum { |r| r[:files].length },
      total_comments: reviews.sum { |r| r[:files].sum { |f| f[:comment_count] } },
      reviews: reviews.map do |review|
        {
          id: review[:id],
          status: review[:status],
          title: review[:title],
          files_with_issues: review[:files].select { |f| f[:comment_count] > 0 }.map do |file|
            {
              filename: file[:filename],
              comment_count: file[:comment_count],
              critical_issues: file[:comments].count { |c| c[:severity] == 'critical' },
              major_issues: file[:comments].count { |c| c[:severity] == 'major' },
              actionable_items: file[:comments].count { |c| c[:type] == 'actionable' }
            }
          end
        }
      end
    }
  end

  def create_readable_report(reviews)
    report = []
    report << "# CodeRabbit Review Report for cpp_ast_v3"
    report << "Generated: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
    report << ""
    
    reviews.each_with_index do |review, index|
      report << "## Review #{index + 1}: #{review[:title]}"
      report << "- **Status**: #{review[:status]}"
      report << "- **Started**: #{review[:started_at]}"
      report << "- **Ended**: #{review[:ended_at]}"
      report << ""
      
      review[:files].each do |file|
        next if file[:comment_count] == 0
        
        report << "### #{file[:filename]} (#{file[:comment_count]} comments)"
        report << ""
        
        file[:comments].each_with_index do |comment, comment_index|
          report << "#### Comment #{comment_index + 1} (Lines #{comment[:start_line]}-#{comment[:end_line]})"
          report << "- **Type**: #{comment[:type]}"
          report << "- **Severity**: #{comment[:severity] || 'none'}"
          report << ""
          report << "**Comment:**"
          report << "```"
          report << comment[:comment]
          report << "```"
          report << ""
          
          if comment[:codegen_instructions] && !comment[:codegen_instructions].empty?
            report << "**Code Generation Instructions:**"
            report << "```"
            report << comment[:codegen_instructions]
            report << "```"
            report << ""
          end
          
          if comment[:suggestions] && !comment[:suggestions].empty?
            report << "**Suggestions:**"
            comment[:suggestions].each do |suggestion|
              report << "- #{suggestion}"
            end
            report << ""
          end
        end
      end
    end
    
    File.write(File.join(@output_dir, 'review_report.md'), report.join("\n"))
  end
end

# Запуск
if __FILE__ == $0
  extractor = CodeRabbitReviewExtractor.new
  extractor.extract_current_reviews
end
