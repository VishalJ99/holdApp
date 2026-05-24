#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"

ROOT = File.expand_path("..", __dir__)

EXPECTED_FILES = {
  "app-store-assets/screenshots/hold-iphone-65.png" => { width: 1242, height: 2688, alpha: "no" },
  "app-store-assets/screenshots/hold-ipad-129.png" => { width: 2048, height: 2732, alpha: "no" },
  "app-store-assets/screenshots/hold-mac-desktop.png" => { width: 2880, height: 1800, alpha: "no" },
  "HoldApp-iOS/Assets.xcassets/AppIcon.appiconset/AppIcon~ios-marketing.png" => { width: 1024, height: 1024, alpha: "no" },
  "HoldApp/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png" => { width: 1024, height: 1024, alpha: "no" },
  "HoldApp/Assets.xcassets/hold_icon.imageset/hold_icon.png" => { width: 176, height: 176, alpha: "yes" }
}.freeze

ICON_SETS = [
  "HoldApp-iOS/Assets.xcassets/AppIcon.appiconset",
  "HoldApp/Assets.xcassets/AppIcon.appiconset"
].freeze

def fail_with(message)
  warn "ERROR: #{message}"
  exit 1
end

def image_info(path)
  stdout, stderr, status = Open3.capture3("sips", "-g", "pixelWidth", "-g", "pixelHeight", "-g", "hasAlpha", path)
  fail_with("sips failed for #{path}: #{stderr.strip}") unless status.success?

  {
    width: stdout[/pixelWidth:\s+(\d+)/, 1].to_i,
    height: stdout[/pixelHeight:\s+(\d+)/, 1].to_i,
    alpha: stdout[/hasAlpha:\s+(\w+)/, 1]
  }
end

def expected_icon_pixels(entry)
  size = entry.fetch("size").split("x").first.to_f
  scale = entry.fetch("scale").delete_suffix("x").to_f
  (size * scale).round
end

errors = []

EXPECTED_FILES.each do |relative_path, expected|
  path = File.join(ROOT, relative_path)
  if !File.file?(path)
    errors << "missing #{relative_path}"
    next
  end

  actual = image_info(path)
  errors << "#{relative_path} width #{actual[:width]} != #{expected[:width]}" unless actual[:width] == expected[:width]
  errors << "#{relative_path} height #{actual[:height]} != #{expected[:height]}" unless actual[:height] == expected[:height]
  errors << "#{relative_path} alpha #{actual[:alpha]} != #{expected[:alpha]}" unless actual[:alpha] == expected[:alpha]
end

ICON_SETS.each do |relative_icon_set|
  icon_set = File.join(ROOT, relative_icon_set)
  contents_path = File.join(icon_set, "Contents.json")
  data = JSON.parse(File.read(contents_path))

  data.fetch("images").each do |entry|
    filename = entry["filename"]
    next unless filename

    image_path = File.join(icon_set, filename)
    if !File.file?(image_path)
      errors << "missing #{File.join(relative_icon_set, filename)}"
      next
    end

    actual = image_info(image_path)
    expected_pixels = expected_icon_pixels(entry)
    relative_image_path = File.join(relative_icon_set, filename)
    errors << "#{relative_image_path} width #{actual[:width]} != #{expected_pixels}" unless actual[:width] == expected_pixels
    errors << "#{relative_image_path} height #{actual[:height]} != #{expected_pixels}" unless actual[:height] == expected_pixels
  end
end

if errors.any?
  errors.each { |error| warn "ERROR: #{error}" }
  exit 1
end

puts "App Store asset validation passed."
puts "Checked #{EXPECTED_FILES.length} key files and #{ICON_SETS.length} app icon sets."
