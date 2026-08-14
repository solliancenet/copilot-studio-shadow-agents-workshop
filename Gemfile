source "https://rubygems.org"

# Static site generator
gem "jekyll", "~> 4.3"

# Theme — GitHub Pages docs theme used across the Solliance workshop repos
gem "just-the-docs", "~> 0.10"

# Ruby 3.x no longer ships webrick, which `jekyll serve` needs
gem "webrick", "~> 1.8"

# Windows / JRuby timezone data (harmless elsewhere)
platforms :windows, :jruby do
  gem "tzinfo", ">= 1", "< 3"
  gem "tzinfo-data"
end
