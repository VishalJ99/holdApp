#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "optparse"
require "pathname"

ROOT = File.expand_path("..", __dir__)
DEFAULT_OUTPUT = File.join(ROOT, "app-store-assets/app-store-connect/landing-preview.html")

LISTINGS = {
  "ios" => {
    label: "iOS",
    file: File.join(ROOT, "app-store-assets/app-store-connect/ios-listing.md"),
    accent: "#2f63e7"
  },
  "macos" => {
    label: "macOS",
    file: File.join(ROOT, "app-store-assets/app-store-connect/macos-listing.md"),
    accent: "#2c7a54"
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

ASSET_LABELS = {
  "Screenshots" => :screenshots,
  "App icon" => :app_icon
}.freeze

FIELD_LIMITS = {
  name: 30,
  subtitle: 30,
  promotional_text: 170,
  description: 4_000,
  keywords: 100,
  whats_new: 4_000
}.freeze

def parse_listing(path)
  text = File.read(path)
  labels = FIELD_LABELS.keys.map { |label| Regexp.escape(label) }.join("|")
  markers = []
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

  lines = File.readlines(path)
  assets = {}
  ASSET_LABELS.each do |label, key|
    label_index = lines.index { |line| line.chomp == "#{label}:" }
    next unless label_index

    body = []
    lines[(label_index + 1)..-1].to_a.each do |line|
      break if line.start_with?("## ")
      break if line.match?(/^[A-Za-z][A-Za-z ]+:\s*$/)

      body << line
    end
    assets[key] = body.join.scan(/`([^`]+)`/).flatten
  end

  { fields: fields, assets: assets }
end

def relative_to_output(path, listing_file, output)
  absolute = File.expand_path(path, File.dirname(listing_file))
  Pathname.new(absolute).relative_path_from(Pathname.new(File.dirname(output))).to_s
end

def description_intro(description)
  description.to_s.split(/\n{2,}/).first.to_s
end

def split_paragraphs(text)
  text.to_s.split(/\n{2,}/).map(&:strip).reject(&:empty?)
end

def feature_lines(description)
  description.to_s.each_line.map(&:strip).select { |line| line.start_with?("- ") }.map { |line| line.sub(/\A-\s*/, "") }
end

def platform_payload(key, listing_info, output)
  parsed = parse_listing(listing_info.fetch(:file))
  fields = parsed.fetch(:fields)
  assets = parsed.fetch(:assets)
  {
    key: key,
    label: listing_info.fetch(:label),
    accent: listing_info.fetch(:accent),
    source: Pathname.new(listing_info.fetch(:file)).relative_path_from(Pathname.new(ROOT)).to_s,
    fields: fields,
    intro: description_intro(fields[:description]),
    descriptionParagraphs: split_paragraphs(fields[:description]),
    features: feature_lines(fields[:description]),
    screenshots: assets.fetch(:screenshots, []).map { |path| relative_to_output(path, listing_info.fetch(:file), output) },
    appIcon: assets.fetch(:app_icon, []).first && relative_to_output(assets.fetch(:app_icon).first, listing_info.fetch(:file), output),
    limits: FIELD_LIMITS.each_with_object({}) do |(field, limit), result|
      value = fields[field].to_s
      result[field] = { length: value.length, limit: limit }
    end
  }
end

def html_template(payload)
  json = JSON.pretty_generate(payload)
  <<~HTML
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>Hold App Store Page Preview</title>
      <style>
        :root {
          --ink: #1f2937;
          --brand: #1f2747;
          --paper: #ffffff;
          --muted: #667085;
          --line: #d8dde8;
          --soft: #f5f7fb;
          --ok: #2c7a54;
          --warn: #b54708;
        }

        * { box-sizing: border-box; }

        body {
          margin: 0;
          color: var(--ink);
          background: #f7f8fb;
          font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", sans-serif;
          line-height: 1.45;
        }

        button, input, textarea { font: inherit; }

        .topbar {
          position: sticky;
          top: 0;
          z-index: 10;
          border-bottom: 1px solid var(--line);
          background: rgba(255, 255, 255, 0.94);
          backdrop-filter: blur(18px);
        }

        .topbar-inner {
          max-width: 1240px;
          margin: 0 auto;
          padding: 14px 20px;
          display: flex;
          align-items: center;
          justify-content: space-between;
          gap: 16px;
        }

        .title-group {
          min-width: 0;
        }

        h1 {
          margin: 0;
          font-size: 20px;
          font-weight: 700;
          letter-spacing: 0;
        }

        .source-line {
          margin-top: 2px;
          color: var(--muted);
          font-size: 13px;
          overflow-wrap: anywhere;
        }

        .segmented {
          display: inline-grid;
          grid-template-columns: 1fr 1fr;
          border: 1px solid var(--line);
          border-radius: 8px;
          background: var(--soft);
          padding: 3px;
          min-width: 220px;
        }

        .segmented button {
          border: 0;
          border-radius: 6px;
          color: var(--muted);
          background: transparent;
          min-height: 34px;
          padding: 0 14px;
          cursor: pointer;
        }

        .segmented button[aria-selected="true"] {
          color: var(--ink);
          background: var(--paper);
          box-shadow: 0 1px 3px rgba(31, 41, 55, 0.14);
        }

        main {
          max-width: 1240px;
          margin: 0 auto;
          padding: 22px 20px 44px;
        }

        .layout {
          display: grid;
          grid-template-columns: minmax(0, 1fr) 330px;
          gap: 22px;
          align-items: start;
        }

        .preview-shell {
          background: var(--paper);
          border: 1px solid var(--line);
          border-radius: 8px;
          overflow: hidden;
        }

        .store-nav {
          display: flex;
          align-items: center;
          gap: 18px;
          padding: 14px 24px;
          border-bottom: 1px solid var(--line);
          color: var(--muted);
          font-size: 13px;
        }

        .store-nav strong {
          color: var(--ink);
          font-size: 15px;
        }

        .product-head {
          padding: 28px 24px 22px;
          display: grid;
          grid-template-columns: 118px minmax(0, 1fr) auto;
          gap: 22px;
          align-items: center;
        }

        .app-icon {
          width: 118px;
          height: 118px;
          border-radius: 22px;
          border: 1px solid rgba(31, 41, 55, 0.12);
          overflow: hidden;
          background: var(--brand);
        }

        .app-icon img {
          width: 100%;
          height: 100%;
          object-fit: cover;
          display: block;
        }

        .product-copy h2 {
          margin: 0;
          font-size: 34px;
          font-weight: 700;
          letter-spacing: 0;
        }

        .subtitle {
          color: var(--muted);
          font-size: 18px;
          margin-top: 2px;
        }

        .meta-row {
          margin-top: 14px;
          display: flex;
          flex-wrap: wrap;
          gap: 8px;
        }

        .pill {
          border: 1px solid var(--line);
          border-radius: 999px;
          color: var(--muted);
          background: var(--soft);
          padding: 4px 10px;
          font-size: 12px;
          white-space: nowrap;
        }

        .get-button {
          align-self: end;
          border: 0;
          border-radius: 999px;
          color: white;
          background: var(--accent, #2f63e7);
          font-weight: 700;
          min-width: 76px;
          height: 34px;
          padding: 0 18px;
        }

        .section {
          padding: 22px 24px;
          border-top: 1px solid var(--line);
        }

        .section h3 {
          margin: 0 0 12px;
          font-size: 21px;
          letter-spacing: 0;
        }

        .promo {
          font-size: 18px;
          color: var(--ink);
          margin: 0;
          max-width: 760px;
        }

        .screenshots {
          display: grid;
          grid-auto-flow: column;
          grid-auto-columns: minmax(230px, 320px);
          gap: 16px;
          overflow-x: auto;
          padding-bottom: 6px;
          overscroll-behavior-inline: contain;
        }

        .shot {
          border: 1px solid var(--line);
          border-radius: 8px;
          background: #101828;
          overflow: hidden;
          min-height: 220px;
        }

        .shot img {
          width: 100%;
          height: 100%;
          object-fit: contain;
          display: block;
          background: #101828;
        }

        .macos .screenshots {
          grid-auto-columns: minmax(480px, 760px);
        }

        .description {
          display: grid;
          gap: 14px;
          max-width: 820px;
        }

        .description p {
          margin: 0;
        }

        .feature-list {
          margin: 4px 0 0;
          padding-left: 20px;
          display: grid;
          gap: 6px;
        }

        .sidebar {
          display: grid;
          gap: 14px;
        }

        .panel {
          background: var(--paper);
          border: 1px solid var(--line);
          border-radius: 8px;
          padding: 16px;
        }

        .panel h3 {
          margin: 0 0 12px;
          font-size: 16px;
          letter-spacing: 0;
        }

        .metrics {
          display: grid;
          gap: 10px;
        }

        .metric {
          display: grid;
          grid-template-columns: minmax(0, 1fr) auto;
          gap: 10px;
          align-items: center;
          font-size: 13px;
        }

        .bar {
          grid-column: 1 / -1;
          height: 6px;
          border-radius: 999px;
          background: var(--soft);
          overflow: hidden;
        }

        .bar span {
          display: block;
          height: 100%;
          width: var(--fill, 0%);
          background: var(--metric-color, var(--ok));
        }

        .field-view {
          width: 100%;
          min-height: 118px;
          resize: vertical;
          border: 1px solid var(--line);
          border-radius: 8px;
          padding: 10px;
          color: var(--ink);
          background: var(--soft);
          font-size: 13px;
        }

        .field-select {
          width: 100%;
          margin-bottom: 10px;
          border: 1px solid var(--line);
          border-radius: 8px;
          min-height: 36px;
          padding: 0 10px;
          color: var(--ink);
          background: var(--paper);
        }

        .small {
          margin: 10px 0 0;
          color: var(--muted);
          font-size: 12px;
        }

        @media (max-width: 900px) {
          .topbar-inner {
            align-items: stretch;
            flex-direction: column;
          }

          .segmented {
            width: 100%;
          }

          .layout {
            grid-template-columns: 1fr;
          }

          .product-head {
            grid-template-columns: 86px minmax(0, 1fr);
          }

          .app-icon {
            width: 86px;
            height: 86px;
            border-radius: 18px;
          }

          .product-copy h2 {
            font-size: 28px;
          }

          .get-button {
            grid-column: 1 / -1;
            justify-self: start;
          }

          .macos .screenshots,
          .screenshots {
            grid-auto-columns: minmax(236px, 82vw);
          }
        }
      </style>
    </head>
    <body>
      <header class="topbar">
        <div class="topbar-inner">
          <div class="title-group">
            <h1>Hold App Store Page Preview</h1>
            <div class="source-line" id="sourceLine"></div>
          </div>
          <div class="segmented" role="tablist" aria-label="Platform">
            <button type="button" data-platform="ios" aria-selected="true">iOS</button>
            <button type="button" data-platform="macos" aria-selected="false">macOS</button>
          </div>
        </div>
      </header>

      <main>
        <div class="layout">
          <section id="preview" class="preview-shell ios" aria-live="polite"></section>
          <aside class="sidebar">
            <section class="panel">
              <h3>Field Lengths</h3>
              <div id="metrics" class="metrics"></div>
            </section>
            <section class="panel">
              <h3>Copy Scratchpad</h3>
              <select id="fieldSelect" class="field-select" aria-label="Copy field"></select>
              <textarea id="fieldView" class="field-view" spellcheck="true"></textarea>
              <p class="small">Edit here for quick copy experiments. Source markdown is unchanged until you update the listing file.</p>
            </section>
          </aside>
        </div>
      </main>

      <script>
        const DATA = #{json};
        const FIELD_LABELS = {
          name: "App name",
          subtitle: "Subtitle",
          promotional_text: "Promotional text",
          description: "Description",
          keywords: "Keywords",
          whats_new: "What's new"
        };

        let active = "ios";

        function escapeHtml(value) {
          return String(value || "").replace(/[&<>"']/g, (char) => ({
            "&": "&amp;",
            "<": "&lt;",
            ">": "&gt;",
            '"': "&quot;",
            "'": "&#39;"
          })[char]);
        }

        function setPlatform(key) {
          active = key;
          if (location.hash.replace("#", "") !== key) {
            history.replaceState(null, "", `#${key}`);
          }
          document.querySelectorAll("[data-platform]").forEach((button) => {
            button.setAttribute("aria-selected", String(button.dataset.platform === key));
          });
          render();
        }

        function renderScreenshots(item) {
          return item.screenshots.map((src, index) => `
            <figure class="shot">
              <img src="${escapeHtml(src)}" alt="${escapeHtml(item.label)} screenshot ${index + 1}">
            </figure>
          `).join("");
        }

        function renderDescription(item) {
          const intro = item.descriptionParagraphs.filter((paragraph) => !paragraph.includes("\\n- ")).map((paragraph) => {
            if (paragraph.startsWith("Features:")) return "";
            if (paragraph.startsWith("- ")) return "";
            return `<p>${escapeHtml(paragraph)}</p>`;
          }).join("");
          const features = item.features.length ? `
            <ul class="feature-list">
              ${item.features.map((feature) => `<li>${escapeHtml(feature)}</li>`).join("")}
            </ul>
          ` : "";
          return `${intro}${features}`;
        }

        function renderPreview(item) {
          const fields = item.fields;
          document.documentElement.style.setProperty("--accent", item.accent);
          document.getElementById("sourceLine").textContent = `Source: ${item.source}`;
          const preview = document.getElementById("preview");
          preview.className = `preview-shell ${item.key}`;
          preview.innerHTML = `
            <div class="store-nav">
              <strong>App Store</strong>
              <span>Today</span>
              <span>Apps</span>
              <span>${escapeHtml(fields.category || "Productivity")}</span>
            </div>
            <div class="product-head">
              <div class="app-icon"><img src="${escapeHtml(item.appIcon)}" alt="Hold app icon"></div>
              <div class="product-copy">
                <h2>${escapeHtml(fields.name)}</h2>
                <div class="subtitle">${escapeHtml(fields.subtitle)}</div>
                <div class="meta-row">
                  <span class="pill">${escapeHtml(item.label)}</span>
                  <span class="pill">${escapeHtml(fields.category || "PRODUCTIVITY")}</span>
                  <span class="pill">Version 1.1 preview</span>
                </div>
              </div>
              <button class="get-button" type="button">GET</button>
            </div>
            <section class="section">
              <h3>What's New</h3>
              <p class="promo">${escapeHtml(fields.whats_new)}</p>
            </section>
            <section class="section">
              <h3>Preview</h3>
              <div class="screenshots">${renderScreenshots(item)}</div>
            </section>
            <section class="section">
              <h3>Promotional Text</h3>
              <p class="promo">${escapeHtml(fields.promotional_text)}</p>
            </section>
            <section class="section">
              <h3>Description</h3>
              <div class="description">${renderDescription(item)}</div>
            </section>
          `;
        }

        function renderMetrics(item) {
          const metrics = document.getElementById("metrics");
          metrics.innerHTML = Object.entries(item.limits).map(([key, limit]) => {
            const percent = Math.min(100, Math.round((limit.length / limit.limit) * 100));
            const color = percent > 95 ? "var(--warn)" : "var(--ok)";
            return `
              <div class="metric">
                <span>${escapeHtml(FIELD_LABELS[key] || key)}</span>
                <strong>${limit.length}/${limit.limit}</strong>
                <div class="bar" style="--fill:${percent}%; --metric-color:${color};"><span></span></div>
              </div>
            `;
          }).join("");
        }

        function renderScratchpad(item) {
          const select = document.getElementById("fieldSelect");
          const textarea = document.getElementById("fieldView");
          const existing = select.value || "promotional_text";
          select.innerHTML = Object.entries(FIELD_LABELS).map(([key, label]) => `
            <option value="${key}">${escapeHtml(label)}</option>
          `).join("");
          select.value = item.fields[existing] === undefined ? "promotional_text" : existing;
          textarea.value = item.fields[select.value] || "";
        }

        function render() {
          const item = DATA.platforms[active];
          renderPreview(item);
          renderMetrics(item);
          renderScratchpad(item);
        }

        document.querySelectorAll("[data-platform]").forEach((button) => {
          button.addEventListener("click", () => setPlatform(button.dataset.platform));
        });
        document.getElementById("fieldSelect").addEventListener("change", (event) => {
          document.getElementById("fieldView").value = DATA.platforms[active].fields[event.target.value] || "";
        });

        const initialPlatform = DATA.platforms[location.hash.replace("#", "")] ? location.hash.replace("#", "") : "ios";
        setPlatform(initialPlatform);
      </script>
    </body>
    </html>
  HTML
end

options = {
  output: DEFAULT_OUTPUT
}

OptionParser.new do |parser|
  parser.banner = "Usage: ruby scripts/generate_app_store_preview.rb [options]"
  parser.on("--output PATH", "Preview HTML output path") { |value| options[:output] = value }
  parser.on("-h", "--help", "Show help") do
    puts parser
    exit 0
  end
end.parse!

output = File.expand_path(options[:output])
payload = {
  platforms: LISTINGS.each_with_object({}) do |(key, listing_info), result|
    result[key] = platform_payload(key, listing_info, output)
  end
}

FileUtils.mkdir_p(File.dirname(output))
File.write(output, html_template(payload))
puts "Wrote #{output}"
