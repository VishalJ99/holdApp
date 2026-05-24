#!/usr/bin/env ruby
# frozen_string_literal: true

require "base64"
require "digest"
require "fileutils"
require "json"
require "net/http"
require "openssl"
require "optparse"
require "time"
require "uri"

ROOT = File.expand_path("..", __dir__)
API_BASE = "https://api.appstoreconnect.apple.com"
DEFAULT_BUNDLE_ID = "com.vishaljain.HoldApp"
DEFAULT_LOCALE = "en-GB"

LISTINGS = {
  "IOS" => {
    label: "iOS",
    file: File.join(ROOT, "app-store-assets/app-store-connect/ios-listing.md")
  },
  "MAC_OS" => {
    label: "macOS",
    file: File.join(ROOT, "app-store-assets/app-store-connect/macos-listing.md")
  }
}.freeze

FIELD_LABELS = {
  "App name" => :name,
  "Category" => :category,
  "Support URL" => :support_url,
  "Privacy Policy URL" => :privacy_policy_url,
  "Copyright" => :copyright,
  "Subtitle" => :subtitle,
  "Promotional text" => :promotional_text,
  "Description" => :description,
  "Keywords" => :keywords,
  "What's new" => :whats_new,
  "Review notes" => :review_notes
}.freeze

ASSET_LABELS = %w[
  Screenshots
  App\ icon
].freeze

SCREENSHOT_DISPLAY_TYPES = {
  "hold-iphone-65.png" => "APP_IPHONE_65",
  "hold-ipad-129.png" => "APP_IPAD_PRO_3GEN_129",
  "hold-mac-desktop.png" => "APP_DESKTOP"
}.freeze

PROJECT_FILE = File.join(ROOT, "HoldApp.xcodeproj/project.pbxproj")

FIELD_LIMITS = {
  name: 30,
  subtitle: 30,
  promotional_text: 170,
  description: 4_000,
  keywords: 100,
  whats_new: 4_000
}.freeze

EDITABLE_VERSION_STATES = %w[
  DEVELOPER_REJECTED
  INVALID_BINARY
  METADATA_REJECTED
  PREPARE_FOR_SUBMISSION
  REJECTED
  WAITING_FOR_EXPORT_COMPLIANCE
].freeze

def base64url(value)
  Base64.urlsafe_encode64(value).delete("=")
end

def fixed_width_int_bytes(value)
  value.to_s(2).rjust(32, "\0")[-32, 32]
end

def der_to_raw_ecdsa_signature(der_signature)
  sequence = OpenSSL::ASN1.decode(der_signature)
  r, s = sequence.value.map(&:value)
  fixed_width_int_bytes(r) + fixed_width_int_bytes(s)
end

def jwt_for(key_id:, issuer_id:, key_path:)
  header = { alg: "ES256", kid: key_id, typ: "JWT" }
  payload = {
    iss: issuer_id,
    exp: Time.now.to_i + (20 * 60),
    aud: "appstoreconnect-v1"
  }

  signing_input = [base64url(header.to_json), base64url(payload.to_json)].join(".")
  key = OpenSSL::PKey::EC.new(File.read(File.expand_path(key_path)))
  digest = OpenSSL::Digest::SHA256.digest(signing_input)
  signature = der_to_raw_ecdsa_signature(key.dsa_sign_asn1(digest))

  [signing_input, base64url(signature)].join(".")
end

class AppStoreConnectClient
  def initialize(token)
    @token = token
  end

  def get(path, query = {})
    request("GET", path, query: query)
  end

  def patch(path, type:, id:, attributes:)
    request(
      "PATCH",
      path,
      body: {
        data: {
          id: id,
          type: type,
          attributes: attributes
        }
      }
    )
  end

  def post(path, type:, attributes:, relationships: {})
    request(
      "POST",
      path,
      body: {
        data: {
          type: type,
          attributes: attributes,
          relationships: relationships
        }
      }
    )
  end

  def delete(path)
    request("DELETE", path)
  end

  def upload(operation, bytes)
    uri = URI(operation.fetch("url"))
    method = operation.fetch("method").upcase
    request = case method
              when "PUT"
                Net::HTTP::Put.new(uri)
              when "POST"
                Net::HTTP::Post.new(uri)
              else
                Net::HTTPGenericRequest.new(method, true, true, uri)
              end

    operation.fetch("requestHeaders", []).each do |header|
      request[header.fetch("name")] = header.fetch("value")
    end
    request.body = bytes

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.request(request)
    end
    return response if response.code.to_i.between?(200, 299)

    raise "Asset upload #{method} #{uri.host} failed with HTTP #{response.code}: #{response.body}"
  end

  private

  def request(method, path, query: {}, body: nil)
    uri = URI("#{API_BASE}#{path}")
    uri.query = URI.encode_www_form(query) unless query.empty?

    request = Object.const_get("Net::HTTP::#{method.capitalize}").new(uri)
    request["Authorization"] = "Bearer #{@token}"
    request["Content-Type"] = "application/json"
    request.body = JSON.generate(body) if body

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    parsed = response.body.to_s.empty? ? {} : JSON.parse(response.body)
    return parsed if response.code.to_i.between?(200, 299)

    message = if parsed["errors"]
                parsed["errors"].map { |error| [error["status"], error["title"], error["detail"]].compact.join(" ") }.join("; ")
              else
                response.body
              end
    raise "App Store Connect #{method} #{uri} failed with HTTP #{response.code}: #{message}"
  end
end

def parse_listing(path)
  text = File.read(path)
  markers = []
  labels = FIELD_LABELS.keys.map { |label| Regexp.escape(label) }.join("|")
  text.to_enum(:scan, /^(#{labels}):\n/).each do
    match = Regexp.last_match
    markers << [FIELD_LABELS.fetch(match[1]), match.begin(0), match.end(0)]
  end

  fields = {}
  markers.each_with_index do |(field, _label_start, value_start), index|
    next_label_start = markers[index + 1] && markers[index + 1][1]
    next_heading = text.match(/^## /, value_start)
    end_pos = [next_label_start, next_heading && next_heading.begin(0)].compact.min || text.length
    fields[field] = text[value_start...end_pos].strip
  end
  fields
end

def parse_asset_references(path)
  lines = File.readlines(path)
  assets = {}
  ASSET_LABELS.each do |label|
    label_index = lines.index { |line| line.chomp == "#{label}:" }
    next unless label_index

    body = []
    lines[(label_index + 1)..-1].to_a.each do |line|
      break if line.start_with?("## ")
      break if line.match?(/^[A-Za-z][A-Za-z ]+:\s*$/)

      body << line
    end

    assets[label] = body.join.scan(/`([^`]+)`/).flatten.map do |relative_path|
      File.expand_path(relative_path, File.dirname(path))
    end
  end
  assets
end

def validate_listing(platform, fields)
  errors = []
  FIELD_LIMITS.each do |field, limit|
    value = fields[field].to_s
    next if value.length <= limit

    errors << "#{platform} #{field} is #{value.length} characters; App Store limit is #{limit}"
  end

  if fields[:keywords].to_s.include?(" ")
    errors << "#{platform} keywords contain spaces; App Store keywords should be comma-separated without spaces"
  end

  required = %i[name subtitle promotional_text description keywords whats_new review_notes support_url privacy_policy_url]
  required.each do |field|
    errors << "#{platform} missing #{field}" if fields[field].to_s.empty?
  end

  errors
end

def validate_assets(platform, assets)
  errors = []
  ASSET_LABELS.each do |label|
    refs = assets.fetch(label, [])
    if refs.empty?
      errors << "#{platform} missing #{label.downcase} asset reference"
      next
    end

    refs.each do |path|
      errors << "#{platform} #{label.downcase} asset does not exist: #{path}" unless File.file?(path)
    end
  end

  assets.fetch("Screenshots", []).each do |path|
    filename = File.basename(path)
    errors << "#{platform} screenshot #{filename} is missing a screenshot display type mapping" unless SCREENSHOT_DISPLAY_TYPES[filename]
  end
  errors
end

def load_listings(platforms)
  platforms.each_with_object({}) do |platform, result|
    file = LISTINGS.fetch(platform).fetch(:file)
    fields = parse_listing(file)
    assets = parse_asset_references(file)
    result[platform] = { fields: fields, assets: assets }
  end
end

def print_local_summary(listings)
  listings.each do |platform, listing|
    fields = listing.fetch(:fields)
    assets = listing.fetch(:assets)
    info = LISTINGS.fetch(platform)
    puts "#{info[:label]} listing from #{info[:file]}"
    puts "  name: #{fields[:name]}"
    puts "  subtitle: #{fields[:subtitle]} (#{fields[:subtitle].to_s.length}/30)"
    puts "  promotional text: #{fields[:promotional_text].to_s.length}/170"
    puts "  description: #{fields[:description].to_s.length}/4000"
    puts "  keywords: #{fields[:keywords].to_s.length}/100"
    puts "  what's new: #{fields[:whats_new].to_s.length}/4000"
    ASSET_LABELS.each do |label|
      puts "  #{label.downcase}: #{assets.fetch(label, []).length} file(s)"
    end
    puts
  end
end

def relationship_ids(resource, relationship_name)
  data = resource.dig("relationships", relationship_name, "data")
  case data
  when Array
    data.map { |item| item.fetch("id") }
  when Hash
    [data.fetch("id")]
  else
    []
  end
end

def included_index(response)
  response.fetch("included", []).each_with_object({}) do |resource, result|
    result[[resource.fetch("type"), resource.fetch("id")]] = resource
  end
end

def find_app(client, app_id:, bundle_id:)
  return app_id if app_id

  response = client.get("/v1/apps", "filter[bundleId]" => bundle_id, "limit" => "10")
  apps = response.fetch("data", [])
  raise "No App Store Connect app found for bundle id #{bundle_id}" if apps.empty?
  if apps.length > 1
    ids = apps.map { |app| "#{app.fetch("id")} #{app.dig("attributes", "name")}" }.join(", ")
    raise "Multiple App Store Connect apps found for #{bundle_id}: #{ids}. Re-run with --app-id."
  end

  app = apps.first
  puts "Found app #{app.dig("attributes", "name")} (#{app.fetch("id")}) for bundle id #{bundle_id}"
  app.fetch("id")
end

def fetch_versions(client, app_id, platform)
  client.get(
    "/v1/apps/#{app_id}/appStoreVersions",
    "filter[platform]" => platform,
    "include" => "appStoreVersionLocalizations,appStoreReviewDetail",
    "fields[appStoreVersions]" => "platform,versionString,appStoreState,appVersionState,createdDate,appStoreVersionLocalizations,appStoreReviewDetail",
    "limit" => "20",
    "limit[appStoreVersionLocalizations]" => "50"
  )
end

def create_app_store_version(client, app_id, platform, version_string)
  client.post(
    "/v1/appStoreVersions",
    type: "appStoreVersions",
    attributes: {
      platform: platform,
      versionString: version_string
    },
    relationships: {
      app: {
        data: {
          type: "apps",
          id: app_id
        }
      }
    }
  ).fetch("data")
end

def create_version_localization(client, version_id, locale, fields)
  client.post(
    "/v1/appStoreVersionLocalizations",
    type: "appStoreVersionLocalizations",
    attributes: version_localization_attributes(fields, false).merge(locale: locale),
    relationships: {
      appStoreVersion: {
        data: {
          type: "appStoreVersions",
          id: version_id
        }
      }
    }
  ).fetch("data")
end

def choose_version(response, platform, explicit_id, apply)
  versions = response.fetch("data", [])
  raise "No #{platform} App Store versions found" if versions.empty?

  if explicit_id
    selected = versions.find { |version| version.fetch("id") == explicit_id }
    raise "No #{platform} App Store version has id #{explicit_id}" unless selected

    return selected
  end

  editable = versions.select do |version|
    attributes = version.fetch("attributes", {})
    EDITABLE_VERSION_STATES.include?(attributes["appStoreState"]) ||
      EDITABLE_VERSION_STATES.include?(attributes["appVersionState"])
  end

  candidates = editable.empty? ? versions : editable
  if apply && candidates.length > 1
    summary = candidates.map do |version|
      attributes = version.fetch("attributes", {})
      "#{version.fetch("id")} v#{attributes["versionString"]} #{attributes["appStoreState"] || attributes["appVersionState"]}"
    end.join(", ")
    raise "Multiple #{platform} versions could be updated: #{summary}. Re-run with --#{platform == "IOS" ? "ios" : "macos"}-version-id."
  end

  candidates.first
end

def find_version_by_string(response, version_string)
  response.fetch("data", []).find do |version|
    version.dig("attributes", "versionString") == version_string
  end
end

def editable_version?(version)
  attributes = version.fetch("attributes", {})
  EDITABLE_VERSION_STATES.include?(attributes["appStoreState"]) ||
    EDITABLE_VERSION_STATES.include?(attributes["appVersionState"])
end

def version_state(version)
  attributes = version.fetch("attributes", {})
  attributes["appStoreState"] || attributes["appVersionState"] || "UNKNOWN"
end

def ensure_apply_allowed!(platform, version, options)
  return unless options[:apply]
  return if editable_version?(version)
  return if options[:promotional_text_only]

  raise "#{platform} version #{version.fetch("id")} is #{version_state(version)}, not editable for full version metadata. " \
        "Create a new editable App Store version, or re-run with --promotional-text-only for the live promotional text field only."
end

def find_localization(response, version, locale)
  index = included_index(response)
  relationship_ids(version, "appStoreVersionLocalizations").map do |id|
    index[["appStoreVersionLocalizations", id]]
  end.compact.find do |localization|
    localization.dig("attributes", "locale") == locale
  end
end

def find_review_detail(response, version)
  index = included_index(response)
  relationship_ids(version, "appStoreReviewDetail").map do |id|
    index[["appStoreReviewDetails", id]]
  end.compact.first
end

def fetch_app_infos(client, app_id)
  client.get(
    "/v1/apps/#{app_id}/appInfos",
    "include" => "appInfoLocalizations",
    "limit" => "20",
    "limit[appInfoLocalizations]" => "50"
  )
end

def fetch_screenshot_sets(client, localization_id)
  client.get(
    "/v1/appStoreVersionLocalizations/#{localization_id}/appScreenshotSets",
    "include" => "appScreenshots",
    "fields[appScreenshotSets]" => "screenshotDisplayType,appScreenshots",
    "fields[appScreenshots]" => "fileName,fileSize,assetDeliveryState,imageAsset",
    "limit" => "50",
    "limit[appScreenshots]" => "50"
  )
end

def screenshot_sets_for_localization(client, localization_id)
  response = fetch_screenshot_sets(client, localization_id)
  index = included_index(response)
  response.fetch("data", []).map do |set|
    screenshot_ids = relationship_ids(set, "appScreenshots")
    {
      resource: set,
      screenshots: screenshot_ids.map { |id| index[["appScreenshots", id]] }.compact
    }
  end
end

def print_screenshot_sets(client, localization_id)
  sets = screenshot_sets_for_localization(client, localization_id)
  if sets.empty?
    puts "      no appScreenshotSets"
    return
  end

  sets.each do |set_info|
    set = set_info.fetch(:resource)
    display_type = set.dig("attributes", "screenshotDisplayType")
    screenshots = set_info.fetch(:screenshots)
    puts "      appScreenshotSet #{set.fetch("id")} displayType=#{display_type} screenshots=#{screenshots.length}"
    screenshots.each do |screenshot|
      attributes = screenshot.fetch("attributes", {})
      state = attributes.dig("assetDeliveryState", "state")
      puts "        appScreenshot #{screenshot.fetch("id")} fileName=#{attributes["fileName"].inspect} fileSize=#{attributes["fileSize"]} state=#{state.inspect}"
    end
  end
end

def create_screenshot_set(client, localization_id, display_type)
  client.post(
    "/v1/appScreenshotSets",
    type: "appScreenshotSets",
    attributes: {
      screenshotDisplayType: display_type
    },
    relationships: {
      appStoreVersionLocalization: {
        data: {
          type: "appStoreVersionLocalizations",
          id: localization_id
        }
      }
    }
  ).fetch("data")
end

def reserve_screenshot(client, set_id, path)
  client.post(
    "/v1/appScreenshots",
    type: "appScreenshots",
    attributes: {
      fileName: File.basename(path),
      fileSize: File.size(path)
    },
    relationships: {
      appScreenshotSet: {
        data: {
          type: "appScreenshotSets",
          id: set_id
        }
      }
    }
  ).fetch("data")
end

def upload_screenshot(client, screenshot, path)
  screenshot.fetch("attributes").fetch("uploadOperations").each do |operation|
    offset = operation.fetch("offset")
    length = operation.fetch("length")
    bytes = File.open(path, "rb") do |file|
      file.seek(offset)
      file.read(length)
    end
    client.upload(operation, bytes)
  end

  checksum = Digest::MD5.file(path).hexdigest
  client.patch(
    "/v1/appScreenshots/#{screenshot.fetch("id")}",
    type: "appScreenshots",
    id: screenshot.fetch("id"),
    attributes: {
      uploaded: true,
      sourceFileChecksum: checksum
    }
  )
end

def delete_screenshot(client, screenshot)
  client.delete("/v1/appScreenshots/#{screenshot.fetch("id")}")
end

def upload_listing_screenshots(client, localization, listing, apply, replace_existing)
  screenshot_paths = listing.fetch(:assets).fetch("Screenshots", [])
  existing_sets = if apply
                    screenshot_sets_for_localization(client, localization.fetch("id"))
                  else
                    []
                  end
  sets_by_type = existing_sets.each_with_object({}) do |set_info, result|
    result[set_info.fetch(:resource).dig("attributes", "screenshotDisplayType")] = set_info
  end

  screenshot_paths.each do |path|
    display_type = SCREENSHOT_DISPLAY_TYPES.fetch(File.basename(path))
    set_info = sets_by_type[display_type]
    if set_info && set_info.fetch(:screenshots).any?
      set_id = set_info.fetch(:resource).fetch("id")
      unless replace_existing
        puts "  existing #{display_type} screenshot set #{set_id} has screenshots; leaving it unchanged"
        next
      end

      puts "  replacing #{set_info.fetch(:screenshots).length} existing screenshot(s) in #{display_type} screenshot set #{set_id}"
      set_info.fetch(:screenshots).each do |screenshot|
        puts "    deleting appScreenshot #{screenshot.fetch("id")}"
        delete_screenshot(client, screenshot) if apply
      end
    end

    if apply
      set = set_info ? set_info.fetch(:resource) : create_screenshot_set(client, localization.fetch("id"), display_type)
      puts "  uploading #{File.basename(path)} to appScreenshotSet #{set.fetch("id")} displayType=#{display_type}"
      screenshot = reserve_screenshot(client, set.fetch("id"), path)
      upload_screenshot(client, screenshot, path)
    else
      replacement_note = replace_existing ? "replace existing screenshots and " : ""
      puts "  would #{replacement_note}create or reuse #{display_type} screenshot set and upload #{File.basename(path)}"
    end
  end
end

def listing_preflight(platform, listing)
  fields = listing.fetch(:fields)
  assets = listing.fetch(:assets)
  {
    platform: platform,
    source: LISTINGS.fetch(platform).fetch(:file),
    fieldLengths: FIELD_LIMITS.each_with_object({}) do |(field, limit), result|
      result[field] = {
        length: fields[field].to_s.length,
        limit: limit
      }
    end,
    screenshots: assets.fetch("Screenshots", []).map do |path|
      {
        path: path,
        fileName: File.basename(path),
        displayType: SCREENSHOT_DISPLAY_TYPES.fetch(File.basename(path)),
        fileSize: File.size(path),
        md5: Digest::MD5.file(path).hexdigest
      }
    end,
    appIcon: assets.fetch("App icon", []).map do |path|
      {
        path: path,
        fileName: File.basename(path),
        fileSize: File.size(path),
        md5: Digest::MD5.file(path).hexdigest
      }
    end
  }
end

def live_versions_preflight(client, app_id, platform)
  response = fetch_versions(client, app_id, platform)
  index = included_index(response)
  response.fetch("data", []).map do |version|
    localizations = relationship_ids(version, "appStoreVersionLocalizations").map do |id|
      localization = index[["appStoreVersionLocalizations", id]]
      next unless localization

      screenshot_sets = screenshot_sets_for_localization(client, id).map do |set_info|
        set = set_info.fetch(:resource)
        {
          id: set.fetch("id"),
          displayType: set.dig("attributes", "screenshotDisplayType"),
          screenshots: set_info.fetch(:screenshots).map do |screenshot|
            attributes = screenshot.fetch("attributes", {})
            {
              id: screenshot.fetch("id"),
              fileName: attributes["fileName"],
              fileSize: attributes["fileSize"],
              state: attributes.dig("assetDeliveryState", "state")
            }
          end
        }
      end

      {
        id: id,
        locale: localization.dig("attributes", "locale"),
        promotionalText: localization.dig("attributes", "promotionalText"),
        screenshotSets: screenshot_sets
      }
    end.compact

    {
      id: version.fetch("id"),
      versionString: version.dig("attributes", "versionString"),
      state: version_state(version),
      editable: editable_version?(version),
      localizations: localizations,
      reviewDetailIds: relationship_ids(version, "appStoreReviewDetail")
    }
  end
end

def planned_actions_for_platform(client, app_id, platform, listing, options)
  actions = []
  return actions unless options[:prepare_version]

  response = fetch_versions(client, app_id, platform)
  target = find_version_by_string(response, options[:prepare_version])
  if target
    actions << {
      action: editable_version?(target) ? "use_editable_version" : "blocked_non_editable_version",
      appStoreVersionId: target.fetch("id"),
      versionString: options[:prepare_version],
      state: version_state(target)
    }

    localization = find_localization(response, target, options[:locale])
    actions << if localization
                 {
                   action: "patch_version_localization",
                   localizationId: localization.fetch("id"),
                   locale: options[:locale]
                 }
               else
                 {
                   action: "create_version_localization",
                   appStoreVersionId: target.fetch("id"),
                   locale: options[:locale]
                 }
               end
  else
    actions << {
      action: "create_app_store_version",
      platform: platform,
      versionString: options[:prepare_version]
    }
    actions << {
      action: "create_version_localization",
      locale: options[:locale],
      dependsOn: "create_app_store_version"
    }
  end

  actions << {
    action: "patch_review_notes_if_review_detail_exists",
    locale: options[:locale]
  }

  if options[:upload_screenshots]
    listing.fetch(:assets).fetch("Screenshots", []).each do |path|
      actions << {
        action: "upload_screenshot",
        fileName: File.basename(path),
        displayType: SCREENSHOT_DISPLAY_TYPES.fetch(File.basename(path)),
        fileSize: File.size(path),
        md5: Digest::MD5.file(path).hexdigest
      }
    end
  end

  actions
end

def extract_build_setting(settings, key)
  value = settings[/^\s*#{Regexp.escape(key)}\s*=\s*(.+?);$/, 1]
  value && value.delete_prefix('"').delete_suffix('"')
end

def local_project_versions
  text = File.read(PROJECT_FILE)
  versions = Hash.new { |hash, key| hash[key] = [] }
  text.scan(%r{/\* (Debug|Release) \*/ = \{\n\s*isa = XCBuildConfiguration;\n\s*buildSettings = \{(.*?)\n\s*\};\n\s*name = (Debug|Release);\n\s*\};}m) do |configuration, settings, _name|
    product_name = extract_build_setting(settings, "PRODUCT_NAME")
    next unless product_name == "Hold"

    platform = if settings.include?("SDKROOT = iphoneos;")
                 "IOS"
               elsif settings.include?("COMBINE_HIDPI_IMAGES = YES;")
                 "MAC_OS"
               end
    next unless platform

    versions[platform] << {
      configuration: configuration,
      marketingVersion: extract_build_setting(settings, "MARKETING_VERSION"),
      buildNumber: extract_build_setting(settings, "CURRENT_PROJECT_VERSION"),
      bundleId: extract_build_setting(settings, "PRODUCT_BUNDLE_IDENTIFIER")
    }
  end
  versions
end

def project_version_warnings(local_versions, target_version)
  return [] unless target_version

  local_versions.flat_map do |platform, configurations|
    configurations.map do |configuration|
      if configuration[:marketingVersion] == target_version
        nil
      else
        "#{platform} #{configuration[:configuration]} MARKETING_VERSION #{configuration[:marketingVersion]} does not match target App Store version #{target_version}"
      end
    end.compact
  end
end

def build_preflight_report(client, app_id, listings, options)
  local_versions = local_project_versions
  {
    generatedAt: Time.now.utc.iso8601,
    app: {
      id: app_id,
      bundleId: options[:bundle_id]
    },
    locale: options[:locale],
    targetVersion: options[:prepare_version],
    uploadScreenshots: options[:upload_screenshots],
    replaceScreenshots: options[:replace_screenshots],
    applyRequiredForMutation: true,
    localProjectVersions: local_versions,
    versionWarnings: project_version_warnings(local_versions, options[:prepare_version]),
    platforms: listings.map do |platform, listing|
      {
        platform: platform,
        listing: listing_preflight(platform, listing),
        liveVersions: live_versions_preflight(client, app_id, platform),
        plannedActions: planned_actions_for_platform(client, app_id, platform, listing, options)
      }
    end
  }
end

def write_preflight_report(path, report)
  expanded = File.expand_path(path)
  FileUtils.mkdir_p(File.dirname(expanded))
  File.write(expanded, JSON.pretty_generate(report) + "\n")
  puts "Wrote preflight report to #{expanded}"
  report.fetch(:versionWarnings, []).each { |warning| warn "WARNING: #{warning}" }
end

def app_info_localizations_for_locale(response, locale)
  index = included_index(response)
  response.fetch("data", []).flat_map do |app_info|
    relationship_ids(app_info, "appInfoLocalizations").map do |id|
      localization = index[["appInfoLocalizations", id]]
      next unless localization
      next unless localization.dig("attributes", "locale") == locale

      [app_info, localization]
    end.compact
  end
end

def version_localization_attributes(fields, promotional_text_only)
  attributes = { promotionalText: fields[:promotional_text] }
  return attributes if promotional_text_only

  attributes.merge(
    description: fields[:description],
    keywords: fields[:keywords],
    supportUrl: fields[:support_url],
    whatsNew: fields[:whats_new]
  )
end

def patch_version_localization(client, localization, fields, apply, promotional_text_only)
  attributes = version_localization_attributes(fields, promotional_text_only)
  scope = promotional_text_only ? "promotional text" : "version metadata"

  puts "  #{apply ? "patching" : "would patch"} #{scope} on appStoreVersionLocalization #{localization.fetch("id")}"
  return unless apply

  client.patch(
    "/v1/appStoreVersionLocalizations/#{localization.fetch("id")}",
    type: "appStoreVersionLocalizations",
    id: localization.fetch("id"),
    attributes: attributes
  )
end

def patch_review_detail(client, review_detail, fields, apply)
  puts "  #{apply ? "patching" : "would patch"} appStoreReviewDetail #{review_detail.fetch("id")}"
  return unless apply

  client.patch(
    "/v1/appStoreReviewDetails/#{review_detail.fetch("id")}",
    type: "appStoreReviewDetails",
    id: review_detail.fetch("id"),
    attributes: {
      notes: fields[:review_notes]
    }
  )
end

def prepare_next_version(client, app_id, platform, listing, options)
  fields = listing.fetch(:fields)
  info = LISTINGS.fetch(platform)
  response = fetch_versions(client, app_id, platform)
  existing = find_version_by_string(response, options[:prepare_version])

  if existing
    version = existing
    puts "#{info[:label]} version #{options[:prepare_version]} already exists as #{version.fetch("id")} #{version_state(version)}"
  elsif options[:apply]
    version = create_app_store_version(client, app_id, platform, options[:prepare_version])
    puts "created #{info[:label]} version #{options[:prepare_version]} as #{version.fetch("id")}"
    response = fetch_versions(client, app_id, platform)
    version = find_version_by_string(response, options[:prepare_version]) || version
  else
    puts "would create #{info[:label]} version #{options[:prepare_version]} for app #{app_id}"
    puts "  would create #{options[:locale]} appStoreVersionLocalization with full staged metadata"
    upload_listing_screenshots(client, { "id" => "(new localization)" }, listing, false, options[:replace_screenshots]) if options[:upload_screenshots]
    return
  end

  unless editable_version?(version)
    raise "#{platform} version #{version.fetch("id")} is #{version_state(version)}, not editable for full metadata."
  end

  response = fetch_versions(client, app_id, platform)
  version = find_version_by_string(response, options[:prepare_version]) || version
  localization = find_localization(response, version, options[:locale])

  if localization
    patch_version_localization(client, localization, fields, options[:apply], false)
  elsif options[:apply]
    created_localization = create_version_localization(client, version.fetch("id"), options[:locale], fields)
    puts "  created appStoreVersionLocalization #{created_localization.fetch("id")} for #{options[:locale]}"
    localization = created_localization
  else
    puts "  would create #{options[:locale]} appStoreVersionLocalization with full staged metadata"
  end

  upload_listing_screenshots(client, localization, listing, options[:apply], options[:replace_screenshots]) if options[:upload_screenshots] && localization

  response = fetch_versions(client, app_id, platform)
  version = find_version_by_string(response, options[:prepare_version]) || version
  review_detail = find_review_detail(response, version)
  if review_detail
    patch_review_detail(client, review_detail, fields, options[:apply])
  else
    puts "  no appStoreReviewDetail relationship found; review notes still need App Store Connect UI/API follow-up"
  end
end

def patch_app_info_localization(client, localization, fields, apply)
  attributes = {
    name: fields[:name],
    subtitle: fields[:subtitle],
    privacyPolicyUrl: fields[:privacy_policy_url]
  }

  puts "  #{apply ? "patching" : "would patch"} appInfoLocalization #{localization.fetch("id")}"
  return unless apply

  client.patch(
    "/v1/appInfoLocalizations/#{localization.fetch("id")}",
    type: "appInfoLocalizations",
    id: localization.fetch("id"),
    attributes: attributes
  )
end

options = {
  app_id: ENV["ASC_APP_ID"],
  bundle_id: ENV.fetch("ASC_BUNDLE_ID", DEFAULT_BUNDLE_ID),
  key_id: ENV["ASC_KEY_ID"],
  issuer_id: ENV["ASC_ISSUER_ID"],
  key_path: ENV["ASC_KEY_PATH"],
  locale: ENV.fetch("ASC_LOCALE", DEFAULT_LOCALE),
  platforms: LISTINGS.keys,
  apply: false,
  inspect_live: false,
  local_check: false,
  prepare_version: ENV["ASC_PREPARE_VERSION"],
  promotional_text_only: false,
  replace_screenshots: false,
  upload_screenshots: false,
  update_app_info: false,
  write_preflight: ENV["ASC_PREFLIGHT_REPORT"],
  version_ids: {
    "IOS" => ENV["ASC_IOS_VERSION_ID"],
    "MAC_OS" => ENV["ASC_MACOS_VERSION_ID"]
  }
}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: ruby scripts/app_store_connect_update.rb [options]"
  opts.on("--key-id KEY_ID", "App Store Connect API key id") { |value| options[:key_id] = value }
  opts.on("--issuer-id ISSUER_ID", "App Store Connect API issuer id") { |value| options[:issuer_id] = value }
  opts.on("--key-path PATH", "Path to AuthKey_KEYID.p8") { |value| options[:key_path] = value }
  opts.on("--app-id APP_ID", "App Store Connect app id") { |value| options[:app_id] = value }
  opts.on("--bundle-id BUNDLE_ID", "Bundle id to find the app record") { |value| options[:bundle_id] = value }
  opts.on("--locale LOCALE", "App Store locale to update, default #{DEFAULT_LOCALE}") { |value| options[:locale] = value }
  opts.on("--platform PLATFORM", "Update IOS, MAC_OS, or both. Can be passed more than once.") do |value|
    options[:platforms] = [] if options[:platforms] == LISTINGS.keys
    value.split(",").each { |platform| options[:platforms] << platform.strip.upcase }
  end
  opts.on("--ios-version-id ID", "Explicit iOS appStoreVersion id") { |value| options[:version_ids]["IOS"] = value }
  opts.on("--macos-version-id ID", "Explicit macOS appStoreVersion id") { |value| options[:version_ids]["MAC_OS"] = value }
  opts.on("--update-app-info", "Also patch app-level name, subtitle, and privacy policy URL when unambiguous") do
    options[:update_app_info] = true
  end
  opts.on("--inspect-live", "List live App Store Connect app/version localization records and exit") do
    options[:inspect_live] = true
  end
  opts.on("--prepare-next-version VERSION", "Create or update an editable App Store version with staged full metadata") do |value|
    options[:prepare_version] = value
  end
  opts.on("--upload-screenshots", "With --prepare-next-version, upload staged screenshots to editable version localizations") do
    options[:upload_screenshots] = true
  end
  opts.on("--replace-screenshots", "With --upload-screenshots, delete existing editable-version screenshots before uploading staged files") do
    options[:replace_screenshots] = true
  end
  opts.on("--write-preflight PATH", "Write a JSON report of live state and planned actions") do |value|
    options[:write_preflight] = value
  end
  opts.on("--promotional-text-only", "Patch only promotional text; useful for READY_FOR_SALE live versions") do
    options[:promotional_text_only] = true
  end
  opts.on("--local-check", "Only parse and validate local listing markdown") { options[:local_check] = true }
  opts.on("--apply", "Patch App Store Connect. Without this flag the script performs a dry run.") { options[:apply] = true }
  opts.on("-h", "--help", "Show help") do
    puts opts
    exit 0
  end
end

parser.parse!

unknown_platforms = options[:platforms] - LISTINGS.keys
raise "Unknown platform(s): #{unknown_platforms.join(", ")}" unless unknown_platforms.empty?
raise "--replace-screenshots requires --upload-screenshots" if options[:replace_screenshots] && !options[:upload_screenshots]
raise "--replace-screenshots requires --prepare-next-version" if options[:replace_screenshots] && !options[:prepare_version]

listings = load_listings(options[:platforms])
validation_errors = listings.flat_map do |platform, listing|
  validate_listing(platform, listing.fetch(:fields)) + validate_assets(platform, listing.fetch(:assets))
end

if validation_errors.any?
  validation_errors.each { |error| warn "ERROR: #{error}" }
  exit 1
end

print_local_summary(listings)
if options[:local_check]
  puts "Local listing validation passed."
  exit 0
end

if options[:key_id].to_s.empty? || options[:issuer_id].to_s.empty?
  raise "Missing App Store Connect credentials. Set ASC_KEY_ID and ASC_ISSUER_ID, or pass --key-id and --issuer-id."
end

options[:key_path] ||= File.expand_path("~/.appstoreconnect/private_keys/AuthKey_#{options[:key_id]}.p8")
unless File.file?(File.expand_path(options[:key_path]))
  raise "Missing private key file at #{options[:key_path]}. Save it locally; do not paste the .p8 contents into chat."
end

puts options[:apply] ? "Applying App Store Connect updates." : "Dry run only. Re-run with --apply to patch App Store Connect."

token = jwt_for(key_id: options[:key_id], issuer_id: options[:issuer_id], key_path: options[:key_path])
client = AppStoreConnectClient.new(token)
app_id = find_app(client, app_id: options[:app_id], bundle_id: options[:bundle_id])

if options[:write_preflight]
  report = build_preflight_report(client, app_id, listings, options)
  write_preflight_report(options[:write_preflight], report)
end

if options[:inspect_live]
  app_info_response = fetch_app_infos(client, app_id)
  app_info_index = included_index(app_info_response)
  puts "App info records:"
  app_info_response.fetch("data", []).each do |app_info|
    puts "  appInfo #{app_info.fetch("id")}"
    relationship_ids(app_info, "appInfoLocalizations").each do |id|
      localization = app_info_index[["appInfoLocalizations", id]]
      next unless localization

      attributes = localization.fetch("attributes", {})
      puts "    appInfoLocalization #{id} locale=#{attributes["locale"]} name=#{attributes["name"].inspect} subtitle=#{attributes["subtitle"].inspect}"
    end
  end

  options[:platforms].each do |platform|
    response = fetch_versions(client, app_id, platform)
    index = included_index(response)
    puts "#{platform} versions:"
    response.fetch("data", []).each do |version|
      attributes = version.fetch("attributes", {})
      puts "  appStoreVersion #{version.fetch("id")} version=#{attributes["versionString"]} state=#{attributes["appStoreState"] || attributes["appVersionState"]}"
      localization_ids = relationship_ids(version, "appStoreVersionLocalizations")
      if localization_ids.empty?
        puts "    no appStoreVersionLocalizations relationship data"
      else
        localization_ids.each do |id|
          localization = index[["appStoreVersionLocalizations", id]]
          attributes = localization && localization.fetch("attributes", {})
          locale = attributes && attributes["locale"]
          promotional_text = attributes && attributes["promotionalText"]
          puts "    appStoreVersionLocalization #{id} locale=#{locale || "(not included)"} promotionalText=#{promotional_text.inspect}"
          print_screenshot_sets(client, id) if localization
        end
      end

      review_detail_ids = relationship_ids(version, "appStoreReviewDetail")
      if review_detail_ids.empty?
        puts "    no appStoreReviewDetail relationship data"
      else
        review_detail_ids.each { |id| puts "    appStoreReviewDetail #{id}" }
      end
    end
  end
  exit 0
end

if options[:prepare_version]
  listings.each do |platform, listing|
    prepare_next_version(client, app_id, platform, listing, options)
  end
  puts options[:apply] ? "Editable App Store version preparation finished." : "Dry run finished without changing App Store Connect."
  exit 0
end

if options[:update_app_info]
  app_info_response = fetch_app_infos(client, app_id)
  matches = app_info_localizations_for_locale(app_info_response, options[:locale])
  if matches.length == 1
    _app_info, localization = matches.first
    subtitles = listings.values.map { |listing| listing.fetch(:fields)[:subtitle] }.uniq
    if subtitles.length == 1
      patch_app_info_localization(client, localization, listings.values.first.fetch(:fields), options[:apply])
    else
      puts "Skipping appInfoLocalization #{localization.fetch("id")} because platform subtitles differ in local handoff files."
      puts "  Set the shared subtitle manually in App Store Connect, or align both listing subtitles before using --update-app-info."
    end
  else
    puts "Skipping app info localization update because #{matches.length} #{options[:locale]} appInfoLocalizations were found."
  end
end

listings.each do |platform, listing|
  fields = listing.fetch(:fields)
  info = LISTINGS.fetch(platform)
  response = fetch_versions(client, app_id, platform)
  version = choose_version(response, platform, options[:version_ids][platform], options[:apply])
  attributes = version.fetch("attributes", {})

  puts "#{info[:label]} version #{attributes["versionString"] || "(unknown)"} #{version_state(version)} (#{version.fetch("id")})"
  ensure_apply_allowed!(platform, version, options)

  localization = find_localization(response, version, options[:locale])
  unless localization
    puts "  missing #{options[:locale]} appStoreVersionLocalization; create it in App Store Connect, then re-run"
    next
  end

  patch_version_localization(client, localization, fields, options[:apply], options[:promotional_text_only])

  if options[:promotional_text_only]
    puts "  skipping review notes because --promotional-text-only was requested"
  else
    review_detail = find_review_detail(response, version)
    if review_detail
      patch_review_detail(client, review_detail, fields, options[:apply])
    else
      puts "  no appStoreReviewDetail relationship found; review notes were not #{options[:apply] ? "patched" : "included in dry run"}"
    end
  end
end

puts options[:apply] ? "App Store Connect metadata update finished." : "Dry run finished without changing App Store Connect."
