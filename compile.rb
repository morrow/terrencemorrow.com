#!/usr/bin/env ruby
require "tilt"
require "slim"

# pretty HTML output
Slim::Engine.set_default_options :pretty => true

t = Tilt.new "assets/index.slim"
f = File.new "public/index.html", "w+"
f.write(t.render())
f.close

# compile coffeescript assets
puts "compiling javascripts"
`coffee -cbo public/javascripts assets/*.coffee`

# compile scss assets
puts "compiling stylesheets"
`sass --update assets:public/stylesheets`

