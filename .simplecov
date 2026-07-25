SimpleCov.start do
  root Dir.pwd
  coverage_dir ENV.fetch("COVERAGE_DIR", "coverage")
  command_name ENV.fetch("COVERAGE_COMMAND_NAME", "bats-suite")
  track_files "bin/*"
  track_files "scripts/*"
  add_filter "/tests/"
  add_filter "/coverage/"
  minimum_coverage ENV.fetch("COVERAGE_MINIMUM", "90").to_f
end
