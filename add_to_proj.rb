require 'xcodeproj'
project = Xcodeproj::Project.open('Cleanify.xcodeproj')
group = project.main_group.find_subpath(File.join('Cleanify', 'Managers'), true)
file_ref = group.new_reference('RewardedAdManager.swift')
target = project.targets.first
target.add_file_references([file_ref])
project.save
