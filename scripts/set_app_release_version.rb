#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"

ROOT = File.expand_path("..", __dir__)
PROJECT_FILE = File.join(ROOT, "HoldApp.xcodeproj/project.pbxproj")
APP_BUNDLE_ID = "com.vishaljain.HoldApp"

options = {
  apply: false,
  ios_build: nil,
  macos_build: nil,
  version: nil
}

OptionParser.new do |parser|
  parser.banner = "Usage: ruby scripts/set_app_release_version.rb --version VERSION [options]"
  parser.on("--version VERSION", "Set MARKETING_VERSION on iOS and macOS app targets") { |value| options[:version] = value }
  parser.on("--ios-build BUILD", "Set CURRENT_PROJECT_VERSION for the iOS app target") { |value| options[:ios_build] = value }
  parser.on("--macos-build BUILD", "Set CURRENT_PROJECT_VERSION for the macOS app target") { |value| options[:macos_build] = value }
  parser.on("--apply", "Write the change to HoldApp.xcodeproj/project.pbxproj") { options[:apply] = true }
end.parse!

abort "Missing --version VERSION" unless options[:version]
abort "Invalid marketing version: #{options[:version]}" unless options[:version].match?(/\A\d+(?:\.\d+){0,2}\z/)

[:ios_build, :macos_build].each do |key|
  value = options[key]
  abort "Invalid #{key.to_s.tr("_", "-")}: #{value}" if value && !value.match?(/\A\d+\z/)
end

def setting_value(settings, key)
  settings[/^\t+#{Regexp.escape(key)} = ([^;]+);$/, 1]
end

def replace_setting(settings, key, value)
  old_value = nil
  updated = settings.gsub(/^(\t+#{Regexp.escape(key)} = )([^;]+)(;)$/) do
    old_value = Regexp.last_match(2)
    "#{Regexp.last_match(1)}#{value}#{Regexp.last_match(3)}"
  end

  raise "Missing #{key} in matched app target build settings" unless old_value

  [updated, old_value]
end

def app_platform(settings)
  return nil unless settings.include?("PRODUCT_BUNDLE_IDENTIFIER = #{APP_BUNDLE_ID};")
  return nil unless settings.include?("PRODUCT_NAME = Hold;")
  return "IOS" if settings.include?("SDKROOT = iphoneos;")
  return "MAC_OS" if settings.include?("COMBINE_HIDPI_IMAGES = YES;")

  nil
end

text = File.read(PROJECT_FILE)
matched_counts = Hash.new(0)
actions = []

config_re = /^(\t\t[0-9A-F]+ \/\* (Debug|Release) \*\/ = \{\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = \{\n)(.*?)(\t\t\t\};\n\t\t\tname = (Debug|Release);\n\t\t\};\n)/m

updated_text = text.gsub(config_re) do
  prefix = Regexp.last_match(1)
  comment_name = Regexp.last_match(2)
  settings = Regexp.last_match(3)
  suffix = Regexp.last_match(4)
  config_name = Regexp.last_match(5)

  raise "Build configuration name mismatch: #{comment_name} vs #{config_name}" unless comment_name == config_name

  platform = app_platform(settings)
  next "#{prefix}#{settings}#{suffix}" unless platform

  matched_counts[platform] += 1
  build_key = platform == "IOS" ? :ios_build : :macos_build
  current_build = setting_value(settings, "CURRENT_PROJECT_VERSION")
  raise "Missing CURRENT_PROJECT_VERSION in #{platform} #{config_name}" unless current_build

  new_settings, old_version = replace_setting(settings, "MARKETING_VERSION", options[:version])
  old_build = current_build
  new_build = options[build_key] || current_build
  if options[build_key]
    new_settings, old_build = replace_setting(new_settings, "CURRENT_PROJECT_VERSION", options[build_key])
  end

  actions << {
    platform: platform,
    config: config_name,
    old_version: old_version,
    new_version: options[:version],
    old_build: old_build,
    new_build: new_build
  }

  "#{prefix}#{new_settings}#{suffix}"
end

expected_counts = { "IOS" => 2, "MAC_OS" => 2 }
unless expected_counts.all? { |platform, count| matched_counts[platform] == count }
  observed = expected_counts.keys.map { |platform| "#{platform}=#{matched_counts[platform]}" }.join(", ")
  abort "Expected two iOS and two macOS app target configurations, observed #{observed}"
end

actions.each do |action|
  label = action[:platform] == "IOS" ? "iOS" : "macOS"
  puts "#{label} #{action[:config]} MARKETING_VERSION #{action[:old_version]} -> #{action[:new_version]}, " \
       "CURRENT_PROJECT_VERSION #{action[:old_build]} -> #{action[:new_build]}"
end

if updated_text == text
  puts "No project changes needed."
elsif options[:apply]
  File.write(PROJECT_FILE, updated_text)
  puts "Updated #{PROJECT_FILE}"
else
  puts "Dry run only. Pass --apply to update #{PROJECT_FILE}."
end
