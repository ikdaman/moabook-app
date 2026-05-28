#!/usr/bin/env ruby
# Play Store 의 모든 업로드된 bundle/apk versionCode 를 나열.
# 사용: bundle exec ruby list_bundles.rb
require "google/apis/androidpublisher_v3"
require "googleauth"

PACKAGE = "project.side.ikdaman"
KEY     = File.expand_path("./play-store-credentials.json", __dir__)

svc = Google::Apis::AndroidpublisherV3::AndroidPublisherService.new
svc.authorization = Google::Auth::ServiceAccountCredentials.make_creds(
  json_key_io: File.open(KEY),
  scope: ["https://www.googleapis.com/auth/androidpublisher"],
)

edit = svc.insert_edit(PACKAGE)
puts "edit id: #{edit.id}"

bundles = svc.list_edit_bundles(PACKAGE, edit.id).bundles || []
apks    = svc.list_edit_apks(PACKAGE, edit.id).apks       || []

puts "=== bundles (AAB) ==="
bundles.each { |b| puts "  versionCode=#{b.version_code} sha=#{b.sha256}" }

puts "=== apks ==="
apks.each { |a| puts "  versionCode=#{a.version_code} sha=#{a.binary&.sha256}" }

puts "=== tracks ==="
tracks = svc.list_edit_tracks(PACKAGE, edit.id).tracks || []
tracks.each do |t|
  next if (t.releases || []).empty?
  t.releases.each do |r|
    puts "  track=#{t.track} status=#{r.status} versionCodes=#{r.version_codes&.inspect}"
  end
end

svc.delete_edit(PACKAGE, edit.id)
