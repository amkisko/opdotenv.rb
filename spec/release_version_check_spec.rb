# frozen_string_literal: true

require "spec_helper"
require "stringio"
require "tmpdir"
require_relative "../usr/lib/release_version_check"

RSpec.describe ReleaseVersionCheck do
  describe ".confirm_release?" do
    it "declines when input is closed" do
      expect(described_class.confirm_release?(input: StringIO.new)).to be false
    end

    it "accepts an entered default answer" do
      expect(described_class.confirm_release?(input: StringIO.new("\n"))).to be true
    end

    it "accepts a lowercase confirmation" do
      expect(described_class.confirm_release?(input: StringIO.new("y\n"))).to be true
    end

    it "declines a negative answer" do
      expect(described_class.confirm_release?(input: StringIO.new("n\n"))).to be false
    end
  end

  describe ".changelog_includes_version?" do
    def write_changelog(body)
      path = File.join(Dir.mktmpdir, "CHANGELOG.md")
      File.write(path, body)
      path
    end

    it "accepts plain and Keep a Changelog version headings" do
      path = write_changelog(<<~MD)
        # CHANGELOG

        ## 1.0.6 (2026-11-03)
        ## [1.0.5] - 2026-07-06
      MD

      expect(described_class.changelog_includes_version?("1.0.6", path: path)).to be(true)
      expect(described_class.changelog_includes_version?("1.0.5", path: path)).to be(true)
    end

    it "rejects missing versions and Unreleased headings" do
      path = write_changelog(<<~MD)
        # CHANGELOG

        ## Unreleased
        ## 1.0.6 (Unreleased)
        ## 1.0.5 (2026-07-06)
      MD

      expect(described_class.changelog_includes_version?("1.0.6", path: path)).to be(false)
      expect(described_class.changelog_includes_version?("9.9.9", path: path)).to be(false)
      expect(described_class.changelog_includes_version?("1.0.5", path: path)).to be(true)
    end
  end

  describe ".require_changelog_version!" do
    it "aborts when the changelog file is missing" do
      expect {
        described_class.require_changelog_version!(version: "1.0.6", path: "tmp/missing-changelog.md")
      }.to raise_error(SystemExit)
    end

    it "aborts when the version heading is absent" do
      path = File.join(Dir.mktmpdir, "CHANGELOG.md")
      File.write(path, "# CHANGELOG\n\n## 1.0.0\n")

      expect {
        described_class.require_changelog_version!(version: "1.0.6", path: path)
      }.to raise_error(SystemExit)
    end

    it "returns when the version heading is present" do
      path = File.join(Dir.mktmpdir, "CHANGELOG.md")
      File.write(path, "# CHANGELOG\n\n## 1.0.6 (2026-11-03)\n")

      expect {
        described_class.require_changelog_version!(version: "1.0.6", path: path)
      }.not_to raise_error
    end
  end
end
