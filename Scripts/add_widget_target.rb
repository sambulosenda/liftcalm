#!/usr/bin/env ruby
# Adds the LiftCalmWidgetExtension target (WidgetKit app extension) to the project,
# wires App Group entitlements onto the app, and embeds the appex. Idempotent:
# re-running is a no-op once the target exists. Uses the xcodeproj gem (objectVersion 77 aware).

require 'xcodeproj'

PROJECT = 'LiftCalm.xcodeproj'
WIDGET  = 'LiftCalmWidgetExtension'
TEAM    = 'Y53KNKBDS8'
GROUP   = 'group.com.sambulosendas1.LiftCalm'

project = Xcodeproj::Project.open(PROJECT)
app = project.targets.find { |t| t.name == 'LiftCalm' } or abort('app target "LiftCalm" not found')

if project.targets.any? { |t| t.name == WIDGET }
  puts "#{WIDGET} already exists — nothing to do."
  exit 0
end

widget = project.new_target(:app_extension, WIDGET, :ios, '26.0', project.products_group, :swift)

# Source group + files (explicit refs; folder is not a synchronized root).
group = project.main_group.new_group('LiftCalmWidget', 'LiftCalmWidget')
%w[LiftCalmWidgetBundle.swift ReadinessWidget.swift WidgetSnapshot.swift].each do |name|
  widget.add_file_references([group.new_file(name)])
end
group.new_file('Info.plist')                 # referenced via INFOPLIST_FILE, not compiled
group.new_file('LiftCalmWidget.entitlements') # referenced via CODE_SIGN_ENTITLEMENTS

widget.build_configurations.each do |c|
  bs = c.build_settings
  bs['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.sambulosendas1.LiftCalm.LiftCalmWidget'
  bs['PRODUCT_NAME'] = '$(TARGET_NAME)'
  bs['INFOPLIST_FILE'] = 'LiftCalmWidget/Info.plist'
  bs['GENERATE_INFOPLIST_FILE'] = 'YES'
  bs['INFOPLIST_KEY_CFBundleDisplayName'] = 'LiftCalm'
  bs['CODE_SIGN_ENTITLEMENTS'] = 'LiftCalmWidget/LiftCalmWidget.entitlements'
  bs['CODE_SIGN_STYLE'] = 'Automatic'
  bs['DEVELOPMENT_TEAM'] = TEAM
  bs['IPHONEOS_DEPLOYMENT_TARGET'] = '26.0'
  bs['MARKETING_VERSION'] = '1.0'
  bs['CURRENT_PROJECT_VERSION'] = '1'
  bs['SWIFT_VERSION'] = '5.0'
  bs['TARGETED_DEVICE_FAMILY'] = '1,2'
  bs['SKIP_INSTALL'] = 'YES'
  bs['ENABLE_PREVIEWS'] = 'YES'
  bs['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
  bs['SWIFT_APPROACHABLE_CONCURRENCY'] = 'YES'
  bs['SWIFT_DEFAULT_ACTOR_ISOLATION'] = 'MainActor'
  bs['SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY'] = 'YES'
  bs['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
end

# App: adopt the App Group entitlement so it can write the shared snapshot.
app.build_configurations.each do |c|
  c.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'LiftCalm/LiftCalm.entitlements'
end

# Build order + embed the appex into the app bundle's PlugIns.
app.add_dependency(widget)
embed = app.copy_files_build_phases.find { |ph| ph.symbol_dst_subfolder_spec == :plug_ins }
embed ||= app.new_copy_files_build_phase('Embed Foundation Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
build_file = embed.add_file_reference(widget.product_reference, true)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

project.save
puts "Added #{WIDGET}. Targets now: #{project.targets.map(&:name).join(', ')}"
puts "App Group: #{GROUP}"
