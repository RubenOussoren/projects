require 'opal'

File.write('vendor/opal.js', Opal::Builder.build('opal'))
File.write('vendor/opal-parser.js', Opal::Builder.build('opal-parser'))
File.write('opal_generated/content_script.js', Opal.compile(File.read('content_script.rb')))