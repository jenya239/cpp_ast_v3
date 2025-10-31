# frozen_string_literal: true

# XQR Language - Alias for MLC
# This file provides the XQR language interface as an alias for MLC

require_relative "mlc"

# Alias MLC as XQR
module XQR
  # Re-export all MLC functionality
  include MLC
  
  # XQR-specific extensions can be added here
  module Extensions
    # XQR-specific language features
    # These can extend MLC with additional syntax or features
  end
end

# Make XQR available as the main module
module XQR
  class << self
    # Delegate all MLC methods to XQR
    def method_missing(method_name, *args, &block)
      MLC.send(method_name, *args, &block)
    end
    
    def respond_to_missing?(method_name, include_private = false)
      MLC.respond_to?(method_name, include_private)
    end
  end
end
