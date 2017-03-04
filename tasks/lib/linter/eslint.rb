# encoding: UTF-8

require "execjs"
require "multi_json"
require 'tempfile'

module Eslintrb

    class Lint
    Error = ExecJS::Error

    # Default options for compilation
    DEFAULTS = {
      rules: {
        'no-bitwise' => 2,
        'curly' => 2,
        'eqeqeq' => 2,
        'guard-for-in' => 2,
        'no-use-before-define' => 2,
        'no-caller' => 2,
        'no-new-func' => 2,
        'no-plusplus' => 2,
        'no-undef' => 2,
        'strict' => 2,
        'comma-dangle' => 2
      },
      env: {
        'browser' => true
      }
    }

    SourcePath = File.expand_path("../js/eslint.js", __FILE__)

    def initialize(options = nil, globals = nil)

      if options == :defaults then
        @options = DEFAULTS.dup
      elsif options == :eslintrc then
        raise '`.eslintrc` is not exist on current working directory.' unless File.exist?('./.eslintrc')
        @options = MultiJson.load(File.read('./.eslintrc'))
      elsif options.instance_of? Hash then
        @options = options.dup
        # @options = DEFAULTS.merge(options)
      elsif options.nil?
        @options = nil
      else
        raise 'Unsupported option for Eslintrb: ' + options.to_s
      end

      @globals = globals

      @context = ExecJS.compile("var window = {}; \n" + File.open(SourcePath, "r:UTF-8").read)
    end

    def lint(source)
      source = source.respond_to?(:read) ? source.read : source.to_s

      js = ["var errors;"]
      if @options.nil? and @globals.nil? then
        js << "errors = window.eslint.verify(#{MultiJson.dump(source)}, {});"
      elsif @globals.nil? then
        js << "errors = window.eslint.verify(#{MultiJson.dump(source)}, #{MultiJson.dump(@options)});"
      else
        globals_hash = Hash[*@globals.product([false]).flatten]
        @options = @options.merge({globals: globals_hash})
        js << "errors = window.eslint.verify(#{MultiJson.dump(source)}, #{MultiJson.dump(@options)});"
      end
      js << "return errors;"

      @context.exec js.join("\n")
    end

    def fix(source)
      source = source.respond_to?(:read) ? source.read : source.to_s

      # The eslint fix command only works on files. Create a temporary one.
      file = Tempfile.new('temp')
      file.write(source)
      file.flush
      #js = "return window.eslint.verify(#{MultiJson.dump(source)}, #{MultiJson.dump(@options)}, '#{file.path}', true);"
      js = "return window.eslint.verify(#{MultiJson.dump(source)}, #{MultiJson.dump(@options)}, 'invalid', true);"

      # if @options.nil? and @globals.nil? then
      #   js = "return window.eslint.fix(#{MultiJson.dump(source)}, {});"
      # elsif @globals.nil? then
      #   js = "return window.eslint.fix(#{MultiJson.dump(source)}, #{MultiJson.dump(@options)});"
      # else
      #   globals_hash = Hash[*@globals.product([false]).flatten]
      #   @options = @options.merge({globals: globals_hash})
      #   js = "return window.eslint.fix(#{MultiJson.dump(source)}, #{MultiJson.dump(@options)});"
      # end

      @context.exec js
      file.rewind
      puts source
      out = file.read
      puts out
      return out
    end
  end
end
