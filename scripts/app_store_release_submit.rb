#!/usr/bin/env ruby
# frozen_string_literal: true

require "base64"
require "json"
require "net/http"
require "openssl"
require "optparse"
require "time"
require "uri"

API_BASE = "https://api.appstoreconnect.apple.com"
DEFAULT_APP_ID = "6755408368"
DEFAULT_BUNDLE_ID = "com.vishaljain.HoldApp"

PLATFORMS = {
  "IOS" => {
    label: "iOS",
    version_id: "6ccfefb5-a49f-417d-b154-b5fbd11040fd",
    build_number: "9"
  },
  "MAC_OS" => {
    label: "macOS",
    version_id: "dd41569d-5050-4794-a1de-a9876ab098b4",
    build_number: "10"
  }
}.freeze

APP_VERSION_SUBMITTED_STATES = %w[
  WAITING_FOR_REVIEW
  IN_REVIEW
  PENDING_DEVELOPER_RELEASE
  PENDING_APPLE_RELEASE
  READY_FOR_SALE
].freeze

REVIEW_SUBMISSION_ACTIVE_STATES = %w[
  READY_FOR_REVIEW
  WAITING_FOR_REVIEW
  IN_REVIEW
  UNRESOLVED_ISSUES
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

  def get_all(path, query = {})
    first = get(path, query)
    data = first.fetch("data", [])
    included = first.fetch("included", [])
    next_url = first.dig("links", "next")
    while next_url
      page = request_absolute("GET", next_url)
      data.concat(page.fetch("data", []))
      included.concat(page.fetch("included", []))
      next_url = page.dig("links", "next")
    end
    first.merge("data" => data, "included" => included)
  end

  def patch(path, body)
    request("PATCH", path, body: body)
  end

  def post(path, body)
    request("POST", path, body: body)
  end

  private

  def request_absolute(method, url)
    uri = URI(url)
    perform_request(method, uri)
  end

  def request(method, path, query: {}, body: nil)
    uri = URI("#{API_BASE}#{path}")
    uri.query = URI.encode_www_form(query) unless query.empty?
    perform_request(method, uri, body)
  end

  def perform_request(method, uri, body = nil)
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
                parsed["errors"].map do |error|
                  [error["status"], error["title"], error["detail"]].compact.join(" ")
                end.join("; ")
              else
                response.body
              end
    raise "App Store Connect #{method} #{uri} failed with HTTP #{response.code}: #{message}"
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

def version_state(version)
  attributes = version.fetch("attributes", {})
  attributes["appStoreState"] || attributes["appVersionState"] || "UNKNOWN"
end

def fetch_app_store_version(client, version_id)
  client.get(
    "/v1/appStoreVersions/#{version_id}",
    "include" => "build",
    "fields[appStoreVersions]" => "platform,versionString,appStoreState,appVersionState,build",
    "fields[builds]" => "version,processingState,uploadedDate,usesNonExemptEncryption"
  )
end

def fetch_builds_for_number(client, app_id, build_number)
  client.get_all(
    "/v1/builds",
    "filter[app]" => app_id,
    "filter[version]" => build_number,
    "include" => "preReleaseVersion",
    "fields[builds]" => "version,processingState,uploadedDate,usesNonExemptEncryption,preReleaseVersion",
    "fields[preReleaseVersions]" => "version,platform",
    "sort" => "-uploadedDate",
    "limit" => "50"
  )
end

def matching_build(response, platform, marketing_version)
  index = included_index(response)
  response.fetch("data", []).find do |build|
    pre_release_id = relationship_ids(build, "preReleaseVersion").first
    pre_release = index[["preReleaseVersions", pre_release_id]]
    next false unless pre_release

    attributes = pre_release.fetch("attributes", {})
    attributes["platform"] == platform && attributes["version"] == marketing_version
  end
end

def build_summary(build, response)
  index = included_index(response)
  pre_release_id = relationship_ids(build, "preReleaseVersion").first
  pre_release = index[["preReleaseVersions", pre_release_id]]
  pre_release_attributes = pre_release ? pre_release.fetch("attributes", {}) : {}
  attributes = build.fetch("attributes", {})
  {
    id: build.fetch("id"),
    platform: pre_release_attributes["platform"],
    marketingVersion: pre_release_attributes["version"],
    buildNumber: attributes["version"],
    processingState: attributes["processingState"],
    usesNonExemptEncryption: attributes["usesNonExemptEncryption"],
    uploadedDate: attributes["uploadedDate"]
  }
end

def find_or_wait_for_build(client, app_id, platform, marketing_version, build_number, wait_seconds)
  deadline = Time.now + wait_seconds
  last_response = nil
  loop do
    response = fetch_builds_for_number(client, app_id, build_number)
    last_response = response
    build = matching_build(response, platform, marketing_version)
    if build
      state = build.dig("attributes", "processingState")
      summary = build_summary(build, response)
      puts "  found build #{summary[:id]} #{summary[:platform]} #{summary[:marketingVersion]} (#{summary[:buildNumber]}) state=#{state} uploaded=#{summary[:uploadedDate]}"
      return [build, response] if state == "VALID"
      raise "#{platform} build #{build_number} processing failed with state #{state}" if %w[FAILED INVALID].include?(state)
    else
      puts "  build #{platform} #{marketing_version} (#{build_number}) not visible yet"
    end

    break if Time.now >= deadline

    sleep 30
  end

  visible = last_response.fetch("data", []).map { |build| build_summary(build, last_response) }
  raise "Timed out waiting for #{platform} #{marketing_version} (#{build_number}) to become VALID. Visible builds: #{JSON.generate(visible)}"
end

def set_export_compliance(client, build, apply)
  current = build.dig("attributes", "usesNonExemptEncryption")
  if current == false
    puts "  export compliance already set to usesNonExemptEncryption=false"
    return
  end

  puts "  #{apply ? "setting" : "would set"} export compliance usesNonExemptEncryption=false for build #{build.fetch("id")}"
  return unless apply

  client.patch(
    "/v1/builds/#{build.fetch("id")}",
    {
      data: {
        id: build.fetch("id"),
        type: "builds",
        attributes: {
          usesNonExemptEncryption: false
        }
      }
    }
  )
end

def attach_build(client, version, build, apply)
  attached_build_id = relationship_ids(version, "build").first
  if attached_build_id == build.fetch("id")
    puts "  appStoreVersion #{version.fetch("id")} already points at build #{build.fetch("id")}"
    return
  end

  puts "  #{apply ? "attaching" : "would attach"} build #{build.fetch("id")} to appStoreVersion #{version.fetch("id")}"
  return unless apply

  client.patch(
    "/v1/appStoreVersions/#{version.fetch("id")}",
    {
      data: {
        id: version.fetch("id"),
        type: "appStoreVersions",
        relationships: {
          build: {
            data: {
              type: "builds",
              id: build.fetch("id")
            }
          }
        }
      }
    }
  )
end

def list_review_submissions(client, app_id, platform)
  client.get_all(
    "/v1/reviewSubmissions",
    "filter[app]" => app_id,
    "filter[platform]" => platform,
    "include" => "items,appStoreVersionForReview",
    "fields[reviewSubmissions]" => "platform,submittedDate,state,items,appStoreVersionForReview",
    "fields[reviewSubmissionItems]" => "state,appStoreVersion",
    "fields[appStoreVersions]" => "platform,versionString,appStoreState,appVersionState",
    "limit" => "200",
    "limit[items]" => "50"
  )
end

def review_submission_items(client, review_submission_id)
  client.get_all(
    "/v1/reviewSubmissions/#{review_submission_id}/items",
    "fields[reviewSubmissionItems]" => "state,appStoreVersion",
    "limit" => "200"
  )
end

def review_submission_item_for_version(client, review_submission_id, version_id)
  response = review_submission_items(client, review_submission_id)
  response.fetch("data", []).find do |item|
    relationship_ids(item, "appStoreVersion").first == version_id
  end
end

def review_submission_for_version(client, app_id, platform, version_id)
  response = list_review_submissions(client, app_id, platform)
  index = included_index(response)

  response.fetch("data", []).find do |submission|
    state = submission.dig("attributes", "state")
    next false unless REVIEW_SUBMISSION_ACTIVE_STATES.include?(state)

    direct_version_id = relationship_ids(submission, "appStoreVersionForReview").first
    next true if direct_version_id == version_id

    relationship_ids(submission, "items").any? do |item_id|
      item = index[["reviewSubmissionItems", item_id]]
      item && relationship_ids(item, "appStoreVersion").first == version_id
    end
  end
end

def reusable_review_submission(client, app_id, platform)
  response = list_review_submissions(client, app_id, platform)
  response.fetch("data", []).find do |submission|
    submission.dig("attributes", "state") == "READY_FOR_REVIEW" &&
      relationship_ids(submission, "items").empty?
  end
end

def create_review_submission(client, app_id, platform, apply)
  existing = reusable_review_submission(client, app_id, platform)
  if existing
    puts "  reusing reviewSubmission #{existing.fetch("id")} state=#{existing.dig("attributes", "state")}"
    return existing
  end

  puts "  #{apply ? "creating" : "would create"} reviewSubmission for #{platform}"
  return { "id" => "(new reviewSubmission)", "type" => "reviewSubmissions", "attributes" => { "state" => "READY_FOR_REVIEW" } } unless apply

  client.post(
    "/v1/reviewSubmissions",
    {
      data: {
        type: "reviewSubmissions",
        attributes: {
          platform: platform
        },
        relationships: {
          app: {
            data: {
              type: "apps",
              id: app_id
            }
          }
        }
      }
    }
  ).fetch("data")
end

def add_review_submission_item(client, review_submission, version_id, apply)
  existing_item = apply && review_submission_item_for_version(client, review_submission.fetch("id"), version_id)
  if existing_item
    puts "  reviewSubmission #{review_submission.fetch("id")} already contains item #{existing_item.fetch("id")} for version #{version_id}"
    return existing_item
  end

  puts "  #{apply ? "adding" : "would add"} appStoreVersion #{version_id} to reviewSubmission #{review_submission.fetch("id")}"
  return unless apply

  begin
    client.post(
      "/v1/reviewSubmissionItems",
      {
        data: {
          type: "reviewSubmissionItems",
          relationships: {
            reviewSubmission: {
              data: {
                type: "reviewSubmissions",
                id: review_submission.fetch("id")
              }
            },
            appStoreVersion: {
              data: {
                type: "appStoreVersions",
                id: version_id
              }
            }
          }
        }
      }
    ).fetch("data")
  rescue RuntimeError => error
    raise unless error.message.include?("already added to this reviewSubmission")

    puts "  appStoreVersion #{version_id} is already present in reviewSubmission #{review_submission.fetch("id")}"
    nil
  end
end

def submit_review_submission(client, review_submission, apply)
  state = review_submission.dig("attributes", "state")
  if %w[WAITING_FOR_REVIEW IN_REVIEW UNRESOLVED_ISSUES COMPLETE].include?(state)
    puts "  reviewSubmission #{review_submission.fetch("id")} already state=#{state}"
    return
  end

  puts "  #{apply ? "submitting" : "would submit"} reviewSubmission #{review_submission.fetch("id")}"
  return unless apply

  client.patch(
    "/v1/reviewSubmissions/#{review_submission.fetch("id")}",
    {
      data: {
        id: review_submission.fetch("id"),
        type: "reviewSubmissions",
        attributes: {
          submitted: true
        }
      }
    }
  )
end

def submit_version(client, app_id, platform, version, apply)
  state = version_state(version)
  if APP_VERSION_SUBMITTED_STATES.include?(state)
    puts "  appStoreVersion #{version.fetch("id")} is already submitted state=#{state}"
    return
  end

  review_submission = apply && review_submission_for_version(client, app_id, platform, version.fetch("id"))
  review_submission ||= create_review_submission(client, app_id, platform, apply)
  add_review_submission_item(client, review_submission, version.fetch("id"), apply)
  review_submission = apply ? client.get("/v1/reviewSubmissions/#{review_submission.fetch("id")}").fetch("data") : review_submission
  submit_review_submission(client, review_submission, apply)
end

def print_version_status(client, config)
  response = fetch_app_store_version(client, config.fetch(:version_id))
  version = response.fetch("data")
  index = included_index(response)
  build_id = relationship_ids(version, "build").first
  build = build_id && index[["builds", build_id]]
  puts "#{config.fetch(:label)} appStoreVersion #{version.fetch("id")} version=#{version.dig("attributes", "versionString")} state=#{version_state(version)}"
  if build
    attributes = build.fetch("attributes", {})
    puts "  attached build #{build.fetch("id")} number=#{attributes["version"]} processing=#{attributes["processingState"]} encryption=#{attributes["usesNonExemptEncryption"].inspect}"
  else
    puts "  no attached build"
  end
  version
end

options = {
  app_id: ENV.fetch("ASC_APP_ID", DEFAULT_APP_ID),
  bundle_id: ENV.fetch("ASC_BUNDLE_ID", DEFAULT_BUNDLE_ID),
  key_id: ENV["ASC_KEY_ID"],
  issuer_id: ENV["ASC_ISSUER_ID"],
  key_path: ENV["ASC_KEY_PATH"],
  marketing_version: ENV.fetch("ASC_MARKETING_VERSION", "1.1"),
  wait_minutes: 30,
  apply: false,
  inspect: false,
  platforms: PLATFORMS.keys
}

OptionParser.new do |opts|
  opts.banner = "Usage: ruby scripts/app_store_release_submit.rb [options]"
  opts.on("--key-id KEY_ID", "App Store Connect API key id") { |value| options[:key_id] = value }
  opts.on("--issuer-id ISSUER_ID", "App Store Connect API issuer id") { |value| options[:issuer_id] = value }
  opts.on("--key-path PATH", "Path to AuthKey_KEYID.p8") { |value| options[:key_path] = value }
  opts.on("--app-id APP_ID", "App Store Connect app id") { |value| options[:app_id] = value }
  opts.on("--version VERSION", "Marketing version to submit, default 1.1") { |value| options[:marketing_version] = value }
  opts.on("--ios-build BUILD", "Expected iOS build number") { |value| PLATFORMS.fetch("IOS")[:build_number] = value }
  opts.on("--macos-build BUILD", "Expected macOS build number") { |value| PLATFORMS.fetch("MAC_OS")[:build_number] = value }
  opts.on("--ios-version-id ID", "iOS appStoreVersion id") { |value| PLATFORMS.fetch("IOS")[:version_id] = value }
  opts.on("--macos-version-id ID", "macOS appStoreVersion id") { |value| PLATFORMS.fetch("MAC_OS")[:version_id] = value }
  opts.on("--platform PLATFORM", "IOS, MAC_OS, or comma-separated list") do |value|
    options[:platforms] = value.split(",").map { |platform| platform.strip.upcase }
  end
  opts.on("--wait-minutes MINUTES", Integer, "Minutes to wait for uploaded builds to become VALID") do |value|
    options[:wait_minutes] = value
  end
  opts.on("--inspect", "Inspect build attachment/submission state and exit") { options[:inspect] = true }
  opts.on("--apply", "Attach builds, set export compliance, and submit versions") { options[:apply] = true }
  opts.on("-h", "--help", "Show help") do
    puts opts
    exit 0
  end
end.parse!

unknown_platforms = options[:platforms] - PLATFORMS.keys
raise "Unknown platform(s): #{unknown_platforms.join(", ")}" unless unknown_platforms.empty?
raise "Missing --key-id or ASC_KEY_ID" if options[:key_id].to_s.empty?
raise "Missing --issuer-id or ASC_ISSUER_ID" if options[:issuer_id].to_s.empty?

options[:key_path] ||= File.expand_path("~/.appstoreconnect/private_keys/AuthKey_#{options[:key_id]}.p8")
raise "Missing private key file at #{options[:key_path]}" unless File.file?(File.expand_path(options[:key_path]))

puts options[:apply] ? "Applying release submission updates." : "Dry run only. Re-run with --apply to mutate App Store Connect."
token = jwt_for(key_id: options[:key_id], issuer_id: options[:issuer_id], key_path: options[:key_path])
client = AppStoreConnectClient.new(token)

options[:platforms].each do |platform|
  config = PLATFORMS.fetch(platform)
  puts
  puts "#{config.fetch(:label)} target #{options[:marketing_version]} (#{config.fetch(:build_number)})"
  version = print_version_status(client, config)
  next if options[:inspect]

  build, _response = find_or_wait_for_build(
    client,
    options[:app_id],
    platform,
    options[:marketing_version],
    config.fetch(:build_number),
    options[:wait_minutes] * 60
  )

  set_export_compliance(client, build, options[:apply])
  refreshed_version = fetch_app_store_version(client, config.fetch(:version_id)).fetch("data")
  attach_build(client, refreshed_version, build, options[:apply])
  refreshed_version = fetch_app_store_version(client, config.fetch(:version_id)).fetch("data")
  submit_version(client, options[:app_id], platform, refreshed_version, options[:apply])
  print_version_status(client, config) if options[:apply]
end
