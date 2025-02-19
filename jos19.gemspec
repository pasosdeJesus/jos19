# frozen_string_literal: true

require_relative "lib/jos19/version"

Gem::Specification.new do |spec|
  spec.name        = "jos19"
  spec.version     = Jos19::VERSION
  spec.authors     = ["Vladimir Támara Patiño"]
  spec.email       = ["vtamara@pasosdeJesus.org"]
  spec.homepage    = "https://gitlab.com/pasosdeJesus/jos19"
  spec.summary     = "Seguimiento con cor1440 a casos de sivel2_gen"
  spec.description = "Facilita crear sistemas sobre cor1440 y sivel2_gen."
  spec.license = "ISC"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://gitlab.com/pasosdeJesus/jos19"
  spec.metadata["changelog_uri"] = "https://gitlab.com/pasosdeJesus/jos19"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "LICENSE.md", "Rakefile", "README.md"]
  end

  spec.add_dependency("rails", ">= 7.0.4")
end
