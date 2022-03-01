require "yast/rake"


Packaging.configuration do |conf|
  conf.obs_project = "home:varkoly:branches:SUSE:SLE-15-SP4:Update"
  conf.package_name = "sap-installation-wizard"
  conf.obs_api = "https://api.suse.de/"
  conf.obs_target = "standard"
end

desc "Run unit tests with coverage."
task "coverage" do
  files = Dir["**/test/**/*_{spec,test}.rb"]
  sh "export COVERAGE=1; rspec --color --format doc '#{files.join("' '")}'" unless files.empty?
  # sh "xdg-open coverage/index.html"
end

Yast::Tasks.configuration do |conf|
  conf.skip_license_check << /.*/
end

desc "Run unit tests with coverage."
task "coverage" do
  files = Dir["**/test/**/*_{spec,test}.rb"]
  sh "export COVERAGE=1; rspec --color --format doc '#{files.join("' '")}'" unless files.empty?
  # sh "xdg-open coverage/index.html"
end
