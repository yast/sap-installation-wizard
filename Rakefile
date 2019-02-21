require "yast/rake"

desc "Run unit tests with coverage."
task "coverage" do
  files = Dir["**/test/**/*_{spec,test}.rb"]
  sh "export COVERAGE=1; rspec --color --format doc '#{files.join("' '")}'" unless files.empty?
  # sh "xdg-open coverage/index.html"
end

Yast::Tasks.configuration do |conf|
end

desc "Run unit tests with coverage."
task "coverage" do
  files = Dir["**/test/**/*_{spec,test}.rb"]
  sh "export COVERAGE=1; rspec --color --format doc '#{files.join("' '")}'" unless files.empty?
  #sh "xdg-open coverage/index.html"
end
