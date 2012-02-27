
Dir[File.expand_path('app/presenters/*.rb', File.dirname(__FILE__))].each do |f|
  require f
end