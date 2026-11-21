# frozen_string_literal: true

module Payments
  # Reads and merge-updates a dotenv-style file. Only the keys it is given change; every other line,
  # comment and blank line stays as it is. The file is left with mode 600.
  class EnvFile
    LINE = /\A\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)\z/

    def initialize(path)
      @path = path.to_s
    end

    def read
      return {} unless File.exist?(@path)

      File.readlines(@path, chomp: true).each_with_object({}) do |line, values|
        match = LINE.match(line)
        values[match[1]] = match[2].strip.delete_prefix('"').delete_suffix('"') if match
      end
    end

    # Returns the names of the keys it wrote, never the values.
    def merge!(values)
      lines = File.exist?(@path) ? File.readlines(@path, chomp: true) : []
      pending = values.transform_keys(&:to_s)

      lines = lines.map do |line|
        name = LINE.match(line)&.captures&.first
        name && pending.key?(name) ? "#{name}=#{pending.delete(name)}" : line
      end
      pending.each { |name, value| lines << "#{name}=#{value}" }

      File.write(@path, "#{lines.join("\n")}\n")
      File.chmod(0o600, @path)
      values.keys.map(&:to_s)
    end
  end
end
