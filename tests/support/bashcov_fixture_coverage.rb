# frozen_string_literal: true

require "digest"
require "pathname"
require "bashcov/xtrace"

module BashcovFixtureCoverage
  ROOT = Pathname.new(ENV.fetch("BASHCOV_CANONICAL_ROOT")).realpath
  TEMPORARY_BATS_PATH = %r{(?:\A|/)bats-run-[^/]+/}.freeze

  canonical_paths = [
    *ROOT.glob("bin/*"),
    *ROOT.glob("scripts/*"),
    *ROOT.glob("scripts/lib/*.bash"),
  ].select(&:file?)

  CANONICAL_BY_DIGEST = canonical_paths
    .group_by { |path| Digest::SHA256.file(path).hexdigest }
    .filter_map { |digest, paths| [digest, paths.first] if paths.one? }
    .to_h
    .freeze

  private

  def update_wd_stacks!(pwd, oldpwd)
    @bashcov_fixture_current_pwd = pwd
    super
  end

  def find_script(bash_source)
    source = Pathname.new(bash_source)
    script = source.cleanpath
    direct = source.absolute? ? source : @bashcov_fixture_current_pwd&.join(source)
    script = if direct&.file?
               direct.realpath
             else
               super
             end
    return script unless TEMPORARY_BATS_PATH.match?(script.to_s) && script.file?

    CANONICAL_BY_DIGEST.fetch(Digest::SHA256.file(script).hexdigest, script)
  rescue Errno::EACCES, Errno::ENOENT
    script
  end
end

shell_options = ENV.fetch("SHELLOPTS", "").split(":")
ENV["SHELLOPTS"] = (shell_options | ["functrace"]).join(":")
ENV.delete("BASHCOV_CANONICAL_ROOT")
ENV.delete("RUBYOPT")
Bashcov::Xtrace.prepend(BashcovFixtureCoverage)
