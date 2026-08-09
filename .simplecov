SimpleCov.start do
  root Dir.pwd
  coverage_dir ENV.fetch("COVERAGE_DIR", "coverage")
  track_files "bin/*"
  track_files "scripts/*"
  add_filter "/tests/"
  add_filter "/coverage/"
end
