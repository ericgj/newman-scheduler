require "bundler"
Bundler.require

require File.expand_path('../app_libraries', File.dirname(__FILE__))
require File.expand_path('../app_models', File.dirname(__FILE__))

require 'minitest/spec'
MiniTest::Unit.autorun