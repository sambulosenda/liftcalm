#!/usr/bin/env ruby
# Adds the MuscleMap Swift Package (remote SPM dependency) to the LiftCalm app
# target and links its `MuscleMap` product. Idempotent: re-running is a no-op
# once the package reference exists. Uses the xcodeproj gem (objectVersion 77 aware).
#
# MuscleMap: MIT, zero transitive deps, on-device SVG body rendering (no network),
# iOS 17+. https://github.com/melihcolpan/MuscleMap

require 'xcodeproj'

PROJECT = 'LiftCalm.xcodeproj'
REPO    = 'https://github.com/melihcolpan/MuscleMap.git'
PRODUCT = 'MuscleMap'
MIN_VER = '1.6.4'

project = Xcodeproj::Project.open(PROJECT)
app = project.targets.find { |t| t.name == 'LiftCalm' } or abort('app target "LiftCalm" not found')

existing = (project.root_object.package_references || []).find do |ref|
  ref.respond_to?(:repositoryURL) && ref.repositoryURL == REPO
end
if existing
  puts "#{PRODUCT} package already referenced — nothing to do."
  exit 0
end

# Remote package reference, pinned up-to-next-major from MIN_VER.
pkg_ref = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
pkg_ref.repositoryURL = REPO
pkg_ref.requirement = { 'kind' => 'upToNextMajorVersion', 'minimumVersion' => MIN_VER }
project.root_object.package_references ||= []
project.root_object.package_references << pkg_ref

# Product dependency on the app target.
product_ref = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
product_ref.package = pkg_ref
product_ref.product_name = PRODUCT
app.package_product_dependencies ||= []
app.package_product_dependencies << product_ref

# Link the product into the app's Frameworks build phase.
build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
build_file.product_ref = product_ref
app.frameworks_build_phase.files << build_file

project.save
puts "Added #{PRODUCT} (#{REPO}, upToNextMajor from #{MIN_VER}) to target LiftCalm."
