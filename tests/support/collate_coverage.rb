# frozen_string_literal: true

require "json"
require "pathname"
require "simplecov"

root_arg, output_arg, command_name, *resultsets = ARGV
abort "Usage: collate_coverage.rb ROOT OUTPUT COMMAND RESULTSET..." unless resultsets.any?

root = Pathname.new(root_arg).realpath
output = Pathname.new(output_arg).realpath
abort "coverage output must stay beneath the project root" unless output.to_s.start_with?("#{root}/")

resultsets.each do |resultset|
  path = Pathname.new(resultset)
  abort "coverage partition is missing: #{path}" unless path.file? && !path.symlink?
end

SimpleCov.collate(resultsets, nil, ignore_timeout: true) do
  root root.to_s
  coverage_dir output.to_s
  track_files "bin/*"
  track_files "scripts/*"
  add_filter "/tests/"
  add_filter "/coverage/"
end

resultset = output.join(".resultset.json")
data = JSON.parse(resultset.read)
abort "collated coverage must contain exactly one result" unless data.one?

temporary = output.join(".resultset.json.collated")
temporary.open("w", 0o600) do |file|
  file.write(JSON.pretty_generate(command_name => data.values.fetch(0)))
  file.write("\n")
  file.flush
  file.fsync
end
temporary.rename(resultset)
