# frozen_string_literal: true

module CppAst
  module Builder
    # DSL Compilation Cache - Phase 4
    class Cache
      def initialize
        @cache = {}
        @hit_count = 0
        @miss_count = 0
      end
      
      def get(key)
        if @cache.key?(key)
          @hit_count += 1
          @cache[key]
        else
          @miss_count += 1
          nil
        end
      end
      
      def set(key, value)
        @cache[key] = value
      end
      
      def clear
        @cache.clear
        @hit_count = 0
        @miss_count = 0
      end
      
      def stats
        {
          size: @cache.size,
          hit_count: @hit_count,
          miss_count: @miss_count,
          hit_rate: @hit_count.to_f / (@hit_count + @miss_count)
        }
      end
      
      def memory_usage
        @cache.values.sum(&:object_id)
      end
    end
    
    # DSL Compilation Optimizer - Phase 4
    class Optimizer
      def initialize
        @cache = Cache.new
        @compilation_stats = {
          total_compilations: 0,
          cached_compilations: 0,
          average_time: 0.0
        }
      end
      
      def compile_with_cache(dsl_code, &block)
        start_time = Time.now
        
        # Always increment total compilations
        @compilation_stats[:total_compilations] += 1
        
        # Generate cache key from DSL code
        cache_key = generate_cache_key(dsl_code)
        
        # Try to get from cache
        cached_result = @cache.get(cache_key)
        if cached_result
          @compilation_stats[:cached_compilations] += 1
          compilation_time = Time.now - start_time
          @compilation_stats[:average_time] = 
            (@compilation_stats[:average_time] * (@compilation_stats[:total_compilations] - 1) + compilation_time) / 
            @compilation_stats[:total_compilations]
          return cached_result
        end
        
        # Compile DSL code
        result = block.call(dsl_code)
        
        # Cache the result
        @cache.set(cache_key, result)
        
        # Update stats
        compilation_time = Time.now - start_time
        @compilation_stats[:average_time] = 
          (@compilation_stats[:average_time] * (@compilation_stats[:total_compilations] - 1) + compilation_time) / 
          @compilation_stats[:total_compilations]
        
        result
      end
      
      def stats
        {
          cache: @cache.stats,
          compilation: @compilation_stats
        }
      end
      
      def clear_cache
        @cache.clear
      end
      
      private
      
      def generate_cache_key(dsl_code)
        # Simple hash-based cache key
        dsl_code.to_s.hash
      end
    end
    
    # DSL Builder with Performance Optimization - Phase 4
    class OptimizedDSL
      include DSL
      
      def initialize
        @optimizer = Optimizer.new
      end
      
      def compile(dsl_code)
        @optimizer.compile_with_cache(dsl_code) do |code|
          # Parse and compile DSL code
          # For now, just return the code as string
          # In real implementation, this would parse and compile DSL
          code
        end
      end
      
      def stats
        @optimizer.stats
      end
      
      def clear_cache
        @optimizer.clear_cache
      end
    end
  end
end
